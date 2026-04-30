---
name: boox-reader
description: >
  Read and transcribe handwritten notes from Onyx BOOX tablets (Note Air, Note Max,
  Tab Ultra, etc.) using Vision LLM OCR. Watches a sync folder (Google Drive, Dropbox,
  Syncthing, or local path) for new PDFs/PNGs exported by the BOOX device, converts
  them to structured text via GPT-4o or Claude 3.5, and returns clean Markdown output
  the agent can reason over, summarise, or act upon.
version: 1.0.0
author: boox-reader contributors
license: MIT
platforms: [macos, linux, windows]
metadata:
  hermes:
    tags: [Productivity, OCR, Handwriting, BOOX, Notes, Vision]
    related_skills: [pdf-reader, google-drive, notion-sync]
required_environment_variables:
  - name: BOOX_SYNC_PATH
    prompt: "Absolute path to the folder where BOOX exports PDFs/PNGs (e.g. ~/Google Drive/BOOX/Notes)"
    help: "Set this to the local folder synced from your BOOX device via Google Drive, Dropbox, or Syncthing"
    required_for: "Watching for new notes"
  - name: BOOX_OCR_PROVIDER
    prompt: "Vision LLM provider to use for OCR: openai | anthropic | google"
    help: "openai uses gpt-4o; anthropic uses claude-3-5-sonnet; google uses gemini-1.5-flash"
    required_for: "Handwriting transcription"
  - name: OPENAI_API_KEY
    prompt: "OpenAI API key (required only if BOOX_OCR_PROVIDER=openai)"
    help: "https://platform.openai.com/api-keys"
    required_for: "OCR via GPT-4o"
  - name: ANTHROPIC_API_KEY
    prompt: "Anthropic API key (required only if BOOX_OCR_PROVIDER=anthropic)"
    help: "https://console.anthropic.com/settings/keys"
    required_for: "OCR via Claude"
  - name: GOOGLE_API_KEY
    prompt: "Google AI Studio API key (required only if BOOX_OCR_PROVIDER=google)"
    help: "https://aistudio.google.com/app/apikey"
    required_for: "OCR via Gemini"
config:
  - key: boox_reader.output_format
    description: "Output format for transcribed notes: markdown | json | plain"
    default: "markdown"
    prompt: "Output format"
  - key: boox_reader.watch_mode
    description: "Enable continuous folder watcher (true) or process on-demand (false)"
    default: "false"
    prompt: "Enable watch mode?"
  - key: boox_reader.preserve_structure
    description: "Attempt to preserve headings, bullet lists, and table structure from handwriting"
    default: "true"
    prompt: "Preserve note structure?"
  - key: boox_reader.language_hint
    description: "Primary language of handwriting (ISO 639-1 code, e.g. en, zh, ja)"
    default: "en"
    prompt: "Handwriting language"
---

# BOOX Reader Skill

Transcribe handwritten BOOX notes using Vision LLM OCR and return structured Markdown
your agent can reason over, summarise, or pass to other skills.

## When to Use

Load this skill when the user says any of:
- "Read my BOOX notes"
- "Transcribe my handwriting"
- "What did I write in my notebook?"
- "Summarise my handwritten notes"
- "Import my BOOX note [filename]"
- "Process the latest note from my BOOX"
- Anything involving a `.pdf` or `.png` file from a known BOOX sync path

## Quick Reference

| Action | Command / Method |
|---|---|
| Transcribe a single PDF | `python scripts/boox_ocr.py --file path/to/note.pdf` |
| Transcribe all new files | `python scripts/boox_ocr.py --watch-once` |
| Start continuous watcher | `python scripts/boox_ocr.py --watch` |
| List available notes | `python scripts/boox_ocr.py --list` |
| Output as JSON | `python scripts/boox_ocr.py --file note.pdf --format json` |
| Specify language | `python scripts/boox_ocr.py --file note.pdf --lang zh` |

## Procedure

### Step 1 — Locate the Note

1. Check if the user specified a filename or path.
2. If not, run `python scripts/boox_ocr.py --list` to show available notes in `$BOOX_SYNC_PATH`.
3. If `$BOOX_SYNC_PATH` is unset, prompt the user: "Where does your BOOX sync its exported PDFs?"
4. Present the list and confirm which note to process.

### Step 2 — Run OCR

5. Run the OCR command for the chosen file:
   ```
   python scripts/boox_ocr.py --file "<path>" --provider $BOOX_OCR_PROVIDER --lang $BOOX_READER_LANG_HINT
   ```
6. The script outputs Markdown to stdout and saves a `.md` sidecar file next to the source.
7. Capture the output as `NOTE_CONTENT`.

### Step 3 — Present and Act

8. Show the transcribed note to the user.
9. Ask: "Would you like me to summarise, extract action items, or save this somewhere?"
10. Proceed with any follow-up task (summarise, push to Notion, create GitHub issue, etc.).

### Step 4 — Watch Mode (optional)

If the user wants continuous processing:
```
python scripts/boox_ocr.py --watch &
```
The watcher polls `$BOOX_SYNC_PATH` every 30 seconds, transcribes new files,
and logs results to `~/.hermes/logs/boox-reader.log`.

## Pitfalls

- **No API key set**: Check `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GOOGLE_API_KEY` matches the chosen provider.
- **BOOX exports as `.note` format**: The `.note` format is proprietary. Make sure BOOX is set to export as PDF or PNG (Settings → Notes → Auto Export Format → PDF).
- **Multi-page notes**: PDFs with many pages consume significant tokens; the script splits pages > 10 into batches.
- **Poor OCR on very light strokes**: Try the `--enhance` flag which applies contrast boosting before sending to the Vision API.
- **Google Drive not synced yet**: If the file was just saved on BOOX, wait 30–60 s for Drive sync to propagate before running.
- **Path with spaces**: Always quote the `--file` path argument.
- **Rate limits**: For large batch runs, the script adds a 1 s delay between pages. Use `--delay 2` if hitting 429 errors.

## Verification

After OCR completes, verify:
1. The `.md` sidecar file exists next to the source PDF.
2. The output contains coherent sentences, not garbled characters.
3. Run `python scripts/boox_ocr.py --verify last` to re-read the last transcription and display a confidence estimate.
4. If accuracy is low, try `--provider anthropic` or `--enhance` and compare results.
