#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_boox_ocr.sh — venv wrapper for boox_ocr.py
#
# Activates the isolated Python virtual environment created by install.sh,
# then delegates all arguments to boox_ocr.py.
#
# Usage:
#   run_boox_ocr.sh --list
#   run_boox_ocr.sh --file path/to/note.pdf
#   run_boox_ocr.sh --file note.pdf --provider anthropic --lang zh
#   run_boox_ocr.sh --watch-once
#   run_boox_ocr.sh --watch &
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── resolve paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"           # parent of scripts/
VENV_DIR="${SKILL_DIR}/.venv"
OCR_SCRIPT="${SCRIPT_DIR}/boox_ocr.py"

# ── sanity checks ──────────────────────────────────────────────────────────────
if [ ! -f "${OCR_SCRIPT}" ]; then
  echo "[boox-reader] ERROR: OCR script not found: ${OCR_SCRIPT}" >&2
  echo "  Re-run the installer: curl -fsSL https://raw.githubusercontent.com/bughunt8/skills-boox-notebook-sync/main/install.sh | bash" >&2
  exit 1
fi

if [ ! -d "${VENV_DIR}" ]; then
  echo "[boox-reader] ERROR: Virtual environment not found: ${VENV_DIR}" >&2
  echo "  Re-run the installer to set up dependencies." >&2
  exit 1
fi

# ── source .env if present ────────────────────────────────────────────────────
ENV_FILE="${SKILL_DIR}/.env"
if [ -f "${ENV_FILE}" ]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

# ── activate venv and run ─────────────────────────────────────────────────────
# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"
python3 "${OCR_SCRIPT}" "$@"
deactivate
