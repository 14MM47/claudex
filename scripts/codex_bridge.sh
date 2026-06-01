#!/usr/bin/env bash
# codex_bridge.sh — minimal, robust primitive for prompting OpenAI Codex (GPT-5.x)
# non-interactively from Claude Code, with multi-turn session resume.
#
# Codex ships as a binary inside the VS Code "openai.chatgpt" extension rather
# than on PATH. This script locates the newest such binary and drives its
# `exec` / `exec resume` subcommands, capturing the assistant's final message.
#
# Auth is read from ~/.codex/auth.json (whatever you logged into in the IDE).
# Every call is a real, BILLED request to OpenAI.
#
# Usage:
#   codex_bridge.sh start [--cd DIR] [--state BASE] (PROMPT | --prompt-file F | -)
#   codex_bridge.sh reply [--cd DIR] [--state BASE] (PROMPT | --prompt-file F | -)
#   codex_bridge.sh session [--state BASE]      # print stored session id
#   codex_bridge.sh which                       # print resolved codex binary
#
# A "thread" is identified by --state BASE (a path prefix). The script writes:
#   ${BASE}.sid    last session id
#   ${BASE}.reply  Codex's last final message (also echoed to stdout)
#   ${BASE}.log    raw transcript of the last call (for debugging)
# Default BASE: ${CLAUDE_JOB_DIR:-${TMPDIR:-/tmp}}/codex_bridge_default
#
# Env overrides:
#   CODEX_BRIDGE_SANDBOX   sandbox mode (default: read-only)
#   CODEX_BRIDGE_TIMEOUT   seconds before giving up (default: 300)
#   CODEX_BIN              explicit path to codex binary (skips auto-detect)
set -euo pipefail

die() { echo "codex_bridge: $*" >&2; exit 2; }

find_codex() {
  # 1) Explicit override.
  if [[ -n "${CODEX_BIN:-}" ]]; then
    [[ -x "$CODEX_BIN" ]] || die "CODEX_BIN not executable: $CODEX_BIN"
    printf '%s\n' "$CODEX_BIN"; return
  fi
  # 2) A standalone codex on PATH (npm -g @openai/codex, brew, etc.).
  local onpath
  if onpath="$(command -v codex 2>/dev/null)"; then
    printf '%s\n' "$onpath"; return
  fi
  # 3) The binary bundled inside the VS Code / Cursor "openai.chatgpt" extension.
  #    The bin subdir follows VS Code's <os>-<arch> convention.
  local os arch plat
  case "$(uname -s)" in
    Linux)  os=linux ;;
    Darwin) os=darwin ;;
    *)      os=unknown ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  [[ "$os" == darwin ]] && arch=x64 || arch=x86_64 ;;
    arm64|aarch64) arch=arm64 ;;
    *)             arch="$(uname -m)" ;;
  esac
  plat="$os-$arch"

  local roots=(
    "${VSCODE_EXTENSIONS:-}"
    "$HOME/.vscode/extensions"
    "$HOME/.vscode-server/extensions"
    "$HOME/.vscode-insiders/extensions"
    "$HOME/.cursor/extensions"
    "$HOME/.cursor-server/extensions"
    "$HOME/.windsurf/extensions"
  )

  # WSL: VS Code / Cursor usually run on the Windows host, so the extension
  # (and its bundled linux-x86_64 codex) lives under /mnt/<drive>/Users/<user>.
  # Append any such dirs; the version-sort below still picks the newest bundle.
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    local w
    for w in /mnt/*/Users/*/.vscode/extensions /mnt/*/Users/*/.cursor/extensions; do
      [[ -d "$w" ]] && roots+=("$w")
    done
  fi

  local pat r cand
  # Prefer the platform-specific bin dir; fall back to any bin/*/codex.
  for pat in "$plat" "*"; do
    for r in "${roots[@]}"; do
      [[ -n "$r" && -d "$r" ]] || continue
      # Controlled glob over a known extension layout; ls+sort -V picks the
      # newest extension version (find not needed — no hostile names: SC2012).
      # $pat is intentionally unquoted so it can expand as a glob when "*": SC2086.
      # shellcheck disable=SC2012,SC2086
      cand="$(ls -d "$r"/openai.chatgpt-*/bin/$pat/codex 2>/dev/null | sort -V | tail -1 || true)"
      [[ -n "$cand" && -x "$cand" ]] && { printf '%s\n' "$cand"; return; }
    done
  done
  die "no codex binary found: not on PATH, and no openai.chatgpt extension bundle (looked for bin/$plat/codex under VS Code/Cursor extension dirs). Set CODEX_BIN to override."
}

