---
name: scan-secrets
description: Scan a repository or directory for plaintext secrets — cloud keys, API tokens, passwords, private keys — and report them with every value masked. Uses a built-in Node.js scanner and, when installed, gitleaks for the working tree and the full git history. Invoked as /scan-secrets, optionally with a path and flags, for example "/scan-secrets ~/Projects/api --no-history". Read-only; it never changes, commits, or uploads anything. Use when the user asks to scan or audit a repo for secrets, leaked credentials, API keys or tokens, or to check before publishing or open-sourcing a repository.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# scan-secrets — find plaintext secrets

Answer one question: does this repository contain credentials in plain text,
now or in its git history? Report where, never what.

## Invocation

Arguments provided: $ARGUMENTS

- `/scan-secrets` — scan the current working directory.
- `/scan-secrets <path>` — scan that directory.
- Flags are passed through to the script:

| Flag | Effect |
| --- | --- |
| `--all` | Turn off the false-positive filters of the heuristic rule |
| `--context=N` | Show N masked lines around each built-in finding |
| `--no-gitleaks` | Skip gitleaks even when it is installed |
| `--no-history` | Skip the gitleaks scan of the git history |
| `--json` | Machine-readable report |

## Rule zero: never reveal a secret

The script masks every value (`AKIA…(20 chars)`). Keep it that way.

- Never `cat`, `grep`, `sed`, or otherwise print a matched line unmasked. To
  see context, rerun the script with `--context=N`; its context lines are
  masked too.
- Never put a value, or a partial value beyond the masked prefix the script
  shows, in a reply, file, ticket, commit, or message.
- gitleaks always runs with `--redact` through the script. Do not run it
  yourself without `--redact`.
- Do not test whether a credential works by calling the service with it.

## Steps

1. **Resolve the target.** The path from the arguments, or the current
   working directory. Confirm it exists.

2. **Check for gitleaks.** Run `command -v gitleaks && gitleaks version`.
   - Present: the script uses it automatically.
   - Missing: say so once, with install options —
     `brew install gitleaks` (macOS), or a binary from
     <https://github.com/gitleaks/gitleaks/releases>. Do not install it
     without the user's go-ahead; continue with the built-in scan only.

3. **Run the scan.** The script lives next to this file:

   ```
   node <skill-dir>/scripts/scan-secrets.js <target> [flags]
   ```

   `<skill-dir>` is the directory this SKILL.md is in. Exit code 0 means
   nothing found, 1 means findings, 2 means an error (bad path, or gitleaks
   failed — the message is in the output).

4. **Review the findings.**
   - *High-confidence* built-in matches and gitleaks findings: known token
     formats, treat as real until shown otherwise.
   - *Heuristic* matches: rerun with `--context=3` and judge each one. Drop
     variable references, templating (`{{ }}`, `${ }`), lookups from a
     secrets store, and documentation examples. Keep literals that look like
     real credentials.
   - Discard known false positives with the reason, for example
     `key_algorithm: "EC_secp384r1"` is an algorithm name.
   - Findings that are only in git history were removed or changed later but
     are still retrievable by anyone with clone access.

5. **Report.** Lead with the verdict (secrets found: yes / no). Then:
   - a table of current findings: type, file, line(s), your judgment;
   - a table of history-only findings: type, file;
   - the false positives you dropped, in one line each;
   - what was not covered: gitleaks missing or skipped, files over 5 MB,
     binaries, lines over 2000 characters, and the fact that pattern
     matching misses secrets in unusual formats. The heuristic rule also
     skips letters-only values without digits or symbols
     (`password: "onlyletters"`), because they cannot be told apart from
     identifiers; `--all` shows them.

   Close with the standard advice, in two lines: rotate or revoke anything
   that is or was valid (removing it from the repo does not remove it from
   history), then move it to a secrets manager.

## What gets scanned

| Scanner | Scope |
| --- | --- |
| Built-in, git repo | Tracked plus untracked, non-ignored files (`git ls-files --cached --others --exclude-standard`) |
| Built-in, plain directory | All files, skipping `.git`, `node_modules`, `vendor`, `dist`, `build`, virtualenvs, and similar |
| `gitleaks dir` | Every file on disk, **including gitignored ones** such as a local `.env` |
| `gitleaks git` | Every commit in the history |

Ansible Vault encrypted files and `!vault` values are skipped; they are
encrypted, not plaintext.

## Constraints

- Read-only. Do not edit, delete, commit, or rewrite history to remove a
  finding, even when asked to "clean it up" in the same breath — that is a
  separate task the user must confirm, and it does not undo the leak.
- Do not upload findings anywhere (tickets, chats, issue trackers) unless the
  user asks; when they do, include file paths and secret types only.
