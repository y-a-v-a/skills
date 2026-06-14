#!/usr/bin/env bash
#
# link-skill.sh — symlink skills from this repo into ~/.claude/skills
#
# A "skill" is any directory in this repo that directly contains a SKILL.md.
# The link name is taken from the skill's frontmatter `name:` field (falling
# back to the directory name), so nested layouts like codex-agent/skills/codex
# and gpse-skill/skill are linked under their real skill names.
#
# Usage:
#   ./link-skill.sh --all          Link every skill in the repo.
#   ./link-skill.sh <name>         Link only the named skill (e.g. html).
#   ./link-skill.sh <name> --force Replace an existing entry at the destination.
#
# Result: ~/.claude/skills/<name> is a symlink to the skill's directory.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--all | <skill-name>] [--force]

Create symlinks in ${SKILLS_DIR} pointing to the skills in this repo.

  --all          Link every skill found in the repo.
  <skill-name>   Link only the named skill (e.g. html).
  --force, -f    Replace an existing symlink or file at the destination.
  -h, --help     Show this help.

Examples:
  $(basename "$0") --all
  $(basename "$0") html
EOF
}

# Read the frontmatter `name:` of a SKILL.md (empty if absent).
extract_name() {
  awk '
    NR==1 && $0 != "---" { exit }          # no frontmatter
    NR==1 { infm=1; next }
    infm && $0 == "---" { exit }           # end of frontmatter
    infm && /^name:[[:space:]]/ {
      sub(/^name:[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      gsub(/^["'\'']|["'\'']$/, "")        # strip surrounding quotes
      print
      exit
    }
  ' "$1"
}

# Print "name<TAB>dir" for every skill directory in the repo.
discover_skills() {
  find "$REPO_DIR" -name SKILL.md -not -path '*/.git/*' -not -path '*/node_modules/*' \
    | while IFS= read -r skillmd; do
        dir="$(cd "$(dirname "$skillmd")" && pwd)"
        name="$(extract_name "$skillmd")"
        [ -n "$name" ] || name="$(basename "$dir")"
        printf '%s\t%s\n' "$name" "$dir"
      done | sort
}

link_one() {
  local name="$1" dir="$2" dest="$SKILLS_DIR/$1"

  if [ -L "$dest" ]; then
    local current
    current="$(readlink "$dest")"
    if [ "$current" = "$dir" ]; then
      echo "= $name already linked"
      return 0
    fi
    if [ "$FORCE" -eq 1 ]; then
      rm "$dest"
    else
      echo "! $name: existing symlink -> $current (use --force to replace)" >&2
      return 1
    fi
  elif [ -e "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$dest"
    else
      echo "! $name: $dest exists and is not a symlink (use --force to replace)" >&2
      return 1
    fi
  fi

  ln -s "$dir" "$dest"
  echo "+ linked $name -> $dir"
}

FORCE=0
ALL=0
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)        ALL=1 ;;
    --force|-f)   FORCE=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -n "$TARGET" ]; then
        echo "Pass only one skill name." >&2; exit 2
      fi
      TARGET="$1" ;;
  esac
  shift
done

if [ "$ALL" -eq 0 ] && [ -z "$TARGET" ]; then
  usage >&2; exit 2
fi
if [ "$ALL" -eq 1 ] && [ -n "$TARGET" ]; then
  echo "Pass either --all or a single skill name, not both." >&2; exit 2
fi

mkdir -p "$SKILLS_DIR"

status=0
found=0
while IFS=$'\t' read -r name dir; do
  if [ "$ALL" -eq 1 ] || [ "$name" = "$TARGET" ] || [ "$(basename "$dir")" = "$TARGET" ]; then
    found=1
    link_one "$name" "$dir" || status=1
  fi
done < <(discover_skills)

if [ "$ALL" -eq 0 ] && [ "$found" -eq 0 ]; then
  echo "No skill named '$TARGET'. Available skills:" >&2
  discover_skills | cut -f1 | sed 's/^/  - /' >&2
  exit 1
fi

exit "$status"
