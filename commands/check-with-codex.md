Hand a technical question, claim, design, or diff to **OpenAI Codex (GPT-5.x)** and
run a verified multi-round back-and-forth until Claude and Codex align (or a genuine
disagreement is documented).

This launches the **claudex** subagent (Claudex, the Codex reconciler), which drives the debate through
`~/.claude/scripts/codex_bridge.sh`. Each Codex turn is a **billed OpenAI call**.

Steps:

1. Determine the issue to reconcile:
   - If `$ARGUMENTS` is non-empty, that is the issue.
   - If empty, use the matter currently under discussion in this conversation
     (the most recent claim, diff, bug, or design decision). State which you picked.

2. Launch the `claudex` subagent (Agent tool, subagent_type
   `claudex`) with a prompt containing:
   - the precise question/claim to reconcile,
   - your *own* current position and the evidence for it (file:line) if you have one,
   - the relevant file paths, and the repo root,
   - the round cap if the user specified one (default: 5 Codex turns).

3. Relay the subagent's verdict to the user: the converged conclusion, the verified
   findings (with file:line), any remaining disagreement, and how many billed Codex
   turns it took. Do not silently accept Codex's claims — the subagent has already
   verified them against the code; present that verification.

The issue to reconcile: $ARGUMENTS
