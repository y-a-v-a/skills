#!/bin/bash
# Validation hook for Codex CLI commands
# This script validates Codex commands before execution to ensure safety
#
# Exit codes:
#   0 - Allow operation
#   2 - Block operation (stderr message returned to Claude)
#   Other - Undefined behavior

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required for command validation but not found in PATH" >&2
  echo "Install jq: https://stedolan.github.io/jq/download/" >&2
  exit 2
fi

# Read input JSON from stdin
INPUT=$(cat)

# Extract the bash command from the JSON
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Check if this is a Codex command by looking for "codex" as a word boundary
# This catches: codex, /path/to/codex, ./codex, ENV=val codex, etc.
if ! echo "$COMMAND" | grep -qE '\bcodex\b'; then
  # Not a Codex command, allow it
  exit 0
fi

# Validation rules for Codex commands

# 1. Block danger-full-access unless explicitly in a safe environment
if echo "$COMMAND" | grep -q -- "--sandbox.*danger-full-access"; then
  if [ -z "$CODEX_ALLOW_DANGER_MODE" ]; then
    echo "Blocked: danger-full-access requires CODEX_ALLOW_DANGER_MODE environment variable" >&2
    echo "This safety check prevents unrestricted filesystem access." >&2
    echo "If you're in a safe environment, set: export CODEX_ALLOW_DANGER_MODE=1" >&2
    exit 2
  fi
fi

# 2. Warn about missing output capture for long tasks
if echo "$COMMAND" | grep -q "codex exec" && ! echo "$COMMAND" | grep -q -- "--output-last-message"; then
  # This is a warning, not a block - but we'll note it in stderr and still allow
  echo "Warning: Consider using --output-last-message to capture results" >&2
fi

# 3. Block commands that try to bypass approvals without proper safeguards
if echo "$COMMAND" | grep -q -- "--dangerously-bypass-approvals-and-sandbox"; then
  if [ -z "$CODEX_ALLOW_BYPASS" ]; then
    echo "Blocked: --dangerously-bypass-approvals-and-sandbox requires CODEX_ALLOW_BYPASS=1" >&2
    echo "This flag disables all safety checks. Only use in isolated CI/CD environments." >&2
    exit 2
  fi
fi

# 4. Ensure Codex is installed
if ! command -v codex &> /dev/null; then
  echo "Blocked: 'codex' command not found in PATH" >&2
  echo "Please install the Codex CLI: https://developers.openai.com/codex/cli" >&2
  exit 2
fi

# 5. Check authentication status for non-help commands
if echo "$COMMAND" | grep -qv "codex login\|codex --help\|codex -h"; then
  if ! codex login status &> /dev/null; then
    echo "Warning: Codex CLI may not be authenticated. Run 'codex login' if needed." >&2
    # Don't block, just warn
  fi
fi

# All checks passed
exit 0
