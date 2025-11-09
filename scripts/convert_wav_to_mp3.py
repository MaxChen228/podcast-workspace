#!/usr/bin/env python3
"""Batch convert existing podcast.wav files to podcast.mp3 in-place."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable

from pydub import AudioSegment


def iter_chapter_dirs(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("podcast.wav")):
        yield path.parent


def convert_chapter(chapter_dir: Path, bitrate: str) -> bool:
    wav_path = chapter_dir / "podcast.wav"
    mp3_path = chapter_dir / "podcast.mp3"

    if not wav_path.exists():
        return False

    if mp3_path.exists() and mp3_path.stat().st_mtime >= wav_path.stat().st_mtime:
        print(f"✓ 已存在最新 MP3：{mp3_path}")
        return False

    try:
        audio = AudioSegment.from_file(wav_path, format="wav")
        audio.export(mp3_path, format="mp3", bitrate=bitrate)
        print(f"🎧 已轉換：{mp3_path}")
        return True
    except Exception as exc:  # pragma: no cover - depends on local ffmpeg setup
        print(f"⚠️  轉換失敗 ({wav_path}): {exc}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert podcast.wav files to podcast.mp3")
    parser.add_argument(
        "root",
        nargs="?",
        default="output",
        help="根目錄（預設: output）",
    )
    parser.add_argument(
        "--bitrate",
        default="192k",
        help="MP3 位元率（預設: 192k）",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"❌ 目錄不存在：{root}")
        return 1

    converted = 0
    for chapter_dir in iter_chapter_dirs(root):
        if convert_chapter(chapter_dir, args.bitrate):
            converted += 1

    print(f"Done. 共更新 {converted} 個章節的 MP3。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
