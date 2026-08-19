#!/usr/bin/env bash
# Regression test for the codex-trigger.sh UserPromptSubmit hook: it must fire on
# explicit "check with codex" imperatives and stay silent on incidental mentions.
# No network, no Codex calls — pure regex behavior. Run: tests/test_codex_trigger.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/codex-trigger.sh"
[[ -x "$HOOK" ]] || { echo "FATAL: hook not executable: $HOOK"; exit 2; }

pass=0 fail=0

fired() {  # returns 0 if the hook emitted output for the given prompt
  local prompt="$1" out
  if command -v jq >/dev/null 2>&1; then
    out="$(printf '{"prompt":%s}' "$(printf '%s' "$prompt" | jq -Rs .)" | "$HOOK")"
  else
    out="$(printf '%s' "$prompt" | "$HOOK")"   # hook falls back to raw payload
  fi
  [[ -n "$out" ]]
}

expect_fire() {
  if fired "$1"; then echo "ok   FIRE   | $1"; pass=$((pass+1))
  else echo "FAIL want-FIRE got-silent | $1"; fail=$((fail+1)); fi
}
expect_silent() {
  if fired "$1"; then echo "FAIL want-silent got-FIRE | $1"; fail=$((fail+1))
  else echo "ok   silent | $1"; pass=$((pass+1)); fi
}

# --- should FIRE (explicit imperative to consult Codex) ---
expect_fire "check with codex whether this auth logic is correct"
expect_fire "ask codex about the egress invariant"
expect_fire "can you verify this with codex?"
expect_fire "get codex's opinion on the diff"
expect_fire "let's reconcile this design with codex"
expect_fire "run it by codex"
expect_fire "double-check the migration with codex"
expect_fire "check with claudex whether the cache key is stable"
expect_fire "run claudex on this diff"
expect_fire "ask claudex about the retry logic"

# --- should stay SILENT (incidental mention of the word "codex") ---
expect_silent "what does the codex binary live in?"
expect_silent "explain how codex sessions are stored"
expect_silent "check how the codex directory is laid out"
expect_silent "the codex directory belongs to openai"
expect_silent "can you converse with codex?"
expect_silent "rename the claudex repo directory"

echo "-----------------------------------------"
echo "PASS=$pass FAIL=$fail"
[[ "$fail" -eq 0 ]]
