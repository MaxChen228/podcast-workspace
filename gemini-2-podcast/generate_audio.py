"""Generate podcast audio using Gemini 2.5 Flash TTS via the Gemini API."""

from __future__ import annotations

import io
import os
from typing import Dict, List

from dotenv import load_dotenv
from pydub import AudioSegment

from audio_processor import GeminiTTSClient

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
VOICE_A = os.getenv("VOICE_A", "Puck").strip()
VOICE_B = os.getenv("VOICE_B", "Kore").strip()
TTS_MODEL_NAME = os.getenv("TTS_MODEL_NAME", "gemini-2.5-flash-tts")
TTS_LANGUAGE_CODE = os.getenv("TTS_LANGUAGE_CODE", "en-US")
PROMPT_BYTE_LIMIT = int(os.getenv("TTS_MAX_PROMPT_BYTES", 3600))
SILENCE_DURATION_MS = int(os.getenv("TTS_SILENCE_MS", 50))

SPEAKER_ALIASES = {
    "Speaker A:": "SpeakerA",
    "Speaker B:": "SpeakerB",
}


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as src:
        return src.read()


def extract_turns(script_text: str) -> List[Dict[str, str]]:
    turns: List[Dict[str, str]] = []
    for raw_line in script_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        for label, alias in SPEAKER_ALIASES.items():
            if line.startswith(label):
                spoken_text = line[len(label) :].strip()
                if not spoken_text:
                    raise ValueError(f"No dialogue found after label '{label}'")
                turns.append({"speaker": alias, "text": spoken_text})
                break
        else:
            raise ValueError(
                "Script must contain lines that begin with 'Speaker A:' or 'Speaker B:'"
            )
    if not turns:
        raise ValueError("Podcast script is empty; run generate_script.py first")
    return turns


def chunk_turns(turns: List[Dict[str, str]], available_bytes: int) -> List[List[Dict[str, str]]]:
    if available_bytes <= 0:
        raise ValueError("Prompt byte limit must be greater than zero")

    batches: List[List[Dict[str, str]]] = []
    current: List[Dict[str, str]] = []
    current_bytes = 0

    for turn in turns:
        line = f"{turn['speaker']}: {turn['text']}\n"
        line_bytes = len(line.encode("utf-8"))
        if line_bytes > available_bytes:
            raise ValueError(
                "A single dialogue line exceeds the allowed prompt size. "
                "Consider splitting that turn into shorter sentences."
            )

        if current and current_bytes + line_bytes > available_bytes:
            batches.append(current)
            current = []
            current_bytes = 0

        current.append(turn)
        current_bytes += line_bytes

    if current:
        batches.append(current)

    return batches


def format_prompt(system_instructions: str, turns: List[Dict[str, str]]) -> str:
    dialogue_block = "\n".join(f"{turn['speaker']}: {turn['text']}" for turn in turns)
    return f"{system_instructions.strip()}\n\n{dialogue_block}".strip()


def audio_bytes_to_segment(audio_bytes: bytes, mime_type: str) -> AudioSegment:
    if mime_type == "audio/wav":
        return AudioSegment.from_file(io.BytesIO(audio_bytes), format="wav")
    # Default to 24kHz mono PCM
    return AudioSegment(
        data=audio_bytes,
        sample_width=2,
        frame_rate=24000,
        channels=1,
    )


def synthesize_chunks(
    client: GeminiTTSClient,
    system_instructions: str,
    batches: List[List[Dict[str, str]]],
) -> List[AudioSegment]:
    audio_segments: List[AudioSegment] = []

    for index, batch in enumerate(batches, start=1):
        prompt = format_prompt(system_instructions, batch)
        if len(prompt.encode("utf-8")) > PROMPT_BYTE_LIMIT:
            raise ValueError(
                "Prompt exceeded the maximum byte limit even after chunking. "
                "Try reducing system instructions or lowering chunk size."
            )
        print(f"Synthesizing batch {index}/{len(batches)}...")
        audio_bytes, mime_type = client.synthesize(prompt)
        audio_segments.append(audio_bytes_to_segment(audio_bytes, mime_type))

    return audio_segments


def combine_segments(segments: List[AudioSegment], output_path: str) -> None:
    combined = AudioSegment.empty()
    silence = AudioSegment.silent(duration=SILENCE_DURATION_MS)

    for segment in segments:
        combined += segment.set_channels(2) + silence

    combined.export(output_path, format="wav")


def main() -> None:
    system_instructions = read_text("system_instructions_audio.txt")
    script_text = read_text("podcast_script.txt")
    turns = extract_turns(script_text)
    instructions_bytes = len(system_instructions.strip().encode("utf-8")) + 2
    available_bytes = PROMPT_BYTE_LIMIT - instructions_bytes
    if available_bytes <= 0:
        raise ValueError("System instructions exceed the configured prompt byte limit")

    batches = chunk_turns(turns, available_bytes)

    client = GeminiTTSClient(
        api_key=GEMINI_API_KEY,
        model=TTS_MODEL_NAME,
        language_code=TTS_LANGUAGE_CODE,
        speaker_voice_map={
            "SpeakerA": VOICE_A,
            "SpeakerB": VOICE_B,
        },
    )

    segments = synthesize_chunks(client, system_instructions, batches)
    if not segments:
        raise RuntimeError("No audio segments were generated")

    combine_segments(segments, "final_podcast.wav")
    print("Final podcast audio created: final_podcast.wav")


if __name__ == "__main__":
    main()
