#!/usr/bin/env bash
# check-hook-wiring.sh — test each skill's PreToolUse hook *as wired*, i.e. the
# exact `command:` string from its SKILL.md frontmatter, run the way Claude Code
# runs it: from the session's cwd (never the skill dir), with stdin = tool JSON.
# Run from the codex-agent root.
#
# Why this exists: the §1 unit tests call the validation script by its full
# path, so they passed for months while the frontmatter used a relative path
# that never resolved from a user's project (exit 127 = non-blocking, so every
# command went through). This tests the wiring, not just the script.
#
# Scenarios per skill:
#   A. CLAUDE_PLUGIN_ROOT = skill dir (what Claude Code sets for skill hooks)
#   B. variable unset; skill installed under $CLAUDE_CONFIG_DIR/skills/<name>
#      (codex-validate: under $CLAUDE_PROJECT_DIR/.claude/skills/)
#   C. script nowhere: codex commands blocked, other commands still allowed
set -u

SKILLS=(skills/codex skills/codex-review skills/codex-discuss .claude/skills/codex-validate)
ROOT="$(pwd)"
ELSEWHERE="$(mktemp -d)"     # stands in for a user's project directory
trap 'rm -rf "$ELSEWHERE"' EXIT

fail=0
DANGER='{"tool_input":{"command":"codex exec -s danger-full-access x"}}'
BENIGN='{"tool_input":{"command":"codex exec --sandbox read-only -o out.txt - < brief.md"}}'
OTHER='{"tool_input":{"command":"ls -la"}}'

expect() {  # expect <want> <label> <json> [env assignments...]
  local want="$1" label="$2" json="$3"; shift 3
  local got
  got="$(cd "$ELSEWHERE" && printf '%s' "$json" | env -u CLAUDE_PLUGIN_ROOT "$@" bash -c "$CMD" >/dev/null 2>&1; echo $?)"
  if [ "$got" = "$want" ]; then
    echo "  ok   [$got] $label"
  else
    echo "  FAIL [$got, want $want] $label"; fail=1
  fi
}

for s in "${SKILLS[@]}"; do
  md="$s/SKILL.md"; name="$(basename "$s")"
  echo "== $name"
  # The hook command, single-quoted or plain YAML scalar.
  CMD="$(sed -n 's/^ *command: *//p' "$md" | head -1)"
  CMD="${CMD#\'}"; CMD="${CMD%\'}"
  if [ -z "$CMD" ]; then
    echo "  FAIL no hook command found in $md"; fail=1; continue
  fi
  if ! grep -qE '^ *onFailure: block$' "$md"; then
    echo "  FAIL hook lacks 'onFailure: block' (a hook that cannot start must not fail open)"; fail=1
  fi

  # A. the variable Claude Code sets
  expect 2 "A danger blocked (CLAUDE_PLUGIN_ROOT)" "$DANGER" CLAUDE_PLUGIN_ROOT="$ROOT/$s"
  expect 0 "A other command allowed"               "$OTHER"  CLAUDE_PLUGIN_ROOT="$ROOT/$s"
  if command -v codex >/dev/null 2>&1; then
    expect 0 "A safe codex command allowed"        "$BENIGN" CLAUDE_PLUGIN_ROOT="$ROOT/$s"
  fi

  # B. fallback install location
  fake="$(mktemp -d)"
  if [ "$name" = codex-validate ]; then
    mkdir -p "$fake/.claude/skills"; ln -s "$ROOT/$s" "$fake/.claude/skills/$name"
    expect 2 "B danger blocked (fallback: project dir)" "$DANGER" CLAUDE_PROJECT_DIR="$fake"
  else
    mkdir -p "$fake/skills"; ln -s "$ROOT/$s" "$fake/skills/$name"
    expect 2 "B danger blocked (fallback: config dir)"  "$DANGER" CLAUDE_CONFIG_DIR="$fake"
  fi
  rm -rf "$fake"

  # C. script missing everywhere
  empty="$(mktemp -d)"
  expect 2 "C codex command blocked when script is missing" "$DANGER" \
    CLAUDE_CONFIG_DIR="$empty" CLAUDE_PROJECT_DIR="$empty" HOME="$empty"
  expect 0 "C other command still allowed when script is missing" "$OTHER" \
    CLAUDE_CONFIG_DIR="$empty" CLAUDE_PROJECT_DIR="$empty" HOME="$empty"
  rm -rf "$empty"
done

if [ "$fail" -eq 0 ]; then echo "PASS: hooks block as wired, from any cwd"; exit 0; fi
echo "FAIL: hook wiring broken — see above"; exit 1
