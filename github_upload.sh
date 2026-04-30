#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# github_upload.sh
# Automates creation and population of the GitHub repo:
#   https://github.com/bughunt8/skills-boox-notebook-sync
#
# Usage:
#   chmod +x github_upload.sh
#   ./github_upload.sh
#
# Prerequisites:
#   - git installed
#   - GitHub CLI (gh) installed and authenticated  OR
#     a GITHUB_TOKEN env var set (classic token with repo scope)
#   - This script must be run from the directory containing the skill files
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── config ────────────────────────────────────────────────────────────────────
GITHUB_USER="bughunt8"
REPO_NAME="skills-boox-notebook-sync"
REPO_DESC="Hermes/OpenClaw skill — read Onyx BOOX handwritten notes via Vision LLM OCR (GPT-4o, Claude, Gemini)"
REPO_TOPICS="hermes-skill openclaw boox handwriting ocr vision-llm productivity eink"
BRANCH="main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[upload]${NC} $*"; }
warn()    { echo -e "${YELLOW}[upload]${NC} $*"; }
error()   { echo -e "${RED}[upload]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${CYAN}══ $* ══${NC}"; }

# ── check tools ───────────────────────────────────────────────────────────────
section "Checking prerequisites"
command -v git >/dev/null 2>&1 || error "git not installed. Install it first."

USE_GH=false
USE_TOKEN=false

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH=true
  info "GitHub CLI (gh) detected and authenticated ✓"
elif [ -n "${GITHUB_TOKEN:-}" ]; then
  USE_TOKEN=true
  info "GITHUB_TOKEN env var detected ✓"
else
  echo ""
  warn "Neither 'gh' CLI nor GITHUB_TOKEN found."
  echo "  Option 1 (recommended): Install GitHub CLI"
  echo "    macOS:  brew install gh && gh auth login"
  echo "    Linux:  https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
  echo "    Then re-run this script."
  echo ""
  echo "  Option 2: Set GITHUB_TOKEN"
  echo "    export GITHUB_TOKEN=ghp_your_classic_token_with_repo_scope"
  echo "    Then re-run this script."
  echo ""
  read -rp "Do you want to authenticate with 'gh' now? (y/N): " DO_AUTH
  if [[ "${DO_AUTH,,}" == "y" ]]; then
    gh auth login || error "gh auth login failed."
    USE_GH=true
  else
    error "Cannot proceed without GitHub authentication."
  fi
fi

# ── check if repo already exists ──────────────────────────────────────────────
section "Checking repository"
REPO_EXISTS=false

if $USE_GH; then
  if gh repo view "${GITHUB_USER}/${REPO_NAME}" >/dev/null 2>&1; then
    REPO_EXISTS=true
    warn "Repo ${GITHUB_USER}/${REPO_NAME} already exists — will push to it."
  fi
elif $USE_TOKEN; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}")
  [ "$HTTP_STATUS" -eq 200 ] && REPO_EXISTS=true && warn "Repo already exists."
fi

# ── create repo if needed ─────────────────────────────────────────────────────
if ! $REPO_EXISTS; then
  section "Creating repository: ${GITHUB_USER}/${REPO_NAME}"
  if $USE_GH; then
    gh repo create "${GITHUB_USER}/${REPO_NAME}" \
      --public \
      --description "${REPO_DESC}" \
      --homepage "https://github.com/${GITHUB_USER}/${REPO_NAME}" \
      --confirm 2>/dev/null || \
    gh repo create "${REPO_NAME}" \
      --public \
      --description "${REPO_DESC}" \
      --confirm
    info "Repo created ✓"
  elif $USE_TOKEN; then
    curl -s -X POST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESC}\",\"private\":false,\"auto_init\":false}" \
      "https://api.github.com/user/repos" | grep -q '"full_name"' || error "Failed to create repo via API."
    info "Repo created via API ✓"
  fi
fi

# ── init local git repo ───────────────────────────────────────────────────────
section "Initialising local git"
cd "${SCRIPT_DIR}"

if [ -d ".git" ]; then
  warn ".git already exists — will reset and re-init cleanly."
  rm -rf .git
fi

git init
git checkout -b "${BRANCH}"

# set git identity if not configured
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "${GITHUB_USER}@users.noreply.github.com"
  git config user.name "${GITHUB_USER}"
fi

# ── stage all files ───────────────────────────────────────────────────────────
section "Staging files"
# ensure this upload script itself isn't accidentally committed twice
git add \
  SKILL.md \
  install.sh \
  README.md \
  LICENSE \
  .gitignore \
  scripts/boox_ocr.py \
  references/BOOX_SETUP.md \
  references/PROVIDER_GUIDE.md \
  templates/note_output.md \
  github_upload.sh

echo ""
info "Files staged:"
git status --short
echo ""

# ── commit ────────────────────────────────────────────────────────────────────
section "Committing"
git commit -m "feat: initial release of skills-boox-notebook-sync

- SKILL.md: Hermes/OpenClaw skill definition for BOOX handwriting OCR
- boox_ocr.py: Vision LLM OCR engine (GPT-4o, Claude 3.5, Gemini 1.5 Flash)
- install.sh: one-line installer with venv, deps, and interactive config
- references/: BOOX device setup guide + Vision LLM provider comparison
- templates/: note output template

One-line install:
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/install.sh | bash"

# ── set remote ────────────────────────────────────────────────────────────────
section "Setting remote"
REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

if $USE_TOKEN; then
  # embed token in URL for HTTPS auth
  REMOTE_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
fi

git remote add origin "${REMOTE_URL}"
info "Remote set: https://github.com/${GITHUB_USER}/${REPO_NAME}"

# ── push ──────────────────────────────────────────────────────────────────────
section "Pushing to GitHub"
if $USE_GH; then
  git push -u origin "${BRANCH}"
elif $USE_TOKEN; then
  git push -u origin "${BRANCH}"
fi

info "Push complete ✓"

# ── add topics ────────────────────────────────────────────────────────────────
section "Adding repository topics"
if $USE_GH; then
  # gh repo edit accepts --add-topic
  for topic in $REPO_TOPICS; do
    gh repo edit "${GITHUB_USER}/${REPO_NAME}" --add-topic "$topic" 2>/dev/null || true
  done
  info "Topics added ✓"
elif $USE_TOKEN; then
  TOPICS_JSON=$(echo $REPO_TOPICS | tr ' ' '\n' | jq -R . | jq -sc '{"names":.}')
  curl -s -X PUT \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.mercy-preview+json" \
    -H "Content-Type: application/json" \
    -d "${TOPICS_JSON}" \
    "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/topics" >/dev/null
  info "Topics added via API ✓"
fi

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Repo live: https://github.com/${GITHUB_USER}/${REPO_NAME}${NC}"
echo ""
echo -e "  One-line install for anyone:"
echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/install.sh | bash${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
