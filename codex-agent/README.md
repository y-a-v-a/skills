# Claude Code Codex Skills

Claude Code skills that delegate coding tasks and code reviews to OpenAI Codex CLI.

## Quick Start

Install prerequisites: [Claude Code](https://code.claude.com) and [Codex CLI](https://developers.openai.com/codex/cli)

```sh
# clone repository
git clone git@github.com:y-a-v-a/codex-executor.git

# symlink skills into Claude Code (adjust path to where you cloned the repo)
ln -s /path/to/codex-executor/skills/codex ~/.claude/skills/codex
ln -s /path/to/codex-executor/skills/codex-review ~/.claude/skills/codex-review
```

Set permissions in `~/.claude/settings.json` or in `.claude/settings.local.json` at the project level:

```json
{
  "permissions": {
    "allow": [
      "Skill(codex *)",
      "Skill(codex-review *)"
    ]
  }
}
```

## Usage

### `/codex` — Task execution

Delegate a coding task to Codex:

```
/codex create a REST API endpoint for user authentication
/codex refactor this module to use async/await
/codex analyze security vulnerabilities in the codebase
```

### `/codex-review` — Code review

Run a code review using Codex:

```
/codex-review --uncommitted
/codex-review --base main
/codex-review --commit abc123
```

## Key Files

| Path | Purpose |
|------|---------|
| `skills/codex/SKILL.md` | Codex task execution skill |
| `skills/codex/scripts/validate-codex-command.sh` | Command validation hook |
| `skills/codex-review/SKILL.md` | Codex code review skill |

## Documentation

- **[docs/quickref.md](./docs/quickref.md)** — Complete reference: CLI flags, configuration, hooks, troubleshooting
- **[docs/examples.md](./docs/examples.md)** — Usage patterns and workflow examples
- **[docs/contributing.md](./docs/contributing.md)** — Customization and extension guide
- **[docs/testing.md](./docs/testing.md)** — Testing and verification guide
- [Claude Code skills docs](https://code.claude.com/docs/en/skills)
- [Codex CLI reference](https://developers.openai.com/codex/cli/reference)
