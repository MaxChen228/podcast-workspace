"""Service layer exports for the FastAPI application."""

from .filesystem import (
    BookData,
    ChapterData,
    OutputDataCache,
    SubtitleData,
)
from .explanation import (
    SentenceExplanationError,
    SentenceExplanationResult,
    SentenceExplanationService,
    VocabularyEntry,
)
from .news_service import (
    NewsEventLogger,
    NewsFetchResult,
    NewsService,
    NewsServiceError,
    NewsValidationError,
    NewsAPIError,
    NewsConfigurationError,
)
from .podcast_jobs import PodcastJobRepository
from .job_queue import PodcastJobQueue, NullPodcastJobQueue

__all__ = [
    "BookData",
    "ChapterData",
    "OutputDataCache",
    "SubtitleData",
    "SentenceExplanationError",
    "SentenceExplanationResult",
    "SentenceExplanationService",
    "VocabularyEntry",
    "NewsService",
    "NewsFetchResult",
    "NewsEventLogger",
    "NewsServiceError",
    "NewsValidationError",
    "NewsAPIError",
    "NewsConfigurationError",
    "PodcastJobRepository",
    "PodcastJobQueue",
    "NullPodcastJobQueue",
]
