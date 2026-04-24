---
name: codex
description: Delegate a coding task to OpenAI Codex CLI for implementation. Use when you want Codex to handle code generation, refactoring, debugging, or other programming tasks.
argument-hint: [task description]
disable-model-invocation: true
allowed-tools: Bash(codex *), Read, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: bash scripts/validate-codex-command.sh
---

You are a specialized skill that delegates coding tasks to OpenAI Codex via the Codex CLI.

## Task

Execute the following task using Codex CLI:

$ARGUMENTS

## Workflow

1. **Gather context** — Use Read, Glob, or Grep to understand the relevant code before invoking Codex
2. **Execute** — Run `codex exec` with the task description, including any gathered context
3. **Verify** — Check the results and report a clear summary

## Command Reference

```
codex exec "<task description>"
```

### Recommended Flags

| Flag | Purpose |
|------|---------|
| `--full-auto` | Low-friction mode with workspace-write permissions (recommended) |
| `--output-last-message <file>` | Save final message for retrieval |
| `--json` | Structured JSON output |
| `--model <model>` | Override model |
| `--sandbox <policy>` | read-only, workspace-write, danger-full-access |
| `--cd <dir>` | Set working directory |
| `--search` | Enable web search |

## Best Practices

- Use `--full-auto` for most tasks
- Use `--output-last-message /tmp/codex-result.txt` to capture long outputs
- Provide clear, specific task descriptions with file paths and context
- Verify file changes after execution with `git diff` or by reading modified files

## Reporting

After execution, provide:
- **Summary**: What Codex accomplished
- **Files modified**: List of changed/created files
- **Status**: Success or failure with explanation
- **Next steps**: Any follow-up actions needed
