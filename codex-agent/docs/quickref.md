# Codex Skills Quick Reference

Complete reference for configuring and using the Codex skills.

> **Usage Examples**: For workflow examples and common patterns, see [examples.md](./examples.md)

## File Locations

| File | Purpose |
|------|---------|
| `skills/codex/SKILL.md` | Codex task execution skill |
| `skills/codex/scripts/validate-codex-command.sh` | Safety validation hook |
| `skills/codex-review/SKILL.md` | Code review skill |
| `README.md` | Overview and quick start |
| `docs/examples.md` | Usage patterns and examples |
| `docs/testing.md` | Testing and verification guide |
| `docs/contributing.md` | Customization guide |

## Usage

### `/codex` — Task Execution
```
/codex create a REST API endpoint for users
/codex refactor this module to use async/await
/codex analyze security vulnerabilities
```

### `/codex-review` — Code Review
```
/codex-review --uncommitted
/codex-review --base main
/codex-review --commit abc123
```

## Codex CLI Flags

| Flag | Purpose |
|------|---------|
| `--full-auto` | Low-friction mode (recommended for most tasks) |
| `--json` | Structured JSON output |
| `--output-last-message <file>` | Save results to file |
| `--model <model>` | Override model selection |
| `--sandbox <policy>` | Set permissions (read-only, workspace-write, danger-full-access) |
| `--cd <dir>` | Set working directory |
| `--search` | Enable web search |

## Skill Frontmatter Fields

```yaml
---
name: skill-name                        # Required: unique identifier
description: When to use this           # Required: shown in autocomplete
argument-hint: [what to pass]           # Optional: autocomplete hint
disable-model-invocation: true          # Optional: prevent auto-invocation
context: fork                           # Optional: isolated context
agent: Explore                          # Optional: agent type
allowed-tools: Bash(codex *), Read      # Optional: restrict available tools
---
```

## Key Skill Fields

| Field | Purpose |
|-------|---------|
| `name` | Unique skill identifier, used as `/slash-command` |
| `description` | Helps users understand when to use the skill |
| `argument-hint` | Shown in autocomplete after `/name` |
| `disable-model-invocation` | Prevents Claude from auto-triggering (user must use `/command`) |
| `context: fork` | Runs in isolated context without conversation history |
| `agent` | Agent type: default, Explore (read-only) |
| `allowed-tools` | Restricts which tools the skill can use |

## Hook Events

| Event | When Triggered |
|-------|---------------|
| `PreToolUse` | Before tool execution |
| `PostToolUse` | After tool execution |

### Hook Exit Codes
- **0** — Allow operation
- **2** — Block operation (return stderr to Claude)

## Validation Script Usage

```bash
# Test validation script
echo '{"tool_input":{"command":"codex exec test"}}' | bash skills/codex/scripts/validate-codex-command.sh
echo $?  # 0 = allow, 2 = block

# Allow dangerous operations (in safe environments only)
export CODEX_ALLOW_DANGER_MODE=1
export CODEX_ALLOW_BYPASS=1
```

## Common Tasks

### Restrict Tool Access

Edit `skills/codex/SKILL.md`:
```yaml
---
allowed-tools: Bash(codex *), Read, Grep, Glob  # Read-only (no Write/Edit)
---
```

### Add Project-Specific Rules

Edit the system prompt in `skills/codex/SKILL.md`:

```markdown
## Project Rules

For this project:
- Always use TypeScript
- Follow existing code style
- Run `npm test` after changes
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "codex: command not found" | Install Codex CLI and add to PATH |
| Skill not appearing | Check symlink: `ls -la ~/.claude/skills/codex` |
| Authentication errors | Run `codex login` |
| Validation blocks everything | Check script permissions: `chmod +x skills/codex/scripts/validate-codex-command.sh` |
| Hooks not working | Verify script path is relative to skill directory |

## Prerequisites

```bash
# Install and authenticate Codex CLI
npm install -g @openai/codex
codex login
codex login status

# Verify setup
codex --version
which codex
```

## Testing

```bash
# Quick test
claude  # Start Claude Code
# Then: /codex create a hello world function

# Test validation hook
bash skills/codex/scripts/validate-codex-command.sh <<< '{"tool_input":{"command":"codex exec test"}}'

# Check skill syntax
python3 -c "import yaml; yaml.safe_load(open('skills/codex/SKILL.md').read().split('---')[1])"
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `CODEX_ALLOW_DANGER_MODE` | Allow `danger-full-access` sandbox mode |
| `CODEX_ALLOW_BYPASS` | Allow bypassing all approvals and sandboxing |
| `CI` | Detected for CI/CD mode behavior |

## Best Practices

- Use `--full-auto` for most development tasks
- Save output with `--output-last-message`
- Provide clear, specific task descriptions
- Include context about existing code
- Verify changes after delegation
- Use appropriate sandbox settings
- Enable validation hooks for safety
- Document project-specific rules in skill prompt

## Resources

- **Skills Documentation**: https://code.claude.com/docs/en/skills
- **Codex CLI Reference**: https://developers.openai.com/codex/cli/reference
- **Project README**: [../README.md](../README.md)
- **Usage Examples**: [examples.md](./examples.md)
- **Testing Guide**: [testing.md](./testing.md)
- **Customization Guide**: [contributing.md](./contributing.md)
