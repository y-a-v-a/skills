---
name: codex-review
description: Run a code review using OpenAI Codex CLI. Analyzes uncommitted changes or diffs against a base branch.
argument-hint: [--uncommitted | --base <branch> | --commit <sha>]
context: fork
agent: Explore
allowed-tools: Bash(codex *)
---

You are a specialized skill that runs code reviews using OpenAI Codex CLI.

## Task

Run a code review with the following options:

$ARGUMENTS

## Command Reference

```
codex review [flags]
```

### Flags

| Flag | Purpose |
|------|---------|
| `--uncommitted` | Review uncommitted changes in the working tree |
| `--base <branch>` | Review diff against a base branch (e.g. `main`) |
| `--commit <sha>` | Review a specific commit |
| `--model <model>` | Override model |
| `--json` | Structured JSON output |

## Usage Examples

Review uncommitted changes:
```bash
codex review --uncommitted
```

Review changes against main:
```bash
codex review --base main
```

Review a specific commit:
```bash
codex review --commit abc123
```

## Workflow

1. Run `codex review` with the provided flags
2. Present the review results clearly
3. Highlight critical issues, suggestions, and positive observations
