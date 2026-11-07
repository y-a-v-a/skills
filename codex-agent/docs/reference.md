# Codex Skills Reference

## Examples

### `/codex` — Task Execution

```
/codex create a function to parse CSV files with error handling
/codex implement a REST API endpoint for user authentication
/codex refactor the authentication module to use modern async patterns
/codex convert this callback-based code to use promises
/codex analyze security vulnerabilities in the codebase
/codex generate unit tests for the UserService class
/codex fix the race condition in the connection pool
```

### `/codex-review` — Cross-Model Code Review

```
/codex-review --uncommitted                          # Review working tree changes
/codex-review --base main                            # Review branch vs base branch
/codex-review --commit abc123                        # Review a specific commit
/codex-review --base main --focus security           # Directed review
/codex-review --uncommitted --intent "<goal>"        # Review against stated intent
```

Findings are triaged (Accept / Reject / Defer / Discuss); contested findings get
one reconciliation round with Codex (HOLD / WITHDRAW). A report is written to
`codex-reviews/<slug>.md` when there are findings worth tracking.

### `/codex-discuss` — Agent Discussion

```
/codex-discuss <topic or question to work through>
```

Turn-based discussion in `codex-discussions/<slug>.md`. You propose, Codex
challenges; the loop runs autonomously to `CONVERGED` or `IMPASSE` (default cap
5 round-trips) and an `## Outcome` section records the agreed plan or the open
disagreements. Codex runs `--sandbox read-only` and never edits files — you are
the sole writer of the discussion file.

## Prerequisites

```bash
npm install -g @openai/codex
codex login
codex --version
```

## File Locations

| File | Purpose |
|------|---------|
| `skills/codex/SKILL.md` | Codex task execution skill |
| `skills/codex/scripts/validate-codex-command.sh` | Safety validation hook |
| `skills/codex-review/SKILL.md` | Cross-model code review skill |
| `skills/codex-discuss/SKILL.md` | Agent discussion skill |
| `skills/codex-discuss/scripts/validate-codex-command.sh` | Safety validation hook |

## Codex CLI Flags

| Flag | Purpose |
|------|---------|
| `--sandbox workspace-write` | Low-friction mode (recommended for most tasks) |
| `--json` | Structured JSON output |
| `--output-last-message <file>` | Save results to file |
| `--model <model>` | Override model selection |
| `--sandbox <policy>` | Set permissions (read-only, workspace-write, danger-full-access) |
| `--cd <dir>` | Set working directory |
| `--search` | Enable web search |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `CODEX_ALLOW_DANGER_MODE` | Allow `danger-full-access` sandbox mode |
| `CODEX_ALLOW_BYPASS` | Allow bypassing all approvals and sandboxing |
| `CI` | Detected for CI/CD mode behavior |

## Customization

Restrict tools in `skills/codex/SKILL.md`:
```yaml
allowed-tools: Bash(codex *), Read, Grep, Glob
```

Add project rules to the Markdown body of `skills/codex/SKILL.md`:
```markdown
## Project Rules
- Always use TypeScript
- Run `npm test` after changes
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `codex: command not found` | Install Codex CLI and add to PATH |
| Skill not appearing | Check symlink: `ls -la ~/.claude/skills/codex` |
| Authentication errors | Run `codex login` |
| Validation blocks everything | `chmod +x skills/codex/scripts/validate-codex-command.sh` |
| Hooks not working | Verify script path is relative to skill directory |

## Resources

- [Skills Documentation](https://code.claude.com/docs/en/skills)
- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference)
