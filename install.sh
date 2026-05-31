#!/usr/bin/env bash
# Install the standalone codex-reconciler files into ~/.claude/, and (optionally)
# wire the UserPromptSubmit hook into settings.json.
#
# The other two edits (post-edit-verify.sh, CLAUDE.md) are personal/optional and
# are NOT applied automatically — see edits/ for those.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
WIRE_HOOK=1
[[ "${1:-}" == "--no-wire" ]] && WIRE_HOOK=0

copy() {  # src-rel  dest-subdir  mode
  install -D -m "$3" "$SRC/$1" "$DEST/$2/$(basename "$1")"
  echo "  installed $DEST/$2/$(basename "$1")"
}

echo "Installing codex-reconciler into $DEST ..."
copy scripts/codex_bridge.sh      scripts  755
copy hooks/codex-trigger.sh       hooks    755
copy agents/codex-reconciler.md   agents   644
copy commands/check-with-codex.md commands 644

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

cat <<EOF

Done. Optional/personal edits NOT applied automatically (review first):
  * Shellcheck enhancement for a post-edit hook: $SRC/edits/post-edit-verify.sh.snippet.md
  * Durable global instruction in CLAUDE.md:      $SRC/edits/CLAUDE.md.snippet.md

The codex-reconciler subagent loads on your NEXT Claude Code session.
The bridge and /check-with-codex command work right away.
EOF
