#!/usr/bin/env bash
# check-cli-drift.sh — fail if any user-facing codex skill/doc teaches
# deprecated or divergent Codex CLI guidance. Run from the repo root.
#
# This is O5's acceptance test: identical hook md5 proves one unsafe command is
# blocked, but says nothing about whether the *instructions users copy* have
# drifted (e.g. a flag deprecated by a newer Codex CLI). This catches that.
#
# Scope note: the validator's own SKILL.md and any scripts/ file are NOT scanned
# on purpose — they *define and test* the ban (they name deprecated flags), so
# scanning them would be a self-referential false positive.
set -u

# User-facing guidance surfaces — what people read and copy.
FILES=(
  skills/codex/SKILL.md
  skills/codex-review/SKILL.md
  skills/codex-discuss/SKILL.md
  docs/reference.md
  docs/testing.md
)

# Deprecated / forbidden patterns, "pattern|why". Extend as the CLI evolves.
FORBIDDEN=(
  '--full-auto|deprecated by Codex CLI; use --sandbox workspace-write instead'
)

drift=0
for entry in "${FORBIDDEN[@]}"; do
  pat="${entry%%|*}"; why="${entry#*|}"
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    if grep -nF -- "$pat" "$f" >/dev/null 2>&1; then
      drift=1
      echo "DRIFT: '$pat' — $why"
      grep -nF -- "$pat" "$f" | sed "s#^#    $f:#"
    fi
  done
done

if [ "$drift" -eq 0 ]; then
  echo "PASS: no deprecated/divergent CLI guidance in ${#FILES[@]} guidance files"
  exit 0
fi
echo "FAIL: stale CLI guidance found — update the offending files"
exit 1
