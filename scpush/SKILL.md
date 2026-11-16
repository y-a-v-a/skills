---
name: scpush
description: Minimal stage, commit and push of the relevant changes in the current git repo. Only runs when the user types /scpush; for "commit and push" in conversation, the gg skill handles it with more checks.
# gg covers the same requests with more safeguards. Two model-invocable skills
# with the same triggers get picked between at random, so this one is the
# explicit fast path only.
disable-model-invocation: true
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Stage, commit, push

1. Run `git status` and `git diff` to see what changed. Mid-merge, mid-rebase, or detached HEAD: stop and say so.
2. Read every untracked file before staging it; a secret can't be skipped unseen. Stage only the files that belong to the current work, by name (never `git add -A` or `.`). Skip secrets, build output, and unrelated edits; mention anything you skipped.
3. Commit with a short message in the style of `git log --oneline -5`. Never `--no-verify`: a failing hook is a real failure, so report it and fix the cause.
4. Push to the current branch's upstream (`git push -u origin HEAD` if none is set). Never force-push; if the push is rejected, stop and report.
5. Report the commit hash and branch in one line.
