#!/usr/bin/env python3
"""Generate mock scripts/audio/subtitles for offline testing.

This tool walks through the same folders used by the real CLI pipeline and
creates placeholder artifacts so that the CLI UI can be exercised without
calling external LLM/TTS APIs.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import time
import wave
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence

import yaml


def load_config(path: str) -> Dict[str, Any]:
    config_path = Path(path).expanduser()
    if not config_path.exists():
        raise FileNotFoundError(f"找不到配置檔：{config_path}")
    with config_path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def clean_text(content: str) -> str:
    lines = [line.rstrip() for line in content.splitlines()]
    cleaned: List[str] = []
    for line in lines:
        if not line.strip():
            if cleaned and cleaned[-1] != "":
                cleaned.append("")
            continue
        cleaned.append(line.strip())
    return "\n".join(cleaned).strip()


def resolve_book_config(config: Dict[str, Any], book_id: Optional[str]) -> Dict[str, Any]:
    if not book_id:
        raise ValueError("必須提供 --book-id")

    paths_cfg = config.get("paths", {})
    books_root = Path(paths_cfg.get("books_root", "./data")).expanduser().resolve()
    outputs_root = Path(paths_cfg.get("outputs_root", "./output")).expanduser().resolve()

    book_dir = books_root / book_id
    if not book_dir.exists():
        raise FileNotFoundError(f"找不到書籍資料夾: {book_dir}")

    books_cfg = config.get("books", {})
    defaults = books_cfg.get("defaults", {})
    overrides = (books_cfg.get("overrides", {}) or {}).get(book_id, {})

    merged = dict(defaults)
    merged.update(overrides)
    summary_subdir = merged.get("summary_subdir", "summaries")
    summary_suffix = merged.get("summary_suffix", "_summary.txt")

    merged["book_id"] = book_id
    merged["books_root"] = str(books_root)
    merged["outputs_root"] = str(outputs_root)
    merged["chapters_dir"] = str(book_dir)
    merged["summary_subdir"] = summary_subdir
    merged["summary_suffix"] = summary_suffix
    merged["summaries_dir"] = str((book_dir / summary_subdir).resolve())

    if "book_name_override" not in merged and overrides.get("display_name"):
        merged["book_name_override"] = overrides["display_name"]

    return merged


def natural_key(text: str) -> List[object]:
    import re

    parts = re.split(r"(\d+)", text)
    key: List[object] = []
    for part in parts:
        if part.isdigit():
            key.append(int(part))
        else:
            key.append(part.lower())
    return key


def parse_range_spec(spec: str, slugs: Sequence[str]) -> List[str]:
    spec = spec.strip()
    if not spec or spec.lower() == "all":
        return list(slugs)

    selected = set()
    parts = [p.strip() for p in spec.split(",") if p.strip()]
    for part in parts:
        if part.isdigit():
            idx = int(part)
            if 0 <= idx < len(slugs):
                selected.add(slugs[idx])
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            if a.strip().isdigit() and b.strip().isdigit():
                start, end = int(a), int(b)
                if start > end:
                    start, end = end, start
                for idx in range(start, end + 1):
                    if 0 <= idx < len(slugs):
                        selected.add(slugs[idx])
                continue
        if part in slugs:
            selected.add(part)
        else:
            raise ValueError(f"無法解析章節選擇：{part}")

    return [slug for slug in slugs if slug in selected]


def write_silence_wav(target: Path, duration: float, sample_rate: int = 24000) -> None:
    frames = max(1, int(duration * sample_rate))
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * frames)


def build_mock_script(chapter_path: Path, chapter_number: int, narrator: str) -> str:
    raw_text = chapter_path.read_text(encoding="utf-8")
    cleaned = clean_text(raw_text)
    paragraphs = cleaned.splitlines()
    preview = " ".join(paragraphs[:8])
    return (
        f"<Narrator voice=\"{narrator}\">\n"
        f"今天我們繼續探索第 {chapter_number} 章 {chapter_path.stem}\n\n"
        f"{preview}\n\n這是一個離線模擬輸出，僅供內部流程測試。\n"
        "</Narrator>"
    )


def create_mock_subtitles(total_seconds: float) -> str:
    midpoint = min(total_seconds, max(total_seconds / 2, 2))
    def format_ts(seconds: float) -> str:
        millis = int((seconds - int(seconds)) * 1000)
        s = int(seconds)
        m, sec = divmod(s, 60)
        h, m = divmod(m, 60)
        return f"{h:02d}:{m:02d}:{sec:02d},{millis:03d}"

    return "\n".join(
        [
            "1",
            f"00:00:00,000 --> {format_ts(midpoint)}",
            "Mock intro for testing pipeline.",
            "",
            "2",
            f"{format_ts(midpoint)} --> {format_ts(total_seconds)}",
            "Mock outro to complete subtitles.",
            "",
        ]
    )


def save_json(path: Path, data: Dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="離線模擬 Storytelling 內容生成流程")
    parser.add_argument("--book-id", required=True, help="data/ 下的書籍資料夾名稱")
    parser.add_argument("--config", default="./podcast_config.yaml", help="配置檔路徑")
    parser.add_argument(
        "--chapters",
        default="all",
        help="章節範圍（如 0-5,7 或章節名稱）。預設 all",
    )
    parser.add_argument("--duration", type=float, default=6.0, help="每個音檔的長度（秒）")
    parser.add_argument("--seed", type=int, default=None, help="隨機種子，用於時間戳與 mock 內容")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    config = load_config(args.config)
    book_cfg = resolve_book_config(config, args.book_id)
    chapters_dir = Path(book_cfg["chapters_dir"])
    if not chapters_dir.exists():
        raise SystemExit(f"找不到章節資料夾：{chapters_dir}")

    files = sorted(chapters_dir.glob(book_cfg.get("file_pattern", "chapter*.txt")), key=lambda p: natural_key(p.stem))
    if not files:
        raise SystemExit("章節檔案為空，無法模擬")

    slugs = [f.stem for f in files]
    selected_slugs = parse_range_spec(args.chapters, slugs)
    if not selected_slugs:
        raise SystemExit("沒有符合條件的章節")

    outputs_root = Path(book_cfg.get("outputs_root", "./output")).expanduser().resolve()
    book_name = book_cfg.get("book_name_override") or os.environ.get("STORY_BOOK_NAME") or book_cfg.get("book_id") or chapters_dir.name
    book_output_dir = outputs_root / book_name
    chapters_root = book_output_dir
    sessions_root = book_output_dir / "sessions"
    transcripts_root = Path(config.get("paths", {}).get("transcripts_root", "./data/transcripts")).expanduser().resolve()

    chapters_root.mkdir(parents=True, exist_ok=True)
    sessions_root.mkdir(parents=True, exist_ok=True)
    transcripts_root.mkdir(parents=True, exist_ok=True)

    timestamp = time.strftime("%Y%m%d_%H%M%S")
    basic_cfg = config.get("basic", {})
    narrator_voice = str(basic_cfg.get("narrator_voice", "Aoede") or "Aoede")

    session_entries = []
    for idx, slug in enumerate(slugs, start=1):
        if slug not in selected_slugs:
            continue
        chapter_file = chapters_dir / f"{slug}.txt"
        chapter_dir = chapters_root / slug
        chapter_dir.mkdir(parents=True, exist_ok=True)

        script_text = build_mock_script(chapter_file, idx, narrator_voice)
        script_path = chapter_dir / "podcast_script.txt"
        script_path.write_text(script_text, encoding="utf-8")
        word_count = len(script_text.split())
        source_word_count = len(clean_text(chapter_file.read_text(encoding="utf-8")).split())

        metadata = {
            "timestamp": timestamp,
            "book_name": book_name,
            "book_id": book_cfg.get("book_id", book_name),
            "chapter_number": idx,
            "chapter_title": slug,
            "chapter_slug": slug,
            "source_file": str(chapter_file),
            "source_word_count": source_word_count,
            "actual_words": word_count,
            "narrator_voice": narrator_voice,
            "mock_pipeline": True,
        }
        save_json(chapter_dir / "metadata.json", metadata)

        transcript_name = f"transcript_mock_{slug}_{timestamp}.txt"
        transcript_path = transcripts_root / transcript_name
        transcript_path.write_text(script_text, encoding="utf-8")

        audio_path = chapter_dir / "podcast.wav"
        write_silence_wav(audio_path, max(1.0, args.duration))
        mp3_path = chapter_dir / "podcast.mp3"
        mp3_path.write_bytes(audio_path.read_bytes())

        subtitles_path = chapter_dir / "subtitles.srt"
        subtitles_path.write_text(create_mock_subtitles(max(1.0, args.duration)), encoding="utf-8")

        session_entries.append(
            {
                "chapter_number": idx,
                "chapter_slug": slug,
                "chapter_title": slug,
                "script_dir": str(chapter_dir.resolve()),
                "chapter_dir": str(chapter_dir.resolve()),
                "target_words": word_count,
                "actual_words": word_count,
                "source_file": str(chapter_file),
                "previous_summary_present": False,
                "next_summary_present": False,
            }
        )
        print(f"✅ mock 完成：{slug}")

    chapters_index_file = book_output_dir / "chapters_index.json"
    if chapters_index_file.exists():
        chapters_index = json.loads(chapters_index_file.read_text(encoding="utf-8"))
    else:
        chapters_index = {}
    for entry in session_entries:
        chapters_index[entry["chapter_slug"]] = {
            "chapter_number": entry["chapter_number"],
            "chapter_title": entry["chapter_title"],
            "script_dir": entry["script_dir"],
            "last_script_generated_at": timestamp,
            "source_file": entry["source_file"],
        }
    save_json(chapters_index_file, chapters_index)

    session_manifest = sessions_root / f"mock_session_{timestamp}.json"
    session_payload = {
        "session_type": "mock_generation",
        "book_name": book_name,
        "book_id": book_cfg.get("book_id", book_name),
        "timestamp": timestamp,
        "chapters_dir": str(chapters_dir.resolve()),
        "output_dir": str(book_output_dir.resolve()),
        "script_dirs": [entry["script_dir"] for entry in session_entries],
        "chapters": session_entries,
    }
    save_json(session_manifest, session_payload)

    print(f"🎉 Mock pipeline 完成，共處理 {len(session_entries)} 章；session 檔案：{session_manifest}")


if __name__ == "__main__":
    main()
