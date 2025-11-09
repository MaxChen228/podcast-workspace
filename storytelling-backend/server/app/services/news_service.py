"""Integration with external news APIs (e.g., Bing News)."""

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
    """Fetches curated news articles from Bing News Search API."""

    def __init__(
        self,
        *,
        headlines_endpoint: str,
        search_endpoint: str,
        api_key: str,
        default_market: str,
        allowed_categories: Optional[List[str]] = None,
        cache_ttl_seconds: int = 900,
        default_count: int = 10,
        max_count: int = 25,
        http_timeout: float = 10.0,
    ) -> None:
        self.headlines_endpoint = headlines_endpoint
        self.search_endpoint = search_endpoint
        self.api_key = api_key
        self.default_market = default_market
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
        if not settings.bing_news_api_key:
            raise NewsConfigurationError("BING_NEWS_KEY must be set when NEWS_FEATURE_ENABLED=1")
        return cls(
            headlines_endpoint=settings.bing_news_endpoint,
            search_endpoint=settings.bing_news_search_endpoint,
            api_key=settings.bing_news_api_key,
            default_market=settings.bing_news_market,
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
        resolved_market = (market or self.default_market).strip() or self.default_market
        resolved_count = self._normalize_count(count)
        cache_key = self._cache_key("headlines", {
            "category": normalized_category or "",
            "market": resolved_market,
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
            "mkt": resolved_market,
            "count": resolved_count,
            "safeSearch": "Moderate",
            "textFormat": "Raw",
        }
        if normalized_category:
            params["category"] = normalized_category

        articles = await self._request_articles(self.headlines_endpoint, params)
        await self._store_cache(cache_key, articles, normalized_category, resolved_market, resolved_count)

        return NewsFetchResult(
            articles=articles,
            category=normalized_category,
            market=resolved_market,
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
        resolved_market = (market or self.default_market).strip() or self.default_market
        resolved_count = self._normalize_count(count)
        cache_key = self._cache_key("search", {
            "q": query.lower(),
            "market": resolved_market,
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
            "q": query,
            "mkt": resolved_market,
            "count": resolved_count,
            "textFormat": "Raw",
            "safeSearch": "Moderate",
        }

        articles = await self._request_articles(self.search_endpoint, params)
        await self._store_cache(cache_key, articles, None, resolved_market, resolved_count)

        return NewsFetchResult(
            articles=articles,
            category=None,
            market=resolved_market,
            count=resolved_count,
            cached=False,
        )

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
        headers = {"Ocp-Apim-Subscription-Key": self.api_key}
        try:
            async with httpx.AsyncClient(timeout=self.http_timeout) as client:
                response = await client.get(url, params=params, headers=headers)
        except httpx.HTTPError as exc:
            raise NewsAPIError(f"Failed to contact news API: {exc}") from exc

        if response.status_code == 401:
            raise NewsAPIError("Invalid Bing News API key")
        if response.status_code == 429:
            raise NewsAPIError("News API rate limit exceeded")
        if response.status_code >= 500:
            raise NewsAPIError("News API unavailable")
        if response.status_code >= 400:
            raise NewsValidationError("News API rejected the request")

        payload = response.json()
        value = payload.get("value") or []
        articles = [self._to_article(item) for item in value if item]
        return articles

    def _to_article(self, item: Dict[str, Any]) -> NewsArticle:
        url = item.get("url") or ""
        raw_id = url or item.get("name") or item.get("description") or str(hash(item))
        article_id = hashlib.sha1(raw_id.encode("utf-8")).hexdigest()[:24]
        provider_block = (item.get("provider") or [{}])[0]
        image_block = item.get("image") or {}
        thumbnail = image_block.get("thumbnail") or {}
        image_url = thumbnail.get("contentUrl") or image_block.get("contentUrl")
        return NewsArticle(
            id=article_id,
            title=item.get("name", ""),
            summary=item.get("description"),
            url=url,
            image_url=image_url,
            category=item.get("category"),
            provider_name=provider_block.get("name"),
            published_at=item.get("datePublished"),
            source="bing-news",
        )

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