SANDBOX="${CODEX_BRIDGE_SANDBOX:-read-only}"
TIMEOUT="${CODEX_BRIDGE_TIMEOUT:-300}"
DEFAULT_BASE="${CLAUDE_JOB_DIR:-${TMPDIR:-/tmp}}/codex_bridge_default"

# --- arg parse ---------------------------------------------------------------
[[ $# -ge 1 ]] || die "no subcommand (start|reply|session|which)"
SUB="$1"; shift

CD=""
BASE="$DEFAULT_BASE"
PROMPT=""
PROMPT_FILE=""
READ_STDIN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) CD="$2"; shift 2 ;;
    --state) BASE="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    -) READ_STDIN=1; shift ;;
    --) shift; PROMPT="$*"; break ;;
    *) PROMPT="$1"; shift ;;
  esac
done
mkdir -p "$(dirname "$BASE")"

case "$SUB" in
  which)   find_codex; exit 0 ;;
  session) if [[ -f "${BASE}.sid" ]]; then cat "${BASE}.sid"; else die "no session for state $BASE"; fi; exit 0 ;;
  start|reply) : ;;
  *) die "unknown subcommand: $SUB" ;;
esac

# Resolve the prompt text.
if [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || die "prompt file not found: $PROMPT_FILE"
  PROMPT="$(cat "$PROMPT_FILE")"
elif [[ "$READ_STDIN" -eq 1 ]]; then
  PROMPT="$(cat)"
fi
[[ -n "$PROMPT" ]] || die "empty prompt"

CODEX="$(find_codex)"
COMMON=(exec --sandbox "$SANDBOX" --skip-git-repo-check --color never
        -o "${BASE}.reply")

run() {  # runs codex in the target dir, capturing transcript to ${BASE}.log
  local dir="${CD:-$PWD}"
  ( cd "$dir" && timeout "$TIMEOUT" "$CODEX" "$@" ) >"${BASE}.log" 2>&1
}

if [[ "$SUB" == "start" ]]; then
  : >"${BASE}.reply"
  if ! printf '%s' "$PROMPT" | run "${COMMON[@]}" -; then
    echo "----- codex transcript (start failed) -----" >&2
    tail -40 "${BASE}.log" >&2 || true
    die "codex exec failed (see above)"
  fi
  # session id appears as 'session id: <uuid>' in the transcript
  SID=$(grep -aoE 'session id: [0-9a-fA-F-]{36}' "${BASE}.log" | head -1 | awk '{print $3}')
  [[ -n "$SID" ]] && printf '%s' "$SID" >"${BASE}.sid" || echo "codex_bridge: warning: could not capture session id" >&2
else  # reply
  [[ -f "${BASE}.sid" ]] || die "no prior session for state $BASE — call 'start' first"
  SID="$(cat "${BASE}.sid")"
  : >"${BASE}.reply"
  # `exec resume` does NOT accept --sandbox; sandbox is set via -c config override.
  if ! printf '%s' "$PROMPT" | run exec resume "$SID" --skip-git-repo-check \
        -c "sandbox_mode=\"$SANDBOX\"" -o "${BASE}.reply" -; then
    echo "----- codex transcript (resume failed) -----" >&2
    tail -40 "${BASE}.log" >&2 || true
    die "codex exec resume failed (see above)"
  fi
fi

if [[ ! -s "${BASE}.reply" ]]; then
  echo "----- codex transcript (empty reply) -----" >&2
  tail -40 "${BASE}.log" >&2 || true
  die "codex produced no final message"
fi
cat "${BASE}.reply"
