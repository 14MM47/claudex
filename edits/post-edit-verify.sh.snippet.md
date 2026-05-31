# Edit to `~/.claude/hooks/post-edit-verify.sh`

This repo does **not** vendor the whole `post-edit-verify.sh` hook (it is a
pre-existing, user-owned hook). Only the addition introduced by the Codex
workflow is recorded here.

## What it does

The hook lints edited files by **file extension**, so an extensionless shell
script (e.g. a `#!/bin/bash` file named `deploy`) was never shellcheck'd. This
block adds **shebang-based detection** so those route through the shell linter too.

## Where it goes

Immediately **after** these two existing lines:

```bash
EXT="${FILE_PATH##*.}"
WARNINGS=""
```

## The addition

```bash

# Route extensionless / oddly-named scripts with a shell shebang through the
# shell linter too, so files like `deploy` or `pod_up` (no .sh) get shellcheck'd.
case "$EXT" in
  sh|bash) ;;
  *)
    if head -1 "$FILE_PATH" 2>/dev/null | grep -qE '^#!.*\b(bash|sh|dash|ksh|zsh)\b'; then
      EXT="sh"
    fi
    ;;
esac
```

## Note

The existing `sh|bash)` case in the hook's `--- LINT ---` block already runs
`shellcheck`; this addition simply funnels extensionless shell scripts into it by
rewriting `EXT` to `sh` when a shell shebang is present. No other part of the hook
was changed.
