"""Import a Gemini dialogue podcast into the Storytelling backend output tree.

Usage:
    python scripts/import_gemini_dialogue.py \
        --source ../gemini-2-podcast \
        --book gemini-demo \
        --chapter chapter_dialogue_demo \
        --title "Gemini Dialogue Demo" \
        --language en
"""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import re
import sys
import wave

from pydub import AudioSegment

REQUIRED_SOURCE_FILES = ["podcast_script.txt", "final_podcast.wav"]


@dataclass
class ImportOptions:
    source: Path
    book_id: str
    chapter_id: str
    title: str
    language: str
    create_book: bool


def parse_args() -> ImportOptions:
    repo_root = Path(__file__).resolve().parents[1]
    default_source = repo_root.parent / "gemini-2-podcast"

    parser = argparse.ArgumentParser(description="Import Gemini dialogue assets into output/<book>/<chapter>/")
    parser.add_argument("--source", type=Path, default=default_source, help="Directory containing podcast_script.txt and final_podcast.wav")
    parser.add_argument("--book", dest="book_id", default="gemini-demo", help="Book directory name (default: gemini-demo)")
    parser.add_argument("--chapter", dest="chapter_id", default="chapter_dialogue_demo", help="Chapter folder name (default: chapter_dialogue_demo)")
    parser.add_argument("--title", default="Gemini Dialogue Demo", help="Chapter title shown in clients")
    parser.add_argument("--language", default="en", help="Language code of the generated dialogue (for metadata only)")
    parser.add_argument("--create-book", action="store_true", help="Create book folder/metadata if it does not exist")
    args = parser.parse_args()

    chapter_id = args.chapter_id
    if not chapter_id.startswith("chapter"):
        if chapter_id.startswith("chapter_"):
            pass
        else:
            chapter_id = f"chapter_{chapter_id}"

    return ImportOptions(
        source=args.source.resolve(),
        book_id=args.book_id,
        chapter_id=chapter_id,
        title=args.title,
        language=args.language,
        create_book=args.create_book,
    )


def ensure_source_files(source: Path) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for name in REQUIRED_SOURCE_FILES:
        path = source / name
        if not path.exists():
            raise FileNotFoundError(f"Missing {name} in {source}")
        files[name] = path
    return files


def ensure_book_dir(root: Path, book_id: str, create_book: bool) -> Path:
    book_dir = root / book_id
    if not book_dir.exists():
        if not create_book:
            raise FileNotFoundError(
                f"Book directory {book_dir} does not exist. Use --create-book to bootstrap it."
            )
        book_dir.mkdir(parents=True, exist_ok=True)
        metadata = {
            "book_id": book_id,
            "book_title": book_id,
            "display_name": book_id,
            "created_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
            "notes": "Created via import_gemini_dialogue.py",
        }
        (book_dir / "book_metadata.json").write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
        )
    return book_dir


def compute_audio_duration_seconds(wav_path: Path) -> float:
    with wave.open(str(wav_path), "rb") as wav_file:
        frames = wav_file.getnframes()
        rate = wav_file.getframerate()
        if rate == 0:
            return 0.0
        return round(frames / float(rate), 3)


def strip_speaker_labels(text: str) -> str:
    cleaned_lines = []
    for line in text.splitlines():
        cleaned_lines.append(re.sub(r"^\s*Speaker\s+[A-Za-z]+:\s*", "", line))
    return "\n".join(cleaned_lines)


def count_words_from_text(text: str) -> int:
    words = re.findall(r"[\w']+", text)
    return len(words)


def write_chapter_metadata(
    chapter_dir: Path, title: str, language: str, duration: float, word_count: int
) -> None:
    metadata = {
        "chapter_title": title,
        "language": language,
        "audio_file": "podcast.wav",
        "script_file": "podcast_script.txt",
        "audio_duration_sec": duration,
        "word_count": word_count,
        "subtitles_available": False,
        "generation_source": "gemini-2-podcast",
        "created_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
    }
    (chapter_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
    )



def convert_wav_to_mp3(wav_path: Path, bitrate: str = "192k") -> None:
    mp3_path = wav_path.with_suffix(".mp3")
    try:
        audio = AudioSegment.from_file(wav_path)
        audio.export(str(mp3_path), format="mp3", bitrate=bitrate)
    except Exception as exc:
        print(f"⚠️  無法轉換 {wav_path.name} 為 MP3：{exc}")


def main() -> int:
    opts = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    output_root = repo_root / "output"

    source_files = ensure_source_files(opts.source)
    book_dir = ensure_book_dir(output_root, opts.book_id, opts.create_book)
    chapter_dir = book_dir / opts.chapter_id
    chapter_dir.mkdir(parents=True, exist_ok=True)

    wav_dest = chapter_dir / "podcast.wav"
    script_dest = chapter_dir / "podcast_script.txt"
    shutil.copy2(source_files["final_podcast.wav"], wav_dest)
    convert_wav_to_mp3(wav_dest)

    raw_script = source_files["podcast_script.txt"].read_text(encoding="utf-8")
    cleaned_script = strip_speaker_labels(raw_script)
    script_dest.write_text(cleaned_script, encoding="utf-8")

    duration_sec = compute_audio_duration_seconds(wav_dest)
    word_count = count_words_from_text(cleaned_script)
    write_chapter_metadata(chapter_dir, opts.title, opts.language, duration_sec, word_count)

    print(f"✅ Imported dialogue to {chapter_dir.relative_to(repo_root)}")
    print("You can now run uvicorn and access the chapter via the existing API.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except FileNotFoundError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        raise SystemExit(1)
