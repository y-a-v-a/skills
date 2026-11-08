#!/bin/bash
# Validation hook for Codex CLI commands (PreToolUse, matcher: Bash).
#
# Skill hooks stay registered for the rest of the session once the skill is
# invoked, so this runs before EVERY Bash call. Non-codex commands must pass
# through fast and must never be blocked by this script's own dependencies.
#
# Exit codes:
#   0 - allow
#   2 - block (stderr is returned to Claude as the reason)
# Claude never sees stderr from a hook that exits 0, so this script prints
# nothing on the allow path: a "warning" there would go nowhere.

INPUT=$(cat)

# 1. Cheap pre-filter on the raw JSON: no "codex" anywhere means not ours.
#    Done before the jq check so a missing jq can't block unrelated commands.
if ! grep -qE '\bcodex\b' <<<"$INPUT"; then
  exit 0
fi

# 2. From here on this may be a codex command, so fail closed.
if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq is required to validate codex commands but is not on PATH." >&2
  echo "Install jq (brew install jq) and retry." >&2
  exit 2
fi

COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

# Only the command itself counts, not other fields of the tool input.
if ! grep -qE '\bcodex\b' <<<"$COMMAND"; then
  exit 0
fi

# 3. Unrestricted filesystem access, in every spelling the CLI accepts:
#    --sandbox danger-full-access, --sandbox=..., -s danger-full-access,
#    -c sandbox_mode="danger-full-access".
if grep -qE -- "(--sandbox|-s)(=|[[:space:]]+)[\"']?danger-full-access|sandbox_mode[[:space:]]*=[[:space:]]*[\"']*danger-full-access" <<<"$COMMAND"; then
  if [ -z "$CODEX_ALLOW_DANGER_MODE" ]; then
    echo "Blocked: danger-full-access requires the CODEX_ALLOW_DANGER_MODE environment variable." >&2
    echo "This safety check prevents unrestricted filesystem access." >&2
    echo "If you are in a safe environment, set: export CODEX_ALLOW_DANGER_MODE=1" >&2
    exit 2
  fi
fi

# 4. Flags that switch off approvals, the sandbox, or hook trust.
#    --yolo is an alias of the first flag in some CLI versions.
if grep -qE -- "--dangerously-bypass-approvals-and-sandbox|--dangerously-bypass-hook-trust|--yolo\b" <<<"$COMMAND"; then
  if [ -z "$CODEX_ALLOW_BYPASS" ]; then
    echo "Blocked: this codex flag disables approvals, sandboxing, or hook trust and requires CODEX_ALLOW_BYPASS=1." >&2
    echo "Only use it in isolated, externally sandboxed CI environments." >&2
    exit 2
  fi
fi

# 5. Codex must be installed.
if ! command -v codex >/dev/null 2>&1; then
  echo "Blocked: 'codex' command not found in PATH." >&2
  echo "Install the Codex CLI: https://developers.openai.com/codex/cli" >&2
  exit 2
fi

exit 0
