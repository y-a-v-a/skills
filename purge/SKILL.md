---
name: flushcache
description: Purge Akamai edge cache via the Akamai CLI. Invoked as /flushcache with one or more URLs, CP codes, or cache tags — for example "/flushcache https://example.com". Defaults to invalidate on production, supports --staging and --delete, verifies credentials before running, and confirms before any broad purge.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# flushcache — purge Akamai edge cache

Wrapper around `akamai purge` (Akamai CLI). One invocation purges one set of
targets on one network.

## Invocation contract

Arguments provided: $ARGUMENTS

Parse into four things:

| Part | How it is decided | Default |
| --- | --- | --- |
| Targets | every non-flag token | — (required) |
| Target type | URL / CP code / cache tag — see below | URL |
| Operation | `invalidate`, or `delete` if `--delete` is present | `invalidate` |
| Network | `--staging` if present, else production | production |

Target type is inferred from the tokens, and **all targets must be the same
type** — the CLI takes one flag for the whole call:

- Starts with `http://` or `https://` → URL.
- All-digit token (e.g. `1234567`) → CP code, pass `--cpcode`.
- Anything else → cache tag, pass `--tag`.

Overrides win over inference: `--cpcode`, `--tag`, or `--url` (a skill-level
override — the CLI has no `--url` flag, URLs are the unflagged default, so
never pass it through). If the tokens are mixed types, stop and ask which the
user meant — do not split into two calls.

Reject, with one line and no command run:

- **No targets** → `Need a URL, CP code, or cache tag.`
- **Bare hostname** (`example.com`, `www.example.com/path`) → say a URL target
  must include the scheme, and offer `https://example.com`. Do not add the
  scheme silently: a wrong guess purges nothing and reports success.

## Preflight

Run `scripts/preflight.sh` before the first purge of a session. It checks the
`akamai` binary, the `purge` package, and the credentials file; it prints
findings only, never credential values.

If it fails, stop and relay its message. Do not run a purge "to see what
happens" — an unconfigured CLI fails after the arguments are parsed, which
looks the same as a target that matched nothing.

Setup, when credentials are missing (the file is created by the user, not by
this skill):

1. In Akamai Control Center → Identity & Access Management, create an API
   client with the **CCU APIs** service set to READ-WRITE.
2. Download the credentials and place them in `~/.edgerc` under a `[ccu]`
   section: `client_secret`, `host`, `access_token`, `client_token`.
3. `chmod 600 ~/.edgerc`.

`~/.edgerc` holds live production credentials. It never goes in a repository,
a scratch file, a ticket, or chat output. If the user pastes credentials into
the conversation, write them to `~/.edgerc` and say they should be rotated.

Non-default locations are supported by the CLI and should be passed through
when the user names them: `--edgerc <path>`, `--section <name>` (default
`ccu`), `--accountkey <key>` for account switching.

## Running

```bash
akamai purge invalidate https://example.com/path
akamai purge invalidate --staging https://example.com/path
akamai purge invalidate --cpcode 1234567
akamai purge invalidate --tag product-detail
akamai purge delete https://example.com/path
```

More targets than fit comfortably on a line — pipe them instead, the CLI reads
STDIN:

```bash
printf '%s\n' "${urls[@]}" | akamai purge invalidate
```

### Confirm before firing

Run without asking when **all** of these hold: operation is `invalidate`,
targets are URLs, and there are at most 10 of them. That is the case
`/flushcache <url>` was written for, and the user already named the target.

Otherwise print the exact command and get a yes first. Namely:

- `--delete` — evicts the object instead of marking it stale, so the next
  request is a guaranteed origin miss.
- `--cpcode` or `--tag` — the blast radius is a whole property or content set,
  not one object, and a large eviction sends a burst of traffic to origin.
- More than 10 URLs.

A purge cannot be undone or recalled. Say which network is being hit, in
words, every time — "production" is the CLI default and the expensive one.

## Reporting

Relay what the CLI returned: the purge id and the estimated completion time it
prints. The command returning is a *submission*, not a completed purge —
propagation typically takes a few seconds. Do not claim the cache is cleared;
say the purge was submitted and give the estimate.

On failure, show the CLI's error verbatim. Common ones:

- `403` — the API client lacks CCU READ-WRITE, or the URL's property is not on
  this account (try `--accountkey`).
- `Unable to find section` — wrong `--section`; the purge default is `ccu`.

## Guardrails

- One network per invocation. To do staging and production, run twice, and
  state both.
- Never widen the user's targets — no "while we're at it, also the CP code",
  no adding `/*`, no expanding a path to its parent.
- `akamai purge list` shows installed purge subcommands, not purge history. Do
  not present it as an audit trail.
