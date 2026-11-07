# Testing Codex Skills

Prerequisites: install and authenticate Codex CLI — see [reference.md](./reference.md#prerequisites).

## `/codex`

```
/codex create a hello world function in Python
/codex refactor test.py to use type hints
```

Check results:
```bash
git status
git diff
```

## `/codex-review`

```
/codex-review --uncommitted
/codex-review --base main --focus security
/codex-review --commit abc123 --intent "handle empty input"
```

Expect: findings triaged by severity, contested findings reconciled with Codex,
and a `codex-reviews/<slug>.md` report when findings warrant tracking.

## `/codex-discuss`

```
/codex-discuss should config live in env vars or a config file?
```

Check the discussion file:
```bash
cat codex-discussions/*.md
```

Expect: alternating `Turn N — Claude` / `Turn N — Codex` sections, each ending in
a `Signal:` line, and a final `## Outcome` with status `CONVERGED` or `IMPASSE`.

## Validation Hook

```bash
# Should allow (exit 0)
echo '{"tool_input":{"command":"codex exec test"}}' | bash skills/codex/scripts/validate-codex-command.sh

# Should block (exit 2)
echo '{"tool_input":{"command":"codex exec --dangerously-bypass-approvals-and-sandbox test"}}' | bash skills/codex/scripts/validate-codex-command.sh
```

Set `CODEX_ALLOW_DANGER_MODE=1` or `CODEX_ALLOW_BYPASS=1` to permit dangerous operations.

## Troubleshooting

See [reference.md](./reference.md#troubleshooting).
