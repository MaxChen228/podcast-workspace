"""Repository helpers for PodcastJob persistence."""

from __future__ import annotations

from typing import Any, Dict, Optional, List

from sqlalchemy.orm import Session

from ..db.models import PodcastJob, PodcastJobStatus


class PodcastJobRepository:
    """Lightweight repository to hide ORM details from route handlers."""

    def __init__(self, session: Session):
        self.session = session

    def create_job(
        self,
        *,
        payload: Dict[str, Any],
        requested_by: Optional[str] = None,
        initial_status: PodcastJobStatus = PodcastJobStatus.QUEUED,
    ) -> PodcastJob:
        job = PodcastJob(payload=payload, requested_by=requested_by, status=initial_status)
        self.session.add(job)
        self.session.flush()
        self.session.refresh(job)
        return job

    def get_job(self, job_id: str) -> Optional[PodcastJob]:
        return self.session.get(PodcastJob, job_id)

    def list_jobs(
        self,
        *,
        status: Optional[List[PodcastJobStatus]] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[PodcastJob], int]:
        query = self.session.query(PodcastJob)
        if status:
            query = query.filter(PodcastJob.status.in_(status))
        total = query.count()
        rows = (
            query.order_by(PodcastJob.created_at.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )
        return rows, total

    def update_status(
        self,
        job: PodcastJob,
        *,
        status: PodcastJobStatus,
        result_paths: Optional[Dict[str, Any]] = None,
        error_message: Optional[str] = None,
        progress: Optional[int] = None,
        log_excerpt: Optional[str] = None,
    ) -> PodcastJob:
        job.status = status
        if result_paths is not None:
            job.result_paths = result_paths
        if error_message is not None:
            job.error_message = error_message
        if progress is not None:
            job.progress = progress
        if log_excerpt is not None:
            job.log_excerpt = log_excerpt
        self.session.add(job)
        self.session.flush()
        self.session.refresh(job)
        return job
