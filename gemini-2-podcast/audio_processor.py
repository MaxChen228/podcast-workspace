"""Gemini API-based multi-speaker TTS client."""

from __future__ import annotations

from typing import Dict, Tuple

from google import genai
from google.genai import types as genai_types


class GeminiTTSClient:
    """Generates audio using gemini-2.5-flash* models via the Gemini API."""

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        language_code: str,
        speaker_voice_map: Dict[str, str],
    ) -> None:
        if not api_key:
            raise ValueError("GEMINI_API_KEY is required for audio generation")
        if len(speaker_voice_map) != 2:
            raise ValueError("Exactly two speakers are required for multi-speaker synthesis")

        self._client = genai.Client(api_key=api_key)
        self._model = model
        self._speech_config = genai_types.SpeechConfig(
            language_code=language_code,
            multi_speaker_voice_config=genai_types.MultiSpeakerVoiceConfig(
                speaker_voice_configs=[
                    genai_types.SpeakerVoiceConfig(
                        speaker=alias,
                        voice_config=genai_types.VoiceConfig(
                            prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                                voice_name=voice_name
                            )
                        ),
                    )
                    for alias, voice_name in speaker_voice_map.items()
                ]
            ),
        )

    def synthesize(self, prompt: str) -> Tuple[bytes, str]:
        if not prompt.strip():
            raise ValueError("prompt cannot be empty")

        response = self._client.models.generate_content(
            model=self._model,
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=self._speech_config,
            ),
        )

        for candidate in response.candidates:
            for part in candidate.content.parts:
                if part.inline_data:
                    mime_type = part.inline_data.mime_type or "audio/pcm"
                    return part.inline_data.data, mime_type
        raise RuntimeError("No audio data returned by Gemini TTS response")
