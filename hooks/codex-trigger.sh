#!/usr/bin/env bash
# UserPromptSubmit hook: routes explicit "check with codex" requests to the
# codex-reconciler subagent. Pure text injection — no network, no billing.
#
# Fires ONLY on imperative phrasings (ask/check/verify/reconcile ... codex), not
# on incidental mentions of the word "codex", to avoid firing in conversations
# that merely discuss Codex. The injected context is advisory, so the occasional
# false positive is harmless — Claude still decides.
#
# Reads the UserPromptSubmit JSON event on stdin; emits additionalContext on a
# match. Always exits 0 (never blocks prompt submission).
set -euo pipefail

payload="$(cat)"

# Extract the user's prompt text. Prefer jq; fall back to the raw payload.
prompt=""
if command -v jq >/dev/null 2>&1; then
  prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
fi
[[ -z "$prompt" ]] && prompt="$payload"

# Imperative triggers only. bash =~ (POSIX ERE) has no \b, so use grep -E and
# require codex to be the thing *consulted*: a preposition ("with/by codex") or a
# consult verb ("ask codex"). This also rejects incidental mentions like
# "check how the codex directory is laid out".
trigger=0
if printf '%s' "$prompt" | grep -iqE \
   -e '(check|verify|reconcile|confirm|cross[ -]?check|sanity[ -]?check|run (this|it|that)|second opinion|double[ -]?check)[^.]{0,40}(with|by) codex' \
   -e '(ask|consult|query|loop in|run by) +codex' \
   -e "codex('?s)?[^.]{0,30}(opinion|take|sign[ -]?off|to review|(should )?review (this|the|it|that|my))" \
   -e '(get|grab|want|need)[^.]{0,20}(second )?(opinion|take|view)[^.]{0,30}codex' ; then
  trigger=1
fi

if [[ "$trigger" -eq 1 ]]; then
  cat <<'CTX'
[codex-trigger] The user appears to be asking to verify/reconcile something with Codex.
If that reading is correct, handle it via the `codex-reconciler` subagent (or the
`/check-with-codex` command) rather than a one-off codex call: launch the Agent with
subagent_type "codex-reconciler", passing the issue, your current position with
file:line evidence, and the repo root. It runs a verified multi-round Claude<->Codex
debate. Note each Codex turn is a billed OpenAI call. If the user only mentioned Codex
in passing (not asking to verify), ignore this note.
CTX
fi
exit 0
