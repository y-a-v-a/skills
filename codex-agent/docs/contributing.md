# Contributing to Codex Skills

This guide explains how to extend and customize the Codex skills for your needs.

## Skills Architecture

Each skill consists of:
- **Skill definition** — `skills/<name>/SKILL.md` (YAML frontmatter + Markdown prompt)
  - Includes `allowed-tools`, `context`, `agent`, `disable-model-invocation`, and hooks
- **Supporting files** — Scripts, templates, etc. in the skill directory
- **Settings** — `~/.claude/settings.json` (optional global configuration)

### Available Skills

| Skill | Path | Purpose |
|-------|------|---------|
| `/codex` | `skills/codex/SKILL.md` | Delegate coding tasks to Codex CLI |
| `/codex-review` | `skills/codex-review/SKILL.md` | Run code reviews via Codex CLI |

## Customizing Skills

### Modifying the Codex Skill

Edit `skills/codex/SKILL.md`:

#### Change Allowed Tools

```yaml
---
allowed-tools: Bash(codex *), Read, Glob, Grep, WebFetch  # Add WebFetch for research
---
```

#### Change Context Mode

```yaml
---
context: fork  # Run in isolated context (no conversation history)
---
```

#### Change Agent Type

```yaml
---
agent: Explore  # Read-only agent
---
```

### Modifying the System Prompt

The Markdown content after the YAML frontmatter is the system prompt. Customize it to:

- Add domain-specific knowledge
- Change workflow steps
- Add specialized Codex CLI flags for your use case
- Include project-specific context

Example addition:

```markdown
## Project-Specific Rules

For this project:
- Always use TypeScript strict mode
- Follow the existing naming conventions in `src/`
- Run tests after code generation with `npm test`
- Format code with `npm run format` before committing
```

### Adding Validation Rules

Edit `skills/codex/scripts/validate-codex-command.sh` to add custom validation:

```bash
# Block specific Codex models
if echo "$COMMAND" | grep -q -- "--model gpt-3.5"; then
  echo "Blocked: This project requires gpt-4 or better" >&2
  exit 2
fi

# Require certain flags
if echo "$COMMAND" | grep -q "codex exec" && ! echo "$COMMAND" | grep -q -- "--full-auto"; then
  echo "Warning: Consider using --full-auto for this project" >&2
fi

# Project-specific path restrictions
if echo "$COMMAND" | grep -q -- "--cd /production"; then
  echo "Blocked: Cannot run Codex against production paths" >&2
  exit 2
fi
```

## Creating Additional Skills

You can create new skills in `skills/<name>/SKILL.md`:

### Example: Codex Analyzer Skill

Create `skills/codex-analyzer/SKILL.md`:

```yaml
---
name: codex-analyzer
description: Use Codex to analyze code quality, security, and performance without making changes
argument-hint: [analysis target]
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools: Bash(codex *)
---

You are a read-only code analyzer using Codex CLI.

Your role is to analyze code without making modifications.

Always use:
- `--sandbox read-only` flag
- `--json` flag for structured output
- `--output-last-message` to capture results

Analyze: $ARGUMENTS
```

Then symlink: `ln -s ~/Projects/codex-agent/skills/codex-analyzer ~/.claude/skills/codex-analyzer`

## Configuring Hooks

Hooks are configured in the skill's YAML frontmatter:

### Tool Usage Hooks

```yaml
---
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: bash scripts/validate-codex-command.sh
---
```

### Alternative: Global Hooks Configuration

If you need hooks to apply across multiple skills, configure them in `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash skills/codex/scripts/validate-codex-command.sh"
          }
        ]
      }
    ]
  }
}
```

## Best Practices

### For Skill Design

- **Keep focused** — One skill, one purpose
- **Clear descriptions** — Help users understand when to use each skill
- **Appropriate permissions** — Use `allowed-tools` to grant only necessary tools
- **Use `disable-model-invocation: true`** — For skills that cost money or have side effects
- **Use `context: fork`** — For self-contained tasks that don't need conversation history

### For System Prompts

- **Be specific** — Detailed instructions produce better results
- **Include examples** — Show concrete command patterns
- **Use `$ARGUMENTS`** — Pass user input directly into the prompt
- **Provide workflows** — Step-by-step processes
- **Handle errors** — Explicit error handling instructions

### For Validation Scripts

- **Fail safe** — Default to blocking on uncertainty
- **Clear messages** — Explain why something was blocked
- **Exit codes** — Use 0 (allow) and 2 (block) correctly
- **Minimal dependencies** — Avoid requiring exotic tools
- **Fast execution** — Keep validation quick

## Testing Changes

After modifying a skill:

1. **Syntax check** — Ensure YAML is valid
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('skills/codex/SKILL.md').read().split('---')[1])"
   ```

2. **Reload** — Restart Claude Code to pick up changes

3. **Test invocation** — Try the slash command
   ```
   /codex create a hello world function
   ```

4. **Test hooks** — If modified, verify validation works
   ```bash
   echo '{"tool_input":{"command":"codex exec test"}}' | bash skills/codex/scripts/validate-codex-command.sh
   echo $?  # Should be 0 or 2
   ```

## Sharing Your Customizations

If you create useful modifications:

1. Document them clearly
2. Add examples to `docs/examples.md`
3. Update `docs/testing.md` with new test cases
4. Consider contributing back to the community

## Troubleshooting

### Skill not loading

- Check YAML syntax in frontmatter
- Ensure skill is symlinked from `~/.claude/skills/`
- Verify directory contains `SKILL.md`
- Restart Claude Code

### Hooks not triggering

- Verify script has execute permissions
- Check script path is correct (relative to skill directory)
- Ensure script returns proper exit codes (0 or 2)
- Check for syntax errors in hook script

### Permission issues

- Check `allowed-tools` in frontmatter
- Check Claude Code settings.json for `Skill(codex *)` permission
- Verify sandbox mode is appropriate for task

## Resources

- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference)
- [YAML Specification](https://yaml.org/spec/)
- [Bash Exit Codes](https://tldp.org/LDP/abs/html/exitcodes.html)
