"""定義前端真正需要的精簡 Pydantic schema。"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, Literal, Optional, List

from pydantic import BaseModel, Field, ConfigDict


class BookItem(BaseModel):
    """書籍清單項目。"""

    id: str
    title: str
    cover_url: Optional[str] = None
    model_config = ConfigDict(exclude_none=True)


class ChapterItem(BaseModel):
    """章節清單項目。"""

    id: str
    title: str
    chapter_number: Optional[int] = None
    audio_available: bool = False
    subtitles_available: bool = False
    word_count: Optional[int] = None
    audio_duration_sec: Optional[float] = None
    words_per_minute: Optional[float] = None


class ChapterPlayback(BaseModel):
    """播放頁面需要的章節資訊。"""

    id: str
    title: str
    chapter_number: Optional[int] = None
    audio_url: Optional[str] = None
    subtitles_url: Optional[str] = None
    word_count: Optional[int] = None
    audio_duration_sec: Optional[float] = None
    words_per_minute: Optional[float] = None


class SentenceExplanationVocabulary(BaseModel):
    """句子重點的詞彙解釋。"""

    word: str
    meaning: str
    note: Optional[str] = None


class SentenceExplanationRequest(BaseModel):
    """句子解釋請求。"""

    sentence: str = Field(..., min_length=1, max_length=2000)
    previous_sentence: Optional[str] = Field(default="", max_length=2000)
    next_sentence: Optional[str] = Field(default="", max_length=2000)
    language: Optional[str] = Field(default="zh-TW", min_length=2, max_length=16)


class PhraseExplanationRequest(BaseModel):
    """詞組解釋請求。"""

    phrase: str = Field(..., min_length=1, max_length=200, description="用戶選中的詞組")
    sentence: str = Field(..., min_length=1, max_length=2000, description="完整句子")
    previous_sentence: Optional[str] = Field(default="", max_length=2000)
    next_sentence: Optional[str] = Field(default="", max_length=2000)
    language: Optional[str] = Field(default="zh-TW", min_length=2, max_length=16)


class SentenceExplanationResponse(BaseModel):
    """句子解釋回應。"""

    overview: str
    key_points: list[str] = Field(default_factory=list)
    vocabulary: list[SentenceExplanationVocabulary] = Field(default_factory=list)
    chinese_meaning: Optional[str] = None
    cached: bool = False


class AssetList(BaseModel):
    """資源清單回應。"""

    assets: list[str] = Field(default_factory=list, description="Available asset filenames")


class NewsArticle(BaseModel):
    """Single news article normalized for the app."""

    id: str
    title: str
    url: str
    summary: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[str] = None
    provider_name: Optional[str] = None
    published_at: Optional[str] = None
    source: str = "newsdata-io"


class NewsHeadlineResponse(BaseModel):
    articles: list[NewsArticle] = Field(default_factory=list)
    category: Optional[str] = None
    market: str
    count: int
    cached: bool = False


class NewsSearchResponse(NewsHeadlineResponse):
    query: str


class NewsInteraction(BaseModel):
    article_id: str = Field(..., min_length=4, max_length=64)
    article_url: str = Field(..., min_length=5)
    action: Literal["open", "share", "save", "impression"] = "open"
    category: Optional[str] = None
    client_ts: Optional[str] = None
    device_locale: Optional[str] = None
    market: Optional[str] = None


class PodcastJobStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class PodcastJobCreateRequest(BaseModel):
    """請求建立新的 Podcast 生成任務。"""

    source_type: Literal["url", "pdf", "markdown", "text"] = "url"
    source_value: str = Field(..., min_length=1)
    language: str = Field("English", min_length=2, max_length=32)
    book_id: str = Field(..., min_length=2, max_length=128)
    chapter_id: str = Field(..., min_length=2, max_length=128)
    title: str = Field(..., min_length=3, max_length=256)
    notes: Optional[str] = Field(default=None, max_length=500)
    requested_by: Optional[str] = Field(default=None, max_length=128)
    create_book: bool = Field(default=False, description="If true, auto-create book metadata when missing")


class PodcastJobResponse(BaseModel):
    """回傳 Podcast 任務狀態。"""

    id: str
    status: PodcastJobStatus
    requested_by: Optional[str] = None
    payload: Dict[str, Any] = Field(default_factory=dict)
    result_paths: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    progress: Optional[int] = None
    log_excerpt: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class PodcastJobListResponse(BaseModel):
    items: List[PodcastJobResponse] = Field(default_factory=list)
    total: int
