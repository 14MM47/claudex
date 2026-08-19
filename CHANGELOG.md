# Changelog

## Unreleased

- Portable installer for stock macOS/BSD: `mkdir -p` + `install -m` instead of
  GNU-only `install -D`.
- Bridge auto-detects GNU `timeout` or brew's `gtimeout`; refuses to run with
  neither rather than make an unbounded billed call.
- macOS CI job (`macos-latest`): both test suites plus a scratch install with a
  stubbed codex binary and a space-containing custom `CLAUDE_HOME`.

## v0.1.0 — 2026-08-19

First tagged release.

- Codex bridge (`scripts/codex_bridge.sh`): non-interactive `exec` /
  `exec resume` with multi-turn session threading, read-only sandbox default.
- `claudex` subagent, `/check-with-codex` command, `UserPromptSubmit` trigger
  hook, reference `edits/` snippets.
- Hardened installer: unknown-argument rejection, `--help`, post-install codex
  discoverability smoke test, custom `CLAUDE_HOME` support with safe path
  rewriting (sed-escaped for `& | \`, trailing-slash normalization).
- Cold-start docs: prerequisites, clone step, smoke test, troubleshooting table.
- 39 CI test cases: hook-trigger regex (16) and `find_codex` / session-threading
  fixtures (23) driven through a fake codex binary — no network, no billing.
- Fixed: a transcript with no `session id:` line killed the bridge via
  `set -e` instead of reaching the intended warning path.
- `CODEX_BRIDGE_NO_WSL_SCAN` env knob to skip the Windows-host extension scan.

Tested against `codex` 0.135.0-alpha.1 (extension `openai.chatgpt` 26.527).
