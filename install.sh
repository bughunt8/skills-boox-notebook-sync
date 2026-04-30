#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# boox-reader skill — one-line installer for Hermes / OpenClaw agents
#
# Usage (one-line shot):
#   curl -fsSL https://raw.githubusercontent.com/bughunt8/skills-boox-notebook-sync/main/install.sh | bash
#
# Or with options:
#   BOOX_SYNC_PATH=~/Google\ Drive/BOOX BOOX_OCR_PROVIDER=anthropic \
#     curl -fsSL .../install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO="https://github.com/bughunt8/skills-boox-notebook-sync"
RAW="https://raw.githubusercontent.com/bughunt8/skills-boox-notebook-sync/main"
SKILL_DIR="${HOME}/.hermes/skills/productivity/boox-reader"
VENV_DIR="${HOME}/.hermes/skills/productivity/boox-reader/.venv"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[boox-reader]${NC} $*"; }
warn()  { echo -e "${YELLOW}[boox-reader]${NC} $*"; }
error() { echo -e "${RED}[boox-reader]${NC} $*" >&2; exit 1; }

# ── 1. check dependencies ─────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || error "Python 3 is required. Install it first."
command -v curl    >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || error "curl or wget required."

PY_MIN_MINOR=9
PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
[ "$PY_MINOR" -ge "$PY_MIN_MINOR" ] || error "Python 3.${PY_MIN_MINOR}+ required (found 3.${PY_MINOR})."

# ── 2. create skill directory ─────────────────────────────────────────────────
info "Creating skill directory: ${SKILL_DIR}"
mkdir -p "${SKILL_DIR}/scripts" "${SKILL_DIR}/references" "${SKILL_DIR}/templates"

# ── 3. download skill files ───────────────────────────────────────────────────
info "Downloading skill files..."
_dl() {
  local src="$1" dst="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$src" -o "$dst"
  else
    wget -qO "$dst" "$src"
  fi
}

_dl "${RAW}/SKILL.md"              "${SKILL_DIR}/SKILL.md"
_dl "${RAW}/scripts/boox_ocr.py"   "${SKILL_DIR}/scripts/boox_ocr.py"
_dl "${RAW}/references/BOOX_SETUP.md" "${SKILL_DIR}/references/BOOX_SETUP.md"
_dl "${RAW}/references/PROVIDER_GUIDE.md" "${SKILL_DIR}/references/PROVIDER_GUIDE.md"
_dl "${RAW}/templates/note_output.md" "${SKILL_DIR}/templates/note_output.md"

chmod +x "${SKILL_DIR}/scripts/boox_ocr.py"

# ── 4. set up Python venv + dependencies ─────────────────────────────────────
info "Setting up Python virtual environment..."
python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

# base requirements always installed
pip install --quiet --upgrade pip
pip install --quiet pymupdf pillow

# provider-specific installs
PROVIDER="${BOOX_OCR_PROVIDER:-openai}"
info "Installing dependencies for provider: ${PROVIDER}"
case "${PROVIDER}" in
  openai)    pip install --quiet openai ;;
  anthropic) pip install --quiet anthropic ;;
  google)    pip install --quiet google-generativeai ;;
  *)         warn "Unknown provider '${PROVIDER}'. Install the SDK manually." ;;
esac

deactivate

# ── 5. write wrapper script ───────────────────────────────────────────────────
WRAPPER="${SKILL_DIR}/scripts/run_boox_ocr.sh"
cat > "${WRAPPER}" << WRAPEOF
#!/usr/bin/env bash
# Activates the skill venv and runs boox_ocr.py
source "${VENV_DIR}/bin/activate"
python3 "${SKILL_DIR}/scripts/boox_ocr.py" "\$@"
deactivate
WRAPEOF
chmod +x "${WRAPPER}"

# ── 6. write .env template ────────────────────────────────────────────────────
ENV_FILE="${SKILL_DIR}/.env.example"
cat > "${ENV_FILE}" << ENVEOF
# Copy this to ~/.hermes/skills/productivity/boox-reader/.env and fill in your values
# Then source it in your shell profile: source ~/.hermes/skills/productivity/boox-reader/.env

export BOOX_SYNC_PATH="$HOME/Google Drive/BOOX/Notes"
export BOOX_OCR_PROVIDER="openai"          # openai | anthropic | google
export OPENAI_API_KEY="sk-..."
# export ANTHROPIC_API_KEY="sk-ant-..."
# export GOOGLE_API_KEY="AIza..."
export BOOX_READER_LANG_HINT="en"          # ISO 639-1 language code
ENVEOF

# ── 7. interactive config (if running in a terminal) ─────────────────────────
if [ -t 0 ] && [ -t 1 ]; then
  info "Interactive setup..."
  echo ""
  read -rp "  BOOX sync folder path [${HOME}/Documents/BOOX]: " SYNC_PATH_INPUT
  BOOX_SYNC_PATH_FINAL="${SYNC_PATH_INPUT:-${HOME}/Documents/BOOX}"

  read -rp "  OCR provider (openai/anthropic/google) [openai]: " PROVIDER_INPUT
  PROVIDER_FINAL="${PROVIDER_INPUT:-openai}"

  ENV_REAL="${SKILL_DIR}/.env"
  {
    echo "export BOOX_SYNC_PATH=\"${BOOX_SYNC_PATH_FINAL}\""
    echo "export BOOX_OCR_PROVIDER=\"${PROVIDER_FINAL}\""
  } > "${ENV_REAL}"

  info "Config written to ${ENV_REAL}"
  warn "Edit ${ENV_REAL} to add your API key before first use."
  echo ""
fi

# ── 8. register with Hermes if CLI available ──────────────────────────────────
if command -v hermes >/dev/null 2>&1; then
  info "Registering skill with Hermes agent..."
  hermes skills reload 2>/dev/null || true
  info "Skill registered. Run: hermes skills list | grep boox"
else
  warn "Hermes CLI not found. Skill files installed at: ${SKILL_DIR}"
  warn "Copy them to your Openclaw/Hermes skills directory and reload."
fi

# ── 9. verify ─────────────────────────────────────────────────────────────────
info "Verifying installation..."
source "${VENV_DIR}/bin/activate"
python3 -c "import fitz, PIL; print('  ✓ PyMuPDF and Pillow OK')"
deactivate

echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "  boox-reader skill installed successfully!"
info ""
info "  Next steps:"
info "  1. On your BOOX device: Notes → ⋮ → Sync Settings"
info "     → Export to [Google Drive / Dropbox / Syncthing]"
info "     → Format: Vector PDF   → Auto Export: ON"
info ""
info "  2. Set your API key:"
info "     edit ${SKILL_DIR}/.env"
info ""
info "  3. Test it:"
info "     ${WRAPPER} --list"
info "     ${WRAPPER} --file path/to/note.pdf"
info ""
info "  4. Tell your agent:"
info "     'Read my BOOX notes'  or  'Transcribe my latest note'"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
