# Testing the Codex Skills

This guide explains how to test and verify the Codex skills.

## Prerequisites

1. **Install Codex CLI**
   ```bash
   # Follow instructions at https://developers.openai.com/codex/cli
   npm install -g @openai/codex  # or similar
   ```

2. **Authenticate Codex**
   ```bash
   codex login
   ```

3. **Verify Installation**
   ```bash
   codex --version
   codex login status
   ```

## Testing the `/codex` Skill

### 1. Check Skill is Available

Start Claude Code and type `/codex` — it should appear in autocomplete.

### 2. Test Simple Task

```
/codex create a hello world function in Python
```

Expected behavior:
- Skill gathers context if needed
- Runs `codex exec` command
- Reports back with results
- Function is created (if successful)

### 3. Test with Context

Create a test file first:
```bash
echo "def old_function():\n    pass" > test.py
```

Then run:
```
/codex refactor test.py to use type hints
```

Expected behavior:
- Skill reads the existing file
- Passes context to Codex
- Codex modifies the file
- Skill reports changes

### 4. Test Error Handling

Try a task that might fail:
```
/codex implement a nonexistent_framework integration
```

Expected behavior:
- Skill attempts the task
- Codex may fail or ask for clarification
- Skill reports the error clearly
- Skill may suggest next steps

## Testing the `/codex-review` Skill

### 1. Review Uncommitted Changes

Make some changes to a file, then:
```
/codex-review --uncommitted
```

### 2. Review Against a Branch

```
/codex-review --base main
```

### 3. Review a Specific Commit

```
/codex-review --commit abc123
```

## Validation Hook Testing

The validation hook is configured in `skills/codex/SKILL.md` frontmatter.

### 1. Test Normal Command (Should Pass)
```
/codex create a simple function
```

Should work normally.

### 2. Test Dangerous Flag (Should Block)

If Codex tries to use `--dangerously-bypass-approvals-and-sandbox`, it should be blocked by the validation hook unless `CODEX_ALLOW_BYPASS=1` is set.

### 3. Test with Environment Variable
```bash
export CODEX_ALLOW_DANGER_MODE=1
```

Then retry a command with `danger-full-access`. Should now pass.

## Verifying Skill Behavior

### Check Execution Flow

When the skill runs, you should see:
1. Context gathering (if needed)
2. Codex CLI command construction
3. Execution output
4. Result summary

### Check File Changes

After code generation/modification:
```bash
git status  # See what changed
git diff    # Review changes
```

### Check Codex Output

If using `--output-last-message`:
```bash
cat /tmp/codex-result.txt
```

## Common Issues

### Issue: "codex: command not found"

**Solution:**
- Ensure Codex CLI is installed
- Add to PATH if necessary
- Verify with `which codex`

### Issue: Authentication errors

**Solution:**
```bash
codex login
codex login status
```

### Issue: Skill not appearing

**Possible causes:**
- Symlink is broken or missing
- Skill directory doesn't contain `SKILL.md`
- YAML frontmatter has syntax errors

**Solution:**
- Check symlink: `ls -la ~/.claude/skills/codex`
- Verify file exists: `ls skills/codex/SKILL.md`
- Check YAML syntax
- Restart Claude Code

### Issue: Validation hook blocks all commands

**Solution:**
- Check `skills/codex/scripts/validate-codex-command.sh` permissions
- Ensure script is executable: `chmod +x skills/codex/scripts/validate-codex-command.sh`
- Check for jq dependency: `which jq`

## Advanced Testing

### Test JSON Output Mode

```
/codex analyze code quality in this directory and provide structured output
```

The skill should use `--json` flag for structured results.

### Manual Testing

Test Codex CLI directly:
```bash
codex exec "create a hello world function"
codex exec --full-auto --output-last-message /tmp/test.txt "analyze this file"
```

Compare results with skill's behavior.

### Test Validation Script Directly

```bash
echo '{"tool_input":{"command":"codex exec test"}}' | bash skills/codex/scripts/validate-codex-command.sh
echo $?  # 0 = allow

echo '{"tool_input":{"command":"codex exec --dangerously-bypass-approvals-and-sandbox test"}}' | bash skills/codex/scripts/validate-codex-command.sh
echo $?  # 2 = block
```

## Debugging

### Check Codex Logs

Codex CLI may have its own logging:
```bash
codex --help
# Look for log files in ~/.codex/ or similar
```

## Success Criteria

The skills are working correctly if:

- `/codex` invokes Codex CLI and completes tasks
- `/codex-review` runs code reviews successfully
- Results are captured and summarized properly
- File changes are made correctly
- Errors are handled gracefully
- Validation hooks block dangerous commands
- Skill reports useful information back to Claude Code

## Reporting Issues

If you find issues:
1. Document the exact `/codex` or `/codex-review` command used
2. Capture the skill's output
3. Check Codex CLI logs
4. Note any error messages
5. Test Codex CLI directly to isolate the issue
