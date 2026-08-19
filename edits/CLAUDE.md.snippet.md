# Edits to `~/.claude/CLAUDE.md` (global instructions)

Two additions document the workflow as durable instruction so the natural-language
trigger ("check with Codex") is honored even when the advisory hook doesn't fire.

## 1. New line in the `### Slash Commands` list

Add after the `/verify` entry:

```markdown
- `/check-with-codex <issue>` — Reconcile a question/claim/diff with OpenAI Codex (GPT-5.x)
```

## 2. New section (insert before `## Token Efficiency`)

```markdown
## Second-Opinion Reconciliation with Codex

The Codex-reconciler system is named **Claudex**. When the user asks to **"check with
Codex"** (or "with claudex"), "verify/reconcile with Codex", "ask Codex", "run claudex",
or get Codex's opinion, do **not** make a one-off Codex call. Launch the
**`claudex`** subagent (Agent tool, `subagent_type: claudex`), passing the
issue, your own current position with `file:line` evidence, and the repo root. It runs a
verified, multi-round Claude↔Codex debate via `~/.claude/scripts/codex_bridge.sh`,
**checking each side's claims against the actual code**, until they align or a genuine
disagreement is documented. A `UserPromptSubmit` hook (`codex-trigger.sh`) injects an
advisory reminder when it detects this intent. Each Codex turn is a **billed OpenAI call** —
the default cap is 5 turns; surface the count. The bridge drives Codex read-only (it cannot
edit files). Never accept Codex's claims unverified — the value is in the cross-check, not the
second voice.
```
