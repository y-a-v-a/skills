---
name: codex-review
description: Cross-model code review with OpenAI Codex. A different model reviews the diff, findings are triaged by severity, and contested findings are reconciled with Codex before you act — so Claude-authored changes get reviewed without self-review bias.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: '[--uncommitted | --base <branch> | --commit <sha>] [--focus security|performance|correctness|tests] [--intent "<what the change should do>"]'
disable-model-invocation: true
allowed-tools: Bash(codex *), Bash(git diff:*), Bash(git log:*), Read, Write, Edit, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: bash scripts/validate-codex-command.sh
---

You run a code review with OpenAI Codex and then **act as the author's critical
counterpart**: a different model reviews the change, you triage what it finds,
and you reconcile anything contested before reporting.

## Request

$ARGUMENTS

## Why cross-model

A model reviewing its own diff is biased toward approving it. The value here is
that Codex — a *different* model — reviews the change. So this is most useful on
**Claude-authored diffs**: it's the second opinion you can't give yourself.

## Workflow

1. **Frame the intent.** If `--intent` is given, use it. Otherwise infer what the
   change is trying to do from the diff and recent commit messages, and state it
   in one sentence. Review against intent, not just mechanics.

2. **Run the review.** Use the scope flag the user passed:

   ```bash
   codex review --uncommitted          # working-tree changes
   codex review --base main            # branch vs base
   codex review --commit <sha>         # one commit
   ```

   For a `--focus` pass, or to get structured output, run a directed review over
   the diff instead. `codex exec` consumes **one** prompt — a second positional
   arg (`"$(cat /tmp/review.diff)"`) is not reliably read, so the model can end
   up reviewing with no diff in front of it. Build a single brief that embeds the
   intent *and* the diff, then pass that one file:

   ```bash
   git diff <scope> > /tmp/review.diff
   {
     echo "## Intent"
     echo "<intent — what this change should do>"
     echo
     echo "## Focus"
     echo "<focus: security|performance|correctness|tests>"
     echo
     echo "## Instructions"
     echo "For each finding give: severity (Blocker|Major|Minor|Nit), category"
     echo "(correctness|security|performance|maintainability|tests), file:line, the"
     echo "problem, and a concrete fix. Be specific; skip praise."
     echo
     echo "## Diff"
     echo '```diff'
     cat /tmp/review.diff
     echo '```'
   } > /tmp/codex-review-brief.md
   codex exec --sandbox read-only --output-last-message /tmp/codex-review.md \
     "$(cat /tmp/codex-review-brief.md)"
   ```

3. **Triage every finding.** Don't accept findings on the reviewer's authority —
   judge each one against the code and the intent, and mark it:

   | Outcome | Meaning |
   |---------|---------|
   | **Accept** | Real; should be fixed |
   | **Reject** | False positive or out of scope — record *why* |
   | **Defer** | Real but not for this change — note follow-up |
   | **Discuss** | Genuinely unsure, or you and Codex disagree on a Blocker/Major |

4. **Reconcile what's contested.** For every `Discuss` item (and any `Reject` on a
   Blocker/Major), put your rebuttal back to Codex for one round so the two models
   actually settle it rather than you silently overruling:

   ```bash
   codex exec --sandbox read-only --output-last-message /tmp/codex-reply.md \
     "You flagged: <finding>. My position: <your rebuttal>. Is the issue real as \
      stated? Reply: HOLD (with the concrete failing case) or WITHDRAW (with why). \
      One paragraph."
   ```

   Record the resolution. A Blocker that survives reconciliation stays a Blocker.

5. **Report and (optionally) act.** Summarize by severity. If there are findings
   worth tracking, write a report to `codex-reviews/<slug>.md` in the repo:

   ```markdown
   # Review: <scope> — <date>
   **Intent:** <one line>   **Result:** <N blockers, N major, ...>

   ## Findings
   - [Accept · Major · correctness] file:line — <problem> → <fix>
   - [Reject · Minor · style] file:line — <problem> — *rejected: <reason>*
   - [Discuss → HELD · Blocker · security] file:line — <problem> → <fix>

   ## Reconciled
   - <finding> — Codex HELD/WITHDREW: <one line>
   ```

   Apply accepted fixes only if the user asked for changes; otherwise hand back
   the triaged findings and the report path.

## Reporting
Lead with the blockers. State counts by severity, what you accepted vs rejected
(and why), how contested findings were reconciled, and the report path.
