---
name: scpush
description: Stage, commit and push the relevant changes in the current git repo. Use when the user says "stage, commit and push", "commit and push", "ship it", or invokes /scpush.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Stage, commit, push

1. Run `git status` and `git diff` to see what changed.
2. Stage only the files that belong to the current work, by name. Skip secrets, build output, and unrelated edits; mention anything you skipped.
3. Commit with a short message in the style of `git log --oneline -5`.
4. Push to the current branch's upstream (`git push -u origin HEAD` if none is set).
5. Report the commit hash and branch in one line.
