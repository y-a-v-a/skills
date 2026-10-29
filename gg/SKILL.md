---
name: gg
description: Stage, commit and push the current file changes in one pass. Use when the user asks to commit, "commit and push", "stage and push my changes", "ship this", or invokes /gg. Reads the working tree, writes a commit message in the repository's own style, pushes to the tracking branch, and reports the short SHA. Never force-pushes, never bypasses hooks, and never commits without showing what it staged.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# gg — stage, commit, push

One invocation takes the working tree from dirty to pushed.

## Invocation

- `/gg` — all changes in the working tree.
- `/gg <message>` — same, but use the given text as the commit subject.
- `/gg <path> [<path>…]` — restrict staging to those paths.

Arguments that name existing paths are paths; anything else is the message.

## Steps

1. **Read the state.** In one batch:
   `git status --porcelain=v1 -b`, `git diff`, `git diff --cached`,
   `git log -10 --pretty=format:'%s%n%b'`.
   Nothing staged and nothing modified: say so and stop.

2. **Learn the message style** from `git log`: subject mood and
   capitalization, subject length, whether bodies are used and how they wrap,
   which trailers appear. Follow that repository, not a generic convention.

3. **Check what you are about to stage.** Read every untracked file before
   staging it. Do not stage, and name to the user instead:
   - credentials and secrets — `.env*`, `*.pem`, `*.p12`, `id_rsa`, tokens,
     API keys, connection strings, anything that reads like a secret inside a
     diff;
   - build output, dependency directories, editor and OS cruft, coverage
     reports, local scratch files;
   - anything over ~1 MB, and any binary the user has not mentioned.
   A file that should be ignored belongs in `.gitignore`, not in the commit.

4. **Stage.** `git add -- <paths>` for the resolved path list. Explicit paths
   only — never `git add -A` or `git add .`, so nothing arrives in the commit
   unseen.

5. **Show and commit.** Print the staged file list and the message you intend
   to use, then commit with a heredoc:

   ```
   git commit -F - <<'MSG'
   <subject>

   <body: what changed and why, wrapped as the repo wraps it>

   <trailers the repo uses>
   MSG
   ```

   - Subject: imperative mood, no trailing period, ≤ 50 characters.
   - Body only when the *why* is not obvious from the subject.
   - Keep the repository's trailers, including
     `Co-Authored-By: Claude <model> <noreply@anthropic.com>` if the log has it.
   - Never `--no-verify`, never `--amend` a commit that is already pushed.
   - A failing hook is a real failure: report its output, fix the cause, retry.
     Do not work around it.

6. **Push.** Upstream set: `git push`. No upstream:
   `git push -u origin $(git branch --show-current)`.
   - Never `--force`. If the push is rejected as non-fast-forward, stop and
     report — the pull/rebase is the user's call.
   - `--force-with-lease` only on an explicit request, never on your own
     judgment.
   - Pushing to the default branch is fine when that is where the user already
     is; do not silently create a branch instead.

7. **Report** one line: short SHA, subject, branch, and how many files went in.

## Constraints

- Commit only what this invocation covers. Unrelated pending work stays dirty.
- Never rewrite published history, and never reset, checkout over, or clean
  files to make the commit tidier — that destroys work.
- If the repository is mid-merge, mid-rebase, or in a detached HEAD, stop and
  say so.
