#!/usr/bin/env bash
# check-cli-drift.sh — fail if any user-facing codex skill/doc teaches
# deprecated or divergent Codex CLI guidance. Run from the codex-agent root.
#
# This is O5's acceptance test: identical hook md5 proves one unsafe command is
# blocked, but says nothing about whether the *instructions users copy* have
# drifted (e.g. a flag deprecated by a newer Codex CLI). Three checks:
#
#   1. FORBIDDEN — hand-curated patterns known to be wrong (deprecated flags).
#   2. EXISTS    — every --flag named anywhere in the guidance is accepted by
#                  some codex command (`codex`, `codex exec`, `codex review`).
#   3. POSITION  — inside fenced code blocks, flags on a `codex exec` or
#                  `codex review` command line (including \-continuations) must
#                  be accepted by *that* subcommand. Catches global-only flags
#                  placed after the subcommand, e.g. `codex exec --search`.
#
# 2 and 3 are generated from the installed CLI's --help, so they track every
# release without anyone editing a list. They are skipped when codex is absent.
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
  README.md
)

# Deprecated / forbidden patterns, "pattern|why". Extend as the CLI evolves.
FORBIDDEN=(
  '--full-auto|deprecated by Codex CLI; use --sandbox workspace-write instead'
)

# Flags that belong to the skills' own argument syntax, not to the CLI.
SKILL_FLAGS=' --focus --intent --fix '

drift=0

# A guidance file that moved must be updated here, not silently skipped.
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    drift=1
    echo "DRIFT: guidance file missing: $f (renamed? update FILES in this script)"
  fi
done

# --- 1. FORBIDDEN -----------------------------------------------------------
for entry in "${FORBIDDEN[@]}"; do
  pat="${entry%%|*}"; why="${entry#*|}"
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue   # reported once, below
    if grep -nF -- "$pat" "$f" >/dev/null 2>&1; then
      drift=1
      echo "DRIFT: '$pat' — $why"
      grep -nF -- "$pat" "$f" | sed "s#^#    $f:#"
    fi
  done
done

# --- 2 + 3. Generated from the installed CLI --------------------------------
if ! command -v codex >/dev/null 2>&1; then
  echo "SKIP: codex not on PATH — flag EXISTS/POSITION checks not run"
else
  flags_of() { "$@" --help 2>&1 | grep -oE -- '--[a-z][a-z0-9-]+' | sort -u | tr '\n' ' '; }
  GLOBAL=" $(flags_of codex) "
  EXEC=" $(flags_of codex exec) "
  REVIEW=" $(flags_of codex review) "
  ANY="$GLOBAL $EXEC $REVIEW $SKILL_FLAGS"
  GLOBAL_ONLY=""
  for flag in $GLOBAL; do
    case "$EXEC $REVIEW" in *" $flag "*) ;; *) GLOBAL_ONLY="$GLOBAL_ONLY $flag" ;; esac
  done
  # The GLOBAL-ONLY loop runs in a pipeline subshell; it reports hits here.
  GLOBAL_HITS="$(mktemp)"; trap 'rm -f "$GLOBAL_HITS"' EXIT

  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue

    # EXISTS: flags on lines that invoke codex (not /codex skill commands),
    # plus flag-table rows. Other tools' flags (git, curl) are not ours.
    # $(...) substitutions are stripped first: they belong to other commands.
    for flag in $(sed -E 's/\$\([^)]*\)//g' "$f" \
                  | grep -E '(^|[^/[:alnum:]_-])codex([[:space:]]|$)|^\|[[:space:]]*`--' \
                  | grep -oE -- '--[a-z][a-z0-9-]+' | sort -u); do
      case "$ANY" in *" $flag "*) ;; *)
        drift=1
        echo "DRIFT: '$flag' is not accepted by codex, codex exec, or codex review ($(codex --version 2>/dev/null))"
        grep -nF -- "$flag" "$f" | sed "s#^#    $f:#"
      esac
    done

    # GLOBAL-ONLY: flags `codex` accepts but neither `exec` nor `review` does
    # (e.g. --search). Every mention, prose included, must either put it
    # before the subcommand (`codex --search exec`) or say it is global: a bare
    # table row or "add --search" reads as `codex exec --search`, which fails.
    for flag in $GLOBAL_ONLY; do
      grep -nF -- "$flag" "$f" | while IFS= read -r hit; do
        line="${hit#*:}"
        lower="$(tr '[:upper:]' '[:lower:]' <<<"$line")"
        case "$lower" in *global*) continue ;; esac
        before="${line%%"$flag"*}"
        # OK when the nearest preceding "codex" has no subcommand before the flag.
        if [[ "$before" == *codex* ]]; then
          after_codex="${before##*codex}"
          [[ "$after_codex" =~ (^|[[:space:]])(exec|review)([[:space:]]|$) ]] || continue
        fi
        echo "DRIFT: '$flag' is a global flag (codex $flag exec …) but is not marked as one — $f:${hit%%:*}"
        echo x >> "$GLOBAL_HITS"
      done
    done

    # POSITION: flags on codex exec/review command lines inside code fences.
    # Emits "lineno<TAB>sub<TAB>flag" for each flag that follows the subcommand.
    while IFS=$'\t' read -r ln sub flag; do
      [ -n "$flag" ] || continue
      case "$sub" in exec) allowed="$EXEC" ;; review) allowed="$REVIEW" ;; esac
      case "$allowed" in *" $flag "*) ;; *)
        drift=1
        echo "DRIFT: '$flag' after 'codex $sub' is rejected by the CLI (global-only or unknown) — $f:$ln"
      esac
    done < <(awk '
      /^[[:space:]]*```/ { fence = !fence; cont = 0; next }
      !fence { next }
      {
        line = $0
        gsub(/\$\([^)]*\)/, "", line)   # $(git ...) etc. are other commands
        if (match(line, /(^|[^\/[:alnum:]_-])codex[[:space:]]+(exec|review)([[:space:]]|$)/)) {
          rest = substr(line, RSTART)
          sub(/^[^c]*codex[[:space:]]+/, "", rest)
          cur = (rest ~ /^exec/) ? "exec" : "review"
          sub(/^(exec|review)/, "", rest)
          cont = 1
        } else if (cont) {
          rest = line
        } else {
          next
        }
        while (match(rest, /--[a-z][a-z0-9-]+/)) {
          printf "%d\t%s\t%s\n", NR, cur, substr(rest, RSTART, RLENGTH)
          rest = substr(rest, RSTART + RLENGTH)
        }
        cont = (line ~ /\\[[:space:]]*$/)
      }
    ' "$f")
  done
  [ -s "$GLOBAL_HITS" ] && drift=1
fi

if [ "$drift" -eq 0 ]; then
  echo "PASS: no deprecated/divergent CLI guidance in ${#FILES[@]} guidance files"
  exit 0
fi
echo "FAIL: stale CLI guidance found — update the offending files"
exit 1
