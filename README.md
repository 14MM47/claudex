# codex-reconciler

[![CI](https://github.com/14MM47/codex-reconciler/actions/workflows/ci.yml/badge.svg)](https://github.com/14MM47/codex-reconciler/actions/workflows/ci.yml)
![Claude Code](https://img.shields.io/badge/Claude%20Code-agent-d97757?logo=anthropic&logoColor=white)
![OpenAI Codex](https://img.shields.io/badge/OpenAI%20Codex-GPT--5.x-412991?logo=openai&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnubash&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-experimental-orange)

A global Claude Code ↔ OpenAI Codex **adversarial-collaboration** workflow.

Asking Claude Code to *"check with Codex"* hands the disputed question, claim, diff,
or design to **Codex (GPT-5.x)** and runs a **verified, multi-round back-and-forth** —
Claude checks each of Codex's claims against the actual code (and its own), concedes
what the evidence supports, pushes back with `file:line` on what it doesn't, and loops
until the two models **align** on an evidence-backed conclusion or a genuine
disagreement is documented. Neither model is treated as an oracle; alignment is reached
on evidence, never on deference.

Codex ships as a binary **inside the VS Code `openai.chatgpt` extension** (not on
`PATH`); this workflow locates that binary and drives its non-interactive `exec` /
`exec resume` mode. It reuses whatever Codex login is in `~/.codex/auth.json`.

> **Each Codex turn is a real, BILLED OpenAI API call.** The default cap is 5 turns.

> ⚠️ **Privacy — this sends your source to OpenAI.** To reconcile a claim, Codex
> reads the relevant files in your repository and the model sees that content; it
> leaves your machine and is processed by OpenAI's API under your account's data
> terms. Do **not** point this at repositories whose contents may not leave the
> building. It is a developer convenience tool, not a confidential-data tool — use
> it only where sending code to a third-party model is acceptable.

## Components (the "seven files and edits")

Standalone files (vendored in full):

| Path | Role |
|---|---|
| `scripts/codex_bridge.sh` | Primitive: drives `codex exec` / `exec resume`, auto-finds the newest Codex binary, runs read-only, multi-turn sessions (context retained across turns). |
| `agents/codex-reconciler.md` | The subagent that runs the Claude↔Codex debate loop, verifying each reply against code, and returns a structured verdict. |
| `commands/check-with-codex.md` | The `/check-with-codex <issue>` slash command. |
| `hooks/codex-trigger.sh` | `UserPromptSubmit` hook that routes "check with codex" intent to the agent. Pure text injection — **no network, no billing.** |

Edits to pre-existing user-owned files (only the additions are recorded, under `edits/`):

| Path | What |
|---|---|
| `edits/settings.json.patch` | Wires `codex-trigger.sh` in as a `UserPromptSubmit` hook. |
| `edits/post-edit-verify.sh.snippet.md` | Adds shebang-based detection so extensionless shell scripts get shellcheck'd. |
| `edits/CLAUDE.md.snippet.md` | Documents the workflow as durable global instruction. |

## Install

```bash
./install.sh            # copies the 4 files into ~/.claude/ and wires the hook
./install.sh --no-wire  # copy only; don't touch settings.json
```

`install.sh` copies the four standalone files into `~/.claude/` and (unless
`--no-wire`) idempotently adds the `UserPromptSubmit` hook to `~/.claude/settings.json`
via `jq`, backing the file up first. The other two edits are **personal/optional** and
are left to you:

```bash
# post-edit-verify.sh — optional shellcheck enhancement for a personal lint hook
# CLAUDE.md          — optional durable instruction documenting the workflow
# Both are reference snippets under edits/.
```

The `codex-reconciler` subagent becomes selectable on the **next** Claude Code session
(subagent types load at startup); the bridge and `/check-with-codex` command work
immediately.

## Usage

```
You:  check with codex whether <claim about the code>
```

Claude launches the reconciler, which debates Codex and reports: the converged
conclusion, verified findings (`file:line`), any remaining disagreement, and the number
of billed Codex turns.

Drive the bridge directly if you want:

```bash
BR=scripts/codex_bridge.sh
T=/tmp/codex_thread
"$BR" start --state "$T" --cd /path/to/repo "Your question. Cite file:line."
"$BR" reply --state "$T" "Follow-up — same session, full context retained."
```

## Design guarantees

- **Read-only by default** — Codex can read the repo but not modify files
  (`CODEX_BRIDGE_SANDBOX=read-only`; `exec resume` enforces it via `-c sandbox_mode`).
- **No hidden billing** — the only component that calls Codex is the bridge; the hook
  only injects advisory text. Every billed call is explicitly initiated.
- **Evidence over agreement** — the agent must verify concrete claims against source
  before accepting them, and update its own position when the code says so.

## Requirements

- A working **Codex CLI** — either the VS Code / Cursor `openai.chatgpt` extension
  installed and logged in, or a standalone `codex` on `PATH`. Auth is read from
  `~/.codex/auth.json`. The bridge auto-detects the bundled binary on Linux
  (`linux-x86_64`) and macOS (`darwin-arm64` / `darwin-x64`); set `CODEX_BIN` to
  point at a specific binary if detection misses.
- `jq` (used by the hook to parse the prompt event; it degrades gracefully without it).
- `shellcheck` (optional; only for the `post-edit-verify.sh` lint enhancement).

## Compatibility & stability

This drives **undocumented surfaces** of the Codex CLI and may break on upgrades:

- It depends on `codex exec` / `codex exec resume`, the `-c sandbox_mode=…` override,
  and on scraping `session id: <uuid>` from `exec` stdout to thread a conversation.
- It assumes the `openai.chatgpt` extension bundles the binary at
  `bin/<os>-<arch>/codex`.

**Tested against `codex` 0.135.0-alpha.1** (extension `openai.chatgpt` 26.527).
If a Codex upgrade changes the `exec` output format or flags, the bridge's
session-id capture is the first thing to check. Pin or re-verify after upgrades.
