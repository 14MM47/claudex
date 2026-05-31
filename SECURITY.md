# Security Policy

## ⚠️ Data egress — read this first

`codex-reconciler` is a developer convenience tool that **sends your source code to
OpenAI**. To reconcile a claim, it invokes the Codex CLI, which reads the relevant
files in the target repository and transmits that content to OpenAI's API under your
account, where it is processed per OpenAI's data-usage terms.

**Do not run this against repositories whose contents must not leave your
environment** (confidential client code, regulated data, air-gapped/"no data leaves
the building" projects). It is the wrong tool for that — by design it does the
opposite. Use it only where sending code to a third-party model is acceptable.

You control the blast radius:

- **Read-only by default.** Codex runs with `CODEX_BRIDGE_SANDBOX=read-only`; it can
  read the repo but cannot modify files.
- **Scope what it sees.** Point reconciliations at specific files/claims rather than
  whole trees; only the files Codex chooses to read are sent.
- **No background calls.** The only component that contacts OpenAI is
  `scripts/codex_bridge.sh`. The `UserPromptSubmit` hook (`hooks/codex-trigger.sh`)
  only injects advisory text locally — it makes no network calls and incurs no
  billing. Every Codex turn is explicitly initiated.

## Credentials

- Authentication is read from `~/.codex/auth.json` (your existing Codex/IDE login).
  This repo never reads, copies, logs, or transmits that file — it relies on the
  Codex CLI to use it.
- The bridge writes thread state next to its `--state` path: `*.sid` (session id),
  `*.reply` (Codex's last message), `*.log` (raw transcript). **These can contain
  source-code excerpts and prompt/response text.** They default to a temp dir; keep
  them out of version control (see `.gitignore`) and off shared locations.

## Supported versions

This tracks **undocumented surfaces** of the Codex CLI (the `exec` / `exec resume`
subcommands, `-c sandbox_mode=…`, and scraping `session id:` from stdout) and the
`openai.chatgpt` extension's bundled-binary layout. It is **tested against
`codex` 0.135.0-alpha.1**. A Codex upgrade can change these without notice; re-verify
after upgrading (the session-id capture in `codex_bridge.sh` is the first thing to
check). No security fixes are backported to older, untested Codex versions.

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Preferred: GitHub **private vulnerability reporting** — the repository's
  **Security** tab → **Report a vulnerability** (GitHub Security Advisories).
- Alternatively, contact the maintainer privately via their GitHub profile.

Please include reproduction steps and the affected file/line. You'll get an
acknowledgement as soon as practical; this is a personal/experimental project, so
response times are best-effort.

## Scope

In scope: issues in this repo's scripts, agent/command definitions, hook, and
installer — e.g. command injection, unsafe path handling, unintended network egress,
or credential exposure introduced by **this** code. Out of scope: vulnerabilities in
the Codex CLI itself, the `openai.chatgpt` extension, or OpenAI's API (report those
to OpenAI).
