---
name: codex
description: Delegate a coding task to OpenAI Codex CLI for implementation. Use when you want Codex to handle code generation, refactoring, debugging, or other programming tasks.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: "[task description]"
disable-model-invocation: true
allowed-tools: Bash(codex *), Bash(mktemp *), Read, Write, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        # Hooks run in the session's cwd, not the skill dir, so a relative path
        # never resolves. CLAUDE_PLUGIN_ROOT holds the skill dir in skill hooks;
        # the second path is the standard install location. If neither has the
        # script, block codex commands only (fail closed without locking up Bash).
        - type: command
          command: 'for d in "$CLAUDE_PLUGIN_ROOT" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/codex"; do [ -f "$d/scripts/validate-codex-command.sh" ] && exec bash "$d/scripts/validate-codex-command.sh"; done; grep -q codex && { echo "Blocked: codex validation hook script not found; reinstall the codex skill." >&2; exit 2; }; exit 0'
          onFailure: block
---

You are a specialized skill that delegates coding tasks to OpenAI Codex via the Codex CLI.

## Task

Execute the following task using Codex CLI:

$ARGUMENTS

## Workflow

1. **Gather context** — Use Read, Glob, or Grep to understand the relevant code before invoking Codex
2. **Build a brief** — `codex exec` is stateless: it knows *only* what is in the prompt string. Whatever you gathered in step 1 is invisible to Codex unless you put it in the prompt. Write the context you gathered into a brief file (template below) — do not just describe the task in one line and throw the context away
3. **Execute** — Run `codex exec` with the brief as its single prompt and capture the result
4. **Verify** — Check the actual outcome against ground truth (`git diff`, read the changed files) — not just Codex's self-reported summary — and report

## The brief

The quality of Codex's output is bounded by the quality of this prompt. Write
the gathered context into a file and pass that file as the one prompt Codex
sees:

```markdown
## Intent
<one sentence: what "done" looks like>

## Relevant files
<paths you located in step 1, each with a one-line why-it-matters>

## Constraints / conventions
<repo conventions, non-negotiables, things NOT to touch>

## Context
<the actual code excerpts you gathered>

## Task
<the specific ask — substitute $ARGUMENTS here>
```

## Command Reference

Hand Codex the brief file as its **whole** prompt, on stdin (`-`). Never rely
on a bare one-line task string (it strands the context you gathered) or a
second positional argument (`codex exec` consumes one prompt). Don't inline the
brief with `"$(cat …)"` either: Linux caps a single argument at 128 KB, and a
brief with real code excerpts gets there.

```bash
# Fresh per run: fixed /tmp names collide between concurrent sessions.
D="$(mktemp -d)"
# Write the brief to "$D/brief.md" (Write tool), then:
codex exec --sandbox workspace-write --output-last-message "$D/result.txt" - < "$D/brief.md"
```

### Recommended Flags

| Flag | Purpose |
|------|---------|
| `--sandbox workspace-write` | Low-friction mode: workspace-write permissions (recommended default) |
| `--output-last-message <file>` | Save final message for retrieval |
| `--json` | Structured JSON output |
| `--model <model>` | Override model |
| `--sandbox <policy>` | read-only, workspace-write, danger-full-access |
| `--cd <dir>` | Set working directory |
| `--search` | Enable web search. **Global flag:** goes before `exec` (`codex --search exec …`); `codex exec --search` is rejected |

## Best Practices

- Use `--sandbox workspace-write` for most tasks
- Always pass `--output-last-message "$D/result.txt"` so the result is captured and verifiable
- Put gathered context *in the brief* — file paths and excerpts in the prompt beat a vague task description every time
- Don't trust Codex's summary on its face — verify file changes with `git diff` or by reading the modified files before reporting

## Reporting

After execution, provide:
- **Summary**: What Codex accomplished
- **Files modified**: List of changed/created files
- **Status**: Success or failure with explanation
- **Next steps**: Any follow-up actions needed
