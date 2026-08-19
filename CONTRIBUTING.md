# Contributing to claudex

Thanks for your interest. claudex is a small, experimental tool that drives
**undocumented surfaces** of the Codex CLI — contributions are welcome, but
expect the ground to shift under Codex upgrades (see
[Compatibility & stability](README.md#compatibility--stability)).

## Ground rules

- **Never add a billed or networked call to CI or the tests.** Every Codex
  turn is a real OpenAI API call. The test suites run entirely against a fake
  codex binary and regex fixtures — keep it that way.
- **Read-only stays read-only.** The bridge's `read-only` sandbox default and
  its re-enforcement on `exec resume` are load-bearing guarantees
  (see [SECURITY.md](SECURITY.md)). Changes that weaken them will be rejected.
- Bash only, `set -euo pipefail`, shellcheck-clean. Deliberate rule
  suppressions carry a `# shellcheck disable=` comment explaining why.

## Dev setup

```bash
git clone https://github.com/14MM47/claudex.git
cd claudex
shellcheck scripts/*.sh hooks/*.sh install.sh tests/*.sh
tests/test_codex_trigger.sh   # hook regex regression (16 cases)
tests/test_codex_bridge.sh    # find_codex + session threading fixtures (23 cases)
```

Both suites are no-network and take seconds. CI runs them on Linux and macOS,
plus shellcheck and a scratch install — a PR must be green on all jobs.

## Sending changes

1. Fork, branch, make the change.
2. Add or extend a test when you change behavior — especially anything in
   `find_codex()` or the session-id capture, the surfaces most likely to break.
3. Update README/CHANGELOG when user-visible behavior changes.
4. Open a PR using the template. Small, focused PRs with `file:line` reasoning
   review fastest — it's how this repo talks to itself, too.

## Reporting issues

Use the issue templates. For bridge failures, the tail of the `${BASE}.log`
transcript and the output of `scripts/codex_bridge.sh which` are the two most
useful artifacts — **strip anything sensitive first**; transcripts can contain
your prompt and repo content.
