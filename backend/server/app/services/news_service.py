"""Integration with external news APIs (e.g., NewsData.io)."""

from __future__ import annotations

import asyncio
import hashlib
import logging
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import httpx

from ..config import ServerSettings
from ..schemas import NewsArticle

logger = logging.getLogger(__name__)


class NewsServiceError(Exception):
    """Base exception for news service issues."""


class NewsConfigurationError(NewsServiceError):
    """Raised when required config/env vars are missing."""


class NewsValidationError(NewsServiceError):
    """Raised when user-provided inputs are invalid."""


class NewsAPIError(NewsServiceError):
    """Raised when upstream API returns an error."""


@dataclass
class _CacheEntry:
    expires_at: float
    articles: List[NewsArticle]
    category: Optional[str]
    market: str
    count: int


class NewsService:
    """Fetches curated news articles from NewsData.io API."""

    def __init__(
        self,
        *,
        endpoint: str,
        api_key: str,
        default_language: str,
        default_country: Optional[str],
        allowed_categories: Optional[List[str]] = None,
        cache_ttl_seconds: int = 900,
        default_count: int = 10,
        max_count: int = 10,
        http_timeout: float = 10.0,
    ) -> None:
        self.endpoint = endpoint
        self.api_key = api_key
        self.default_language = default_language
        self.default_country = default_country
        self.allowed_categories = [c.lower() for c in allowed_categories or []]
        self.cache_ttl_seconds = cache_ttl_seconds
        self.default_count = default_count
        self.max_count = max_count
        self.http_timeout = http_timeout
        self._cache: dict[str, _CacheEntry] = {}
        self._cache_lock = asyncio.Lock()

    @classmethod
    def from_settings(cls, settings: ServerSettings) -> "NewsService":
        if not settings.news_feature_enabled:
            raise NewsConfigurationError("News feature is disabled")
        if not settings.newsdata_api_key:
            raise NewsConfigurationError("NEWSDATA_API_KEY must be set when NEWS_FEATURE_ENABLED=1")
        return cls(
            endpoint=settings.newsdata_endpoint,
            api_key=settings.newsdata_api_key,
            default_language=settings.newsdata_default_language,
            default_country=settings.newsdata_default_country,
            allowed_categories=settings.news_category_whitelist,
            cache_ttl_seconds=settings.news_cache_ttl_seconds,
            default_count=settings.news_default_count,
            max_count=settings.news_max_count,
            http_timeout=settings.news_http_timeout,
        )

    async def fetch_headlines(
        self,
        *,
        category: Optional[str],
        market: Optional[str],
        count: Optional[int],
    ) -> NewsFetchResult:
        normalized_category = self._normalize_category(category)
        resolved_language, resolved_country = self._parse_market(market)
        resolved_count = self._normalize_count(count)
        cache_key = self._cache_key("headlines", {
            "category": normalized_category or "",
            "language": resolved_language,
            "country": resolved_country or "",
            "count": resolved_count,
        })

        cached = await self._get_cached(cache_key)
        if cached:
            return NewsFetchResult(
                articles=cached.articles,
                category=cached.category,
                market=cached.market,
                count=cached.count,
                cached=True,
            )

        params: dict[str, Any] = {
            "apikey": self.api_key,
            "language": resolved_language,
            "size": resolved_count,
        }
        if normalized_category:
            params["category"] = normalized_category
        if resolved_country:
            params["country"] = resolved_country

        articles = await self._request_articles(self.endpoint, params)
        market_display = f"{resolved_language}-{resolved_country.upper()}" if resolved_country else resolved_language
        await self._store_cache(cache_key, articles, normalized_category, market_display, resolved_count)

        return NewsFetchResult(
            articles=articles,
            category=normalized_category,
            market=market_display,
            count=resolved_count,
            cached=False,
        )

    async def search_news(
        self,
        *,
        query: str,
        market: Optional[str],
        count: Optional[int],
    ) -> NewsFetchResult:
        query = (query or "").strip()
        if not query:
            raise NewsValidationError("Query cannot be empty")
        resolved_language, resolved_country = self._parse_market(market)
        resolved_count = self._normalize_count(count)
        cache_key = self._cache_key("search", {
            "q": query.lower(),
            "language": resolved_language,
            "country": resolved_country or "",
            "count": resolved_count,
        })

        cached = await self._get_cached(cache_key)
        if cached:
            return NewsFetchResult(
                articles=cached.articles,
                category=cached.category,
                market=cached.market,
                count=cached.count,
                cached=True,
            )

        params: dict[str, Any] = {
            "apikey": self.api_key,
            "q": query,
            "language": resolved_language,
            "size": resolved_count,
        }
        if resolved_country:
            params["country"] = resolved_country

        articles = await self._request_articles(self.endpoint, params)
        market_display = f"{resolved_language}-{resolved_country.upper()}" if resolved_country else resolved_language
        await self._store_cache(cache_key, articles, None, market_display, resolved_count)

        return NewsFetchResult(
            articles=articles,
            category=None,
            market=market_display,
            count=resolved_count,
            cached=False,
        )

    def _parse_market(self, market: Optional[str]) -> tuple[str, Optional[str]]:
        """Parse market parameter (e.g., 'en-US') into language and country."""
        if not market or not market.strip():
            return self.default_language, self.default_country

        market = market.strip()
        if "-" in market:
            parts = market.split("-", 1)
            language = parts[0].lower()
            country = parts[1].lower() if len(parts) > 1 else None
            return language, country
        return market.lower(), self.default_country

    def _normalize_category(self, category: Optional[str]) -> Optional[str]:
        if not category:
            return None
        normalized = category.strip().lower()
        if not normalized:
            return None
        if self.allowed_categories and normalized not in self.allowed_categories:
            raise NewsValidationError("Unsupported category")
        return normalized

    def _normalize_count(self, count: Optional[int]) -> int:
        if not count:
            return self.default_count
        if count < 1:
            raise NewsValidationError("count must be >= 1")
        if count > self.max_count:
            return self.max_count
        return count

    async def _get_cached(self, key: str) -> Optional[_CacheEntry]:
        entry = self._cache.get(key)
        if not entry:
            return None
        if entry.expires_at < time.monotonic():
            async with self._cache_lock:
                self._cache.pop(key, None)
            return None
        return entry

    async def _store_cache(
        self,
        key: str,
        articles: List[NewsArticle],
        category: Optional[str],
        market: str,
        count: int,
    ) -> None:
        entry = _CacheEntry(
            expires_at=time.monotonic() + self.cache_ttl_seconds,
            articles=articles,
            category=category,
            market=market,
            count=count,
        )
        async with self._cache_lock:
            self._cache[key] = entry

    async def _request_articles(self, url: str, params: Dict[str, Any]) -> List[NewsArticle]:
        try:
            async with httpx.AsyncClient(timeout=self.http_timeout) as client:
                response = await client.get(url, params=params)
        except httpx.HTTPError as exc:
            raise NewsAPIError(f"Failed to contact news API: {exc}") from exc

        if response.status_code == 401 or response.status_code == 403:
            raise NewsAPIError("Invalid NewsData.io API key")
        if response.status_code == 429:
            raise NewsAPIError("News API rate limit exceeded")
        if response.status_code >= 500:
            raise NewsAPIError("News API unavailable")
        if response.status_code >= 400:
            raise NewsValidationError("News API rejected the request")

        payload = response.json()
        results = payload.get("results") or []
        articles = [self._to_article(item) for item in results if item]
        return articles

    def _to_article(self, item: Dict[str, Any]) -> NewsArticle:
        url = item.get("link") or ""
        raw_id = url or item.get("title") or item.get("description") or str(hash(item))
        article_id = hashlib.sha1(raw_id.encode("utf-8")).hexdigest()[:24]
        image_url = item.get("image_url")
        provider_name = item.get("source_name") or item.get("source_id")
        category_list = item.get("category") or []
        category = category_list[0] if isinstance(category_list, list) and category_list else None
        return NewsArticle(
            id=article_id,
            title=item.get("title", ""),
            summary=item.get("description"),
            url=url,
            image_url=image_url,
            category=category,
            provider_name=provider_name,
            published_at=item.get("pubDate"),
            source="newsdata-io",
        )

    async def fetch_article_content(self, url: str) -> "NewsArticleContent":
        """Fetches and parses the content of a news article."""
        from bs4 import BeautifulSoup
        from ..schemas import NewsArticleContent

        try:
            async with httpx.AsyncClient(timeout=self.http_timeout, follow_redirects=True) as client:
                # Add headers to mimic a browser to avoid some basic anti-bot protections
                headers = {
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                }
                response = await client.get(url, headers=headers)
                response.raise_for_status()
        except httpx.HTTPError as exc:
            raise NewsAPIError(f"Failed to fetch article: {exc}") from exc

        try:
            soup = BeautifulSoup(response.text, "html.parser")
            
            # Basic metadata extraction
            title = soup.title.string if soup.title else ""
            
            # Try to find the main article body
            # This is a heuristic approach and might need refinement for specific sites
            article_body = soup.find("article")
            if not article_body:
                # Fallback to common class names
                for class_name in ["article-content", "post-content", "entry-content", "content", "main"]:
                    article_body = soup.find(class_=class_name)
                    if article_body:
                        break
            
            if not article_body:
                # Last resort: just grab all paragraphs
                content_html = "".join([str(p) for p in soup.find_all("p")])
            else:
                # Clean up the content
                for tag in article_body(["script", "style", "iframe", "form", "nav", "footer", "header"]):
                    tag.decompose()
                content_html = str(article_body)

            # Try to extract image
            image_url = None
            og_image = soup.find("meta", property="og:image")
            if og_image:
                image_url = og_image.get("content")

            # Try to extract author
            author = None
            meta_author = soup.find("meta", attrs={"name": "author"})
            if meta_author:
                author = meta_author.get("content")

            # Try to extract date
            date_published = None
            meta_date = soup.find("meta", property="article:published_time")
            if meta_date:
                date_published = meta_date.get("content")

            return NewsArticleContent(
                title=title.strip() if title else "No Title",
                author=author,
                date_published=date_published,
                content=content_html,
                image_url=image_url,
                url=url
            )

        except Exception as exc:
            raise NewsValidationError(f"Failed to parse article content: {exc}") from exc

    def _cache_key(self, prefix: str, params: Dict[str, Any]) -> str:
        serialized = "&".join(f"{k}={params[k]}" for k in sorted(params))
        return f"{prefix}:{serialized}"


class NewsFetchResult:
    """Normalized result container returned by the service."""

    def __init__(
        self,
        *,
        articles: List[NewsArticle],
        category: Optional[str],
        market: str,
        count: int,
        cached: bool,
    ) -> None:
        self.articles = articles
        self.category = category
        self.market = market
        self.count = count
        self.cached = cached


class NewsEventLogger:
    """Persists client-side news interactions for future personalization."""

    def __init__(self, base_dir) -> None:
        from pathlib import Path
        from threading import Lock
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self._lock = Lock()

    def log(self, event_payload: Dict[str, Any]) -> None:
        import json
        from datetime import datetime, timezone

        now = datetime.now(timezone.utc)
        filename = self.base_dir / f"{now.strftime('%Y-%m-%d')}.jsonl"
        enriched = dict(event_payload)
        enriched.setdefault("server_received_at", now.isoformat())
        with self._lock:
            with filename.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(enriched, ensure_ascii=False) + "\n")


