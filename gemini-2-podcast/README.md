
# gemini-2-podcast Setup Guide

A Python-based tool that generates engaging podcast conversations using Google's Gemini 2.5 Flash for scripting and the Gemini 2.5 Flash TTS model via the Gemini API (AI Studio) for multi-speaker narration. Now with multi-language support for generating podcasts in various languages.

[![Gemini 2 Podcast Setup Guide: Transform Content into Pro-Level Podcasts](https://img.youtube.com/vi/9qeiQ4x30Dk/maxresdefault.jpg)](https://www.youtube.com/watch?v=9qeiQ4x30Dk)

## Features
- Converts content from multiple source formats (PDF, URL, TXT, Markdown) into natural conversational scripts.
- Generates high-quality multi-speaker audio using Gemini 2.5 Flash TTS through the Gemini API dashboard tooling.
- Supports multiple languages for podcast generation and narration.
- Automatically chunks long conversations to stay within Gemini prompt-size limits.
- Uses prompt templates so you can tune both script tone and narration without touching code.

## Prerequisites

## System Dependencies

Install `ffmpeg` so `pydub` can read and write WAV segments:

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# macOS
brew install ffmpeg
```

On Windows, download FFmpeg, extract it, and add the `bin` folder to your `PATH`.

## Project Setup

### Clone the Repository:
```bash
git clone https://github.com/yourusername/gemini-2-podcast.git
cd gemini-2-podcast
```

### Create and Activate Virtual Environment:
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

### Install Python Dependencies:
```bash
pip install -r requirements.txt
```

### Create `.env` File with API Keys:
```text
GEMINI_API_KEY=your_gemini_api_key
VOICE_A=Puck
VOICE_B=Kore
TTS_MODEL_NAME=gemini-2.5-flash-tts        # optional override
TTS_MAX_PROMPT_BYTES=3600                  # optional safety limit per batch
```

`VOICE_A` / `VOICE_B` must match the prebuilt voice names listed in the Gemini dashboard (e.g., `Puck`, `Kore`, `Charlie`).

### Gemini API Setup
1. Visit [AI Studio](https://aistudio.google.com/) and enable the **Gemini API** for your Google account/project.
2. Generate an API key and paste it into `GEMINI_API_KEY`.
3. Ensure the key has access to `gemini-2.5-flash-tts` (or your chosen Gemini TTS model) and note the available prebuilt voices.

## Required Files
```text
Ensure these files are present in your project directory:
- generate_podcast.py
- generate_script.py
- generate_audio.py
- system_instructions_script.txt
- system_instructions_audio.txt
- requirements.txt
- README.md
```

## Usage Instructions

### Start the Podcast Generation:

### Multi-Language Support:
The project supports generating podcasts in multiple languages. Specify the desired language using the `--language` option.
If no language is specified, it defaults to English.

Example usage:
```bash
python generate_podcast.py --language spanish
```

```bash
python generate_podcast.py
```

1. When prompted, input content sources:
   ```text
   - PDF files: pdf
   - URLs: url
   - Text files: txt
   - Markdown files: md
   ```
2. Type `done` when finished.
3. Review the generated script in `podcast_script.txt`.
4. Press `Enter` to continue with audio generation or `q` to quit.

### Wait for Audio Generation to Complete:
```text
- The script automatically chunks long conversations to stay under the Gemini prompt limit (~4 KB per batch by default).
- Each chunk is synthesized sequentially and stitched into final_podcast.wav.
```

## Output Specifications
```text
- Audio format: WAV
- Channels: Stereo
- Sample rate: 24000Hz
- Bit depth: 16-bit
```

## Contributing
1. Fork the repository.
2. Create a feature branch.
3. Commit your changes.
4. Push to the branch.
5. Open a Pull Request.

## License
This project is licensed under the MIT License.

## Acknowledgments
- Inspired by NotebookLM's podcast feature.
