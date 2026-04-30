<div align="center">

# 📓 skills-boox-notebook-sync

### Read your BOOX handwritten notes with an AI agent

**One-line install · Works with Hermes Agent & OpenClaw · GPT-4o / Claude / Gemini**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Hermes Compatible](https://img.shields.io/badge/Hermes-Compatible-blue)](https://hermes-agent.nousresearch.com)
[![OpenClaw Compatible](https://img.shields.io/badge/OpenClaw-Compatible-purple)](https://openclawlaunch.com)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue)](https://python.org)

</div>

---

## What This Does

`boox-reader` is a **Hermes Agent / OpenClaw skill** that lets your AI agent
**read your handwritten BOOX notes** using Vision LLM OCR.

```
You:    "Read my latest BOOX note and summarise the action items"

Agent:  [Loads boox-reader skill]
        [Finds note.pdf in your Google Drive sync folder]
        [Sends pages to GPT-4o / Claude / Gemini]
        [Returns clean Markdown transcript]

        Here's what you wrote:
        ## Meeting Notes — Project Alpha
        - Follow up with design team by Friday
        - Review API spec (marked with asterisk)
        ...
```

---

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/bughunt8/skills-boox-notebook-sync/main/install.sh | bash
```

The installer will:
1. Create `~/.hermes/skills/productivity/boox-reader/`
2. Download SKILL.md + Python OCR script
3. Set up an isolated Python venv with required dependencies
4. Walk you through config interactively
5. Register the skill with Hermes (if CLI available)

---

## Prerequisites

| Requirement | Details |
|---|---|
| BOOX device | Any model with Notes app (Note Air, Note Max, Tab Ultra, etc.) |
| Python | 3.9 or higher |
| Hermes Agent or OpenClaw | Any version with skill support |
| Vision LLM API key | OpenAI, Anthropic, or Google (choose one) |
| Sync method | Google Drive, Dropbox, or Syncthing |

---

## Quick Setup (5 steps)

### Step 1 — Configure Your BOOX Device

1. Open **Notes** app → **☰ Settings → Sync Settings**
2. Set **Export Format** → **Vector PDF**
3. Enable **Auto Export** (exports PDF every time you close a note)
4. Set **Export Destination** → Google Drive / Dropbox folder

See [`references/BOOX_SETUP.md`](references/BOOX_SETUP.md) for detailed sync options including Syncthing.

### Step 2 — Install the Skill

```bash
curl -fsSL https://raw.githubusercontent.com/bughunt8/skills-boox-notebook-sync/main/install.sh | bash
```

### Step 3 — Set Your API Key

Edit the generated `.env` file:
```bash
nano ~/.hermes/skills/productivity/boox-reader/.env
```

```bash
export BOOX_SYNC_PATH="$HOME/Google Drive/BOOX/Notes"
export BOOX_OCR_PROVIDER="openai"   # or: anthropic | google
export OPENAI_API_KEY="sk-..."
```

Source it in your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
echo 'source ~/.hermes/skills/productivity/boox-reader/.env' >> ~/.zshrc
```

### Step 4 — Test the Script Directly

```bash
# List available notes
~/.hermes/skills/productivity/boox-reader/scripts/run_boox_ocr.sh --list

# Transcribe a specific note
~/.hermes/skills/productivity/boox-reader/scripts/run_boox_ocr.sh \
  --file ~/Google\ Drive/BOOX/Notes/meeting_2026_04_29.pdf
```

### Step 5 — Tell Your Agent

```
"Read my BOOX notes"
"Transcribe the latest note from my BOOX"
"What did I write in meeting_2026_04_29?"
"Summarise all unprocessed BOOX notes"
```

---

## Choosing a Vision LLM Provider

| Provider | Best For | Cost |
|---|---|---|
| **OpenAI GPT-4o** | Best English accuracy, structured output | ~$0.10–0.20 / 5-page note |
| **Anthropic Claude 3.5** | Complex handwriting, CJK scripts, privacy | ~$0.08–0.15 / 5-page note |
| **Google Gemini 1.5 Flash** | Bulk processing, lowest cost | ~$0.01–0.03 / 5-page note |

See [`references/PROVIDER_GUIDE.md`](references/PROVIDER_GUIDE.md) for full comparison.

---

## Architecture

```
BOOX Device
  └── Auto-exports PDF on note close
        │
        ▼
Sync Layer (choose one)
  ├── Google Drive  ──┐
  ├── Dropbox         ├──► Local sync folder ($BOOX_SYNC_PATH)
  └── Syncthing ──────┘
                            │
                            ▼
                  boox_ocr.py (this skill)
                  ├── Splits PDF into page images (PyMuPDF)
                  ├── Optionally enhances contrast (Pillow)
                  ├── Sends pages to Vision LLM API
                  │     ├── OpenAI GPT-4o
                  │     ├── Anthropic Claude 3.5
                  │     └── Google Gemini 1.5 Flash
                  └── Returns structured Markdown
                            │
                            ▼
                  Hermes / OpenClaw Agent
                  └── Reasons, summarises, acts on transcript
```

---

## Skill Directory Structure

```
~/.hermes/skills/productivity/boox-reader/
├── SKILL.md                    ← Agent-readable skill instructions
├── scripts/
│   ├── boox_ocr.py             ← Core OCR engine (Python)
│   └── run_boox_ocr.sh         ← Venv wrapper script
├── references/
│   ├── BOOX_SETUP.md           ← BOOX device setup guide
│   └── PROVIDER_GUIDE.md       ← Vision LLM provider comparison
├── templates/
│   └── note_output.md          ← Output template
├── .venv/                      ← Isolated Python environment
├── .env                        ← Your API keys and config (gitignored)
└── .env.example                ← Template for .env
```

---

## Advanced Usage

### Watch Mode (Auto-Process New Notes)

```bash
# Process all unprocessed notes and exit
~/.hermes/skills/productivity/boox-reader/scripts/run_boox_ocr.sh --watch-once

# Run as a background daemon (processes new notes every 30s)
~/.hermes/skills/productivity/boox-reader/scripts/run_boox_ocr.sh --watch &
```

Add to a systemd service or launchd plist for always-on processing.

### CJK / Non-Latin Handwriting

```bash
# Traditional Chinese (Hong Kong / Taiwan)
run_boox_ocr.sh --file note.pdf --lang zh-TW --provider anthropic

# Japanese
run_boox_ocr.sh --file note.pdf --lang ja

# Mixed English + Chinese
run_boox_ocr.sh --file note.pdf --lang "en,zh-TW"
```

### Low-Contrast / Light Strokes

```bash
# Apply contrast enhancement before OCR
run_boox_ocr.sh --file note.pdf --enhance
```

### JSON Output (for Piping to Other Tools)

```bash
run_boox_ocr.sh --file note.pdf --format json | jq .content
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `No PDF files found` | Check `BOOX_SYNC_PATH` is set and the BOOX has synced |
| `BOOX exports .note format` | Enable Auto Export PDF in BOOX Notes settings |
| `ModuleNotFoundError: fitz` | Re-run: `pip install pymupdf` in the skill venv |
| `429 rate limit error` | Add `--delay 3` to space out API calls |
| `Garbled output` | Try `--enhance` flag or switch to `--provider anthropic` |
| `Hermes can't find skill` | Run `hermes skills reload` or restart agent |
| `API key not found` | Source your `.env`: `source ~/.hermes/skills/.../boox-reader/.env` |

---

## Contributing

PRs welcome! Key areas for improvement:
- Support for `.note` format parsing (reverse-engineered)
- Local OCR fallback (Tesseract + Kraken)
- Obsidian vault output integration
- Notion / Logseq push integration

---

## License

MIT © boox-reader contributors
