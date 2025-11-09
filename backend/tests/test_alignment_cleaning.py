from __future__ import annotations

from pathlib import Path
import sys
import types

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if "praatio" not in sys.modules:
    mock_praatio = types.ModuleType("praatio")
    mock_praatio.textgrid = types.SimpleNamespace()
    sys.modules["praatio"] = mock_praatio
    sys.modules["praatio.textgrid"] = mock_praatio.textgrid

from alignment.mfa import clean_script_for_alignment, _tokenize_transcript


def test_clean_script_inserts_spaces_after_dashes_and_periods():
    raw = "forth—Urdree Hardren.but noise…Yomen"
    cleaned = clean_script_for_alignment(raw)

    assert "forth. Urdree" in cleaned
    assert "Hardren. but" in cleaned
    assert "noise. Yomen" in cleaned


def test_tokenize_transcript_splits_glued_words(tmp_path: Path):
    transcript = tmp_path / "chapter_mfa.txt"
    transcript.write_text("forth.Urdree Hardren.but noise.Yomen", encoding="utf-8")

    tokens = _tokenize_transcript(transcript)
    raw_tokens = [raw for raw, normalized in tokens if normalized]

    assert raw_tokens[:4] == ["forth.", "Urdree", "Hardren.", "but"]
    assert "Yomen" in raw_tokens
