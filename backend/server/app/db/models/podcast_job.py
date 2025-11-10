"""SQLAlchemy model for podcast generation jobs."""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional

from sqlalchemy import CheckConstraint, Enum as SQLEnum, JSON, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from ..base import Base


class PodcastJobStatus(str, Enum):
    """Enumeration of job states."""

    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class PodcastJob(Base):
    """Represents a single podcast generation request."""

    __tablename__ = "podcast_jobs"

    id: Mapped[str] = mapped_column(primary_key=True, default=lambda: str(uuid.uuid4()))
    status: Mapped[PodcastJobStatus] = mapped_column(
        SQLEnum(PodcastJobStatus, name="podcast_job_status", native_enum=False),
        default=PodcastJobStatus.QUEUED,
        nullable=False,
    )
    requested_by: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    result_paths: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    progress: Mapped[Optional[int]] = mapped_column(nullable=True)
    log_excerpt: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("progress IS NULL OR (progress >= 0 AND progress <= 100)", name="podcast_jobs_progress_range"),
    )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "status": self.status.value,
            "requested_by": self.requested_by,
            "payload": self.payload,
            "result_paths": self.result_paths,
            "error_message": self.error_message,
            "progress": self.progress,
            "log_excerpt": self.log_excerpt,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }
