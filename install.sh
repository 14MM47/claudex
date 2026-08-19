#!/usr/bin/env bash
# Install the standalone claudex (Codex-reconciler) files into ~/.claude/, and (optionally)
# wire the UserPromptSubmit hook into settings.json.
#
# The other two edits (post-edit-verify.sh, CLAUDE.md) are personal/optional and
# are NOT applied automatically — see edits/ for those.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
DEST="${DEST%/}"   # normalize: a trailing slash would double up in rewritten paths
WIRE_HOOK=1

usage() {
  cat <<'EOF'
Usage: install.sh [--no-wire]
  --no-wire   copy the files only; don't touch settings.json
Environment:
  CLAUDE_HOME  install destination (default: ~/.claude). Installed agent/command
               files are rewritten to reference this path.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-wire) WIRE_HOOK=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; echo "install.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

copy() {  # src-rel  dest-subdir  mode
  install -D -m "$3" "$SRC/$1" "$DEST/$2/$(basename "$1")"
  echo "  installed $DEST/$2/$(basename "$1")"
}

echo "Installing claudex into $DEST ..."
copy scripts/codex_bridge.sh      scripts  755
copy hooks/codex-trigger.sh       hooks    755
copy agents/claudex.md            agents   644
copy commands/check-with-codex.md commands 644

# The agent and command docs reference the default ~/.claude paths; on a custom
# CLAUDE_HOME install, rewrite the installed copies so they point at $DEST.
if [[ "$DEST" != "$HOME/.claude" ]]; then
  # $DEST lands in sed replacement text: escape backslash, the & metachar, and
  # the | delimiter, or such paths abort the install / rewrite silently wrong.
  repl="${DEST//\\/\\\\}"; repl="${repl//&/\\&}"; repl="${repl//|/\\|}"
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  for f in "$DEST/agents/claudex.md" "$DEST/commands/check-with-codex.md"; do
    sed "s|~/\.claude|$repl|g" "$f" > "$tmp"
    cat "$tmp" > "$f"   # cat-into, not mv: keeps the mode set by install
  done
  rm -f "$tmp"
  trap - EXIT
  echo "  rewrote ~/.claude references to $DEST in installed agent/command files"
fi

# --- wire the UserPromptSubmit hook into settings.json (idempotent) ----------
SETTINGS="$DEST/settings.json"
HOOK_CMD="$DEST/hooks/codex-trigger.sh"
if [[ "$WIRE_HOOK" -eq 1 ]]; then
  if command -v jq >/dev/null 2>&1; then
    [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
    tmp="$(mktemp)"
    jq --arg cmd "$HOOK_CMD" '
      .hooks //= {} |
      .hooks.UserPromptSubmit //= [] |
      if any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == $cmd)
      then .
      else .hooks.UserPromptSubmit += [{"hooks":[{"type":"command","command":$cmd,"timeout":10}]}]
      end
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "  wired UserPromptSubmit hook into $SETTINGS (backup alongside)"
  else
    echo "  jq not found — skipping settings.json wiring."
    echo "    Add manually (see edits/settings.json.patch); use this absolute command:"
    echo "      $HOOK_CMD"
  fi
fi

# --- smoke test: can the bridge actually find a codex binary? ----------------
CODEX_STATUS="codex binary NOT found — bridge calls will fail (see warning above)"
if CODEX_PATH="$("$DEST/scripts/codex_bridge.sh" which 2>/dev/null)"; then
  echo "  codex binary: $CODEX_PATH"
  CODEX_STATUS="codex binary found: $CODEX_PATH"
else
  cat >&2 <<WARN
  WARNING: no codex binary found (not on PATH, no openai.chatgpt extension bundle).
  Files are installed, but every bridge call will fail until you either:
    * install and log in to the VS Code / Cursor "openai.chatgpt" extension, or
    * put a standalone codex on PATH, or
    * export CODEX_BIN=/path/to/codex
  Re-check with: $DEST/scripts/codex_bridge.sh which
WARN
fi

cat <<EOF

Done. $CODEX_STATUS
Optional/personal edits NOT applied automatically (review first):
  * Shellcheck enhancement for a post-edit hook: $SRC/edits/post-edit-verify.sh.snippet.md
  * Durable global instruction in CLAUDE.md:      $SRC/edits/CLAUDE.md.snippet.md

The claudex subagent loads on your NEXT Claude Code session.
The bridge and /check-with-codex command work right away.
EOF
