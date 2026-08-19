## What & why

<!-- The change and the problem it solves. file:line references welcome. -->

## How verified

<!-- Commands run and their results. -->

## Checklist

- [ ] `tests/test_codex_trigger.sh` and `tests/test_codex_bridge.sh` pass
- [ ] shellcheck-clean (CI runs it; suppressions have an explaining comment)
- [ ] No networked or billed calls added to tests/CI
- [ ] Read-only sandbox guarantees untouched (or the change argues its case)
- [ ] README / CHANGELOG updated if behavior is user-visible
