"""Simple Redis-backed queue for podcast generation jobs."""

from __future__ import annotations

import json
import logging
from typing import Any, Dict

import redis

logger = logging.getLogger(__name__)


class PodcastJobQueue:
    """Publishes job payloads to a Redis list so workers can consume them."""

    def __init__(self, redis_url: str, queue_name: str = "podcast_jobs") -> None:
        if not redis_url:
            raise ValueError("redis_url is required")
        self.queue_name = queue_name
        self._client = redis.Redis.from_url(redis_url, decode_responses=False)

    def enqueue(self, job_id: str, payload: Dict[str, Any]) -> None:
        body = json.dumps({"job_id": job_id, "payload": payload})
        logger.info("Enqueue podcast job %s", job_id)
        self._client.rpush(self.queue_name, body)


class NullPodcastJobQueue:
    """Fallback queue used when no Redis connection is configured."""

    def enqueue(self, job_id: str, payload: Dict[str, Any]) -> None:  # pragma: no cover - logging only
        logger.warning("Podcast job %s queued but QUEUE_URL is not configured; worker will not see it.", job_id)
