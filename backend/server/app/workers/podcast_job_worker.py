"""Background worker that processes PodcastJob queue messages."""

from __future__ import annotations

import argparse
import importlib.util
import logging
import os
import shutil
import signal
import subprocess
import sys
import threading
import traceback
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Dict, Optional

import httpx

from ..config import ServerSettings
from ..db.models.podcast_job import PodcastJobStatus
from ..db.session import get_sessionmaker
from ..services.job_queue import PodcastJobQueue
from ..services.podcast_jobs import PodcastJobRepository


logger = logging.getLogger("podcast-job-worker")


@contextmanager
def pushd(path: Path):
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def _load_module(module_name: str, file_path: Path):
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    if spec is None or spec.loader is None:  # pragma: no cover - import failure
        raise RuntimeError(f"Unable to load module from {file_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    return module


class PodcastJobWorker:
    def __init__(self, settings: ServerSettings) -> None:
        if not settings.database_url:
            raise RuntimeError("DATABASE_URL is not configured")
        if not settings.queue_url:
            raise RuntimeError("QUEUE_URL is not configured")

        self.settings = settings
        self.sessionmaker = get_sessionmaker(settings.database_url)
        self.queue = PodcastJobQueue(settings.queue_url, settings.job_queue_name)
        self.gemini_dir = settings.project_root / "gemini-2-podcast"
        self.story_cli_dir = settings.project_root / "storytelling-cli"
        self.output_root = settings.project_root / "output"
        self._stop = threading.Event()
        self._generate_script_module = None
        self.sync_bucket = settings.sync_bucket.rstrip("/") if settings.sync_bucket else None
        self.sync_exclude_regex = settings.sync_exclude_regex

    def run(self, once: bool = False) -> None:
        logger.info("Podcast job worker started (queue=%s)", self.settings.job_queue_name)
        while not self._stop.is_set():
            message = self.queue.dequeue(timeout=5)
            if not message:
                if once:
                    break
                continue

            job_id = message.get("job_id")
            if not job_id:
                logger.warning("Received malformed queue payload: %s", message)
                continue

            try:
                self._process_job(job_id)
            except Exception as exc:  # pragma: no cover - unexpected failure
                logger.exception("Unexpected failure while processing %s: %s", job_id, exc)

            if once:
                break

    def stop(self) -> None:
        self._stop.set()

    def _process_job(self, job_id: str) -> None:
        logger.info("Processing job %s", job_id)
        with self.sessionmaker() as session:
            repo = PodcastJobRepository(session)
            job = repo.get_job(job_id)
            if not job:
                logger.warning("Job %s not found in database", job_id)
                return
            job_payload = dict(job.payload)
            repo.update_status(job, status=PodcastJobStatus.RUNNING, progress=5, log_excerpt="Dequeued")
            session.commit()

        try:
            result_paths = self._execute_pipeline(job_id, job_payload)
        except Exception as exc:
            error_message = str(exc)
            logger.error("Job %s failed: %s", job_id, error_message)
            logger.debug("Traceback: %s", traceback.format_exc())
            with self.sessionmaker() as session:
                repo = PodcastJobRepository(session)
                job = repo.get_job(job_id)
                if job:
                    repo.update_status(
                        job,
                        status=PodcastJobStatus.FAILED,
                        error_message=error_message[:1024],
                        log_excerpt=traceback.format_exc()[:2048],
                        progress=100,
                    )
                    session.commit()
            return

        with self.sessionmaker() as session:
            repo = PodcastJobRepository(session)
            job = repo.get_job(job_id)
            if job:
                repo.update_status(
                    job,
                    status=PodcastJobStatus.SUCCEEDED,
                    result_paths=result_paths,
                    progress=100,
                    log_excerpt="Completed",
                )
                session.commit()
        logger.info("Job %s completed", job_id)

    def _execute_pipeline(self, job_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        content = self._resolve_content(payload)
        language = payload.get("language", "English")
        book_id = payload.get("book_id", "gemini-demo")
        chapter_id = payload.get("chapter_id", f"chapter_{job_id[:8]}")
        if not chapter_id.startswith("chapter"):
            chapter_id = f"chapter_{chapter_id}" if not chapter_id.startswith("chapter_") else chapter_id
        title = payload.get("title") or chapter_id

        script_path = self._generate_script_file(content)
        self._prepare_audio_instructions(language)
        self._run_audio_generation()
        chapter_dir = self._import_into_output(book_id, chapter_id, title, language, payload)
        subtitles_path = self._generate_subtitles(chapter_dir)
        self._sync_chapter_to_gcs(book_id, chapter_id, chapter_dir)

        return {
            "chapter_dir": str(chapter_dir),
            "script_file": str(chapter_dir / "podcast_script.txt"),
            "audio_wav": str(chapter_dir / "podcast.wav"),
            "audio_mp3": str(chapter_dir / "podcast.mp3"),
            "metadata": str(chapter_dir / "metadata.json"),
            "subtitles": str(subtitles_path) if subtitles_path else None,
        }

    def _resolve_content(self, payload: Dict[str, Any]) -> str:
        source_type = (payload.get("source_type") or "text").strip().lower()
        source_value = payload.get("source_value") or ""
        if not source_value:
            raise ValueError("source_value is required")

        if source_type in {"text", "markdown", "md"}:
            return source_value
        if source_type == "url":
            response = httpx.get(source_value, timeout=30.0)
            response.raise_for_status()
            return response.text
        raise ValueError(f"Unsupported source_type: {source_type}")

    def _generate_script_file(self, content: str) -> Path:
        if not self.gemini_dir.exists():
            raise FileNotFoundError(f"Gemini project directory not found: {self.gemini_dir}")

        module = self._load_generate_script_module()
        with pushd(self.gemini_dir):
            script = module.create_podcast_script(content)
            if not script:
                raise RuntimeError("Gemini script generation returned empty result")
            cleaned = module.clean_podcast_script(script)
            target = self.gemini_dir / "podcast_script.txt"
            target.write_text(cleaned, encoding="utf-8")
            return target

    def _prepare_audio_instructions(self, language: str) -> None:
        template_path = self.gemini_dir / "system_instructions_audio_template.txt"
        output_path = self.gemini_dir / "system_instructions_audio.txt"
        template = template_path.read_text(encoding="utf-8")
        output_path.write_text(template.replace("[LANGUAGE]", language), encoding="utf-8")

    def _run_audio_generation(self) -> None:
        if not self.gemini_dir.exists():  # pragma: no cover - config error
            raise FileNotFoundError("Gemini project directory missing")
        subprocess.run([sys.executable, "generate_audio.py"], cwd=self.gemini_dir, check=True)

    def _import_into_output(
        self,
        book_id: str,
        chapter_id: str,
        title: str,
        language: str,
        payload: Dict[str, Any],
    ) -> Path:
        script_path = self.story_cli_dir / "scripts" / "import_gemini_dialogue.py"
        if not script_path.exists():
            raise FileNotFoundError(f"Import script not found: {script_path}")

        cmd = [
            sys.executable,
            str(script_path),
            "--source",
            str(self.gemini_dir),
            "--book",
            book_id,
            "--chapter",
            chapter_id,
            "--title",
            title,
            "--language",
            language,
        ]
        if payload.get("create_book", False):
            cmd.append("--create-book")
        env = os.environ.copy()
        env["OUTPUT_ROOT"] = str(self.output_root)
        env["DATA_ROOT"] = str(self.settings.data_root)
        subprocess.run(cmd, cwd=self.story_cli_dir, check=True, env=env)

        cli_output_dir = self.story_cli_dir / "output" / book_id / chapter_id
        target_dir = self.output_root / book_id / chapter_id
        if cli_output_dir.exists():
            target_dir.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["cp", "-R", str(cli_output_dir) + "/.", str(target_dir)], check=True)

        if not target_dir.exists():
            raise FileNotFoundError(f"Expected chapter directory missing: {target_dir}")
        return target_dir

    def _generate_subtitles(self, chapter_dir: Path) -> Optional[Path]:
        script_path = self.story_cli_dir / "generate_subtitles.py"
        if not script_path.exists():
            raise FileNotFoundError(f"Subtitle generator not found: {script_path}")

        cmd = [sys.executable, str(script_path), str(chapter_dir)]
        env = os.environ.copy()
        env.setdefault("OUTPUT_ROOT", str(self.output_root))
        env.setdefault("DATA_ROOT", str(self.settings.data_root))
        subprocess.run(cmd, cwd=self.story_cli_dir, check=True, env=env)

        subtitles_path = chapter_dir / "subtitles.srt"
        if not subtitles_path.exists():
            raise FileNotFoundError(f"Subtitle file missing after generation: {subtitles_path}")
        return subtitles_path

    def _sync_chapter_to_gcs(self, book_id: str, chapter_id: str, chapter_dir: Path) -> None:
        if not self.sync_bucket:
            logger.info("Skipping GCS sync (STORYTELLING_SYNC_BUCKET not configured)")
            return

        if shutil.which("gsutil") is None:
            raise RuntimeError("gsutil command not found; install Google Cloud SDK for automatic sync")

        target_uri = f"{self.sync_bucket}/{book_id}/{chapter_id}"
        cmd = [
            "gsutil",
            "-m",
            "rsync",
            "-r",
            "-x",
            self.sync_exclude_regex,
            str(chapter_dir),
            target_uri,
        ]
        logger.info("Syncing chapter %s/%s to %s", book_id, chapter_id, target_uri)
        subprocess.run(cmd, check=True)

    def _load_generate_script_module(self):
        if self._generate_script_module is None:
            module_path = self.gemini_dir / "generate_script.py"
            self._generate_script_module = _load_module("gemini_generate_script", module_path)
        return self._generate_script_module


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the podcast job worker")
    parser.add_argument("--once", action="store_true", help="Process a single job then exit")
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(
        level=getattr(logging, args.log_level.upper()),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    settings = ServerSettings.load()
    worker = PodcastJobWorker(settings)

    def _handle_signal(signum, frame):  # pragma: no cover - signal handling
        logger.info("Received signal %s, shutting down", signum)
        worker.stop()

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    worker.run(once=args.once)
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    raise SystemExit(main())
