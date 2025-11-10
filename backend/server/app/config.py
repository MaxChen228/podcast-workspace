"""
Configuration helpers for the FastAPI backend.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

from dotenv import load_dotenv


def _resolve_path(raw: str) -> Path:
    """Resolves a potentially relative path against the project root."""
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate
    project_root = Path(__file__).resolve().parents[2]
    return (project_root / candidate).resolve()


@dataclass
class ServerSettings:
    """Settings object populated from environment variables."""

    project_root: Path = field(
        default_factory=lambda: _resolve_path((os.getenv("PROJECT_ROOT") or ".").strip())
    )
    data_root: Path = field(default_factory=lambda: _resolve_path("output"))
    data_root_raw: str = "output"
    database_url: Optional[str] = None
    queue_url: Optional[str] = None
    job_queue_name: str = "podcast_jobs"
    cors_origins: List[str] = field(default_factory=list)
    gzip_min_size: int = 512
    sentence_explainer_model: str = "gemini-2.5-flash-lite"
    sentence_explainer_timeout: float = 30.0
    sentence_explainer_cache_size: int = 128
    media_delivery_mode: str = "local"
    gcs_mirror_include_suffixes: Optional[List[str]] = None
    signed_url_ttl_seconds: int = 600
    news_feature_enabled: bool = False
    newsdata_api_key: Optional[str] = None
    newsdata_endpoint: str = "https://newsdata.io/api/1/latest"
    newsdata_default_language: str = "en"
    newsdata_default_country: Optional[str] = None
    news_category_whitelist: List[str] = field(default_factory=list)
    news_cache_ttl_seconds: int = 900
    news_default_count: int = 10
    news_max_count: int = 25
    news_http_timeout: float = 10.0
    news_events_dir: Path = field(default_factory=lambda: _resolve_path("logs/news_events"))

    @classmethod
    def load(cls) -> "ServerSettings":
        load_dotenv()

        project_root_raw = os.getenv("PROJECT_ROOT", ".").strip()
        project_root = _resolve_path(project_root_raw)
        data_root_raw = os.getenv("DATA_ROOT", "output")
        if data_root_raw.startswith("gs://"):
            cache_root = os.getenv("STORYTELLING_GCS_CACHE_DIR", "/tmp/storytelling-output")
            data_root = Path(cache_root).expanduser().resolve()
        else:
            data_root = _resolve_path(data_root_raw)

        cors_raw = os.getenv("CORS_ORIGINS", "")
        cors_origins = [origin.strip() for origin in cors_raw.split(",") if origin.strip()]
        database_url = os.getenv("DATABASE_URL") or None
        gzip_min_size = int(os.getenv("GZIP_MIN_SIZE", "512"))
        queue_url = os.getenv("QUEUE_URL") or os.getenv("PODCAST_JOB_QUEUE_URL") or None
        job_queue_name = os.getenv("PODCAST_JOB_QUEUE_NAME", "podcast_jobs")
        sentence_explainer_model = os.getenv("SENTENCE_EXPLAINER_MODEL", "gemini-2.5-flash-lite")
        sentence_explainer_timeout = float(os.getenv("SENTENCE_EXPLAINER_TIMEOUT", "30"))
        sentence_explainer_cache_size = int(os.getenv("SENTENCE_EXPLAINER_CACHE_SIZE", "128"))
        media_delivery_mode = (os.getenv("MEDIA_DELIVERY_MODE", "local") or "local").strip().lower()
        include_suffixes_raw = os.getenv("GCS_MIRROR_INCLUDE_SUFFIXES", "").strip()
        include_suffixes: Optional[List[str]]
        if include_suffixes_raw:
            include_suffixes = []
            for item in include_suffixes_raw.split(","):
                normalized = item.strip()
                if not normalized:
                    continue
                if not normalized.startswith("."):
                    normalized = f".{normalized}"
                include_suffixes.append(normalized.lower())
            if not include_suffixes:
                include_suffixes = None
        else:
            include_suffixes = None
        signed_url_ttl_seconds = max(60, int(os.getenv("SIGNED_URL_TTL_SECONDS", "600")))

        news_feature_enabled = os.getenv("NEWS_FEATURE_ENABLED", "false").strip().lower() in {"1", "true", "yes", "on"}
        newsdata_api_key = os.getenv("NEWSDATA_API_KEY") or None
        newsdata_endpoint = os.getenv("NEWSDATA_ENDPOINT", "https://newsdata.io/api/1/latest").rstrip("/")
        newsdata_default_language = os.getenv("NEWSDATA_DEFAULT_LANGUAGE", "en")
        newsdata_default_country = os.getenv("NEWSDATA_DEFAULT_COUNTRY") or None
        category_whitelist_raw = os.getenv("NEWS_CATEGORY_WHITELIST", "")
        news_category_whitelist = [item.strip().lower() for item in category_whitelist_raw.split(",") if item.strip()]
        news_cache_ttl_seconds = max(30, int(os.getenv("NEWS_CACHE_TTL_SECONDS", "900")))
        news_default_count = max(1, int(os.getenv("NEWS_DEFAULT_COUNT", "10")))
        news_max_count = max(news_default_count, int(os.getenv("NEWS_MAX_COUNT", "25")))
        news_http_timeout = float(os.getenv("NEWS_HTTP_TIMEOUT", "10"))
        news_events_dir_raw = os.getenv("NEWS_EVENTS_DIR", "logs/news_events")
        news_events_dir = _resolve_path(news_events_dir_raw)

        return cls(
            project_root=project_root,
            data_root=data_root,
            data_root_raw=data_root_raw,
            database_url=database_url,
            queue_url=queue_url,
            job_queue_name=job_queue_name,
            cors_origins=cors_origins,
            gzip_min_size=gzip_min_size,
            sentence_explainer_model=sentence_explainer_model,
            sentence_explainer_timeout=sentence_explainer_timeout,
            sentence_explainer_cache_size=sentence_explainer_cache_size,
            media_delivery_mode=media_delivery_mode,
            gcs_mirror_include_suffixes=include_suffixes,
            signed_url_ttl_seconds=signed_url_ttl_seconds,
            news_feature_enabled=news_feature_enabled,
            newsdata_api_key=newsdata_api_key,
            newsdata_endpoint=newsdata_endpoint,
            newsdata_default_language=newsdata_default_language,
            newsdata_default_country=newsdata_default_country,
            news_category_whitelist=news_category_whitelist,
            news_cache_ttl_seconds=news_cache_ttl_seconds,
            news_default_count=news_default_count,
            news_max_count=news_max_count,
            news_http_timeout=news_http_timeout,
            news_events_dir=news_events_dir,
        )
