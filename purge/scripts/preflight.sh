#!/usr/bin/env bash
#
# preflight.sh — verify the Akamai CLI can run a purge.
#
# Checks the binary, the purge package, and the credentials section. Prints
# findings and setup instructions; never prints a credential value.
#
# Usage: preflight.sh [--section <name>] [--edgerc <path>]
# Exit:  0 ready · 1 not ready

set -uo pipefail

SECTION="${AKAMAI_EDGERC_SECTION:-ccu}"
EDGERC="${AKAMAI_EDGERC:-${HOME}/.edgerc}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION="${2:?--section needs a value}"; shift 2 ;;
    --edgerc)  EDGERC="${2:?--edgerc needs a value}";   shift 2 ;;
    -h|--help) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

fail() { echo "NOT READY: $*"; exit 1; }

command -v akamai >/dev/null 2>&1 \
  || fail "the 'akamai' binary is not on PATH. Install it with: brew install akamai"

# Captured, not piped: grep -q closes the pipe early, which trips pipefail.
installed="$(akamai list 2>/dev/null)"
grep -qE '^[[:space:]]+purge' <<<"$installed" \
  || fail "the purge package is not installed. Install it with: akamai install purge"

[[ -f "$EDGERC" ]] && fail_missing="" || fail_missing=1
if [[ -n "$fail_missing" ]]; then
  cat <<MSG
NOT READY: no credentials file at ${EDGERC}

Create one:
  1. Akamai Control Center -> Identity & Access Management -> new API client,
     with the CCU APIs service set to READ-WRITE.
  2. Write the downloaded credentials to ${EDGERC}:

       [${SECTION}]
       client_secret = ...
       host          = ...
       access_token  = ...
       client_token  = ...

  3. chmod 600 ${EDGERC}
MSG
  exit 1
fi

perms="$(stat -f '%Lp' "$EDGERC" 2>/dev/null || stat -c '%a' "$EDGERC" 2>/dev/null)"
[[ "$perms" == "600" ]] || echo "WARNING: ${EDGERC} is mode ${perms:-unknown}; run: chmod 600 ${EDGERC}"

# Keys present in the requested section, values never printed.
missing="$(
  awk -v want="$SECTION" '
    /^[[:space:]]*\[/ {
      section = $0
      gsub(/^[[:space:]]*\[[[:space:]]*|[[:space:]]*\][[:space:]]*$/, "", section)
      in_section = (section == want)
      next
    }
    in_section && /^[[:space:]]*[A-Za-z_]+[[:space:]]*=/ {
      key = $0
      sub(/[[:space:]]*=.*$/, "", key)
      gsub(/^[[:space:]]+/, "", key)
      seen[key] = 1
    }
    END {
      split("client_secret host access_token client_token", need, " ")
      for (i in need) if (!(need[i] in seen)) printf "%s ", need[i]
    }
  ' "$EDGERC"
)"

if [[ -z "$(awk -v want="$SECTION" '/^[[:space:]]*\[/ { s=$0; gsub(/^[[:space:]]*\[[[:space:]]*|[[:space:]]*\][[:space:]]*$/,"",s); if (s==want) print "y" }' "$EDGERC")" ]]; then
  fail "${EDGERC} has no [${SECTION}] section. Add one, or pass --section with the right name."
fi

[[ -z "${missing// /}" ]] \
  || fail "[${SECTION}] in ${EDGERC} is missing: ${missing% }"

echo "READY: akamai purge, credentials [${SECTION}] in ${EDGERC}"
