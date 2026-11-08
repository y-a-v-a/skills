---
name: codex-review
description: Cross-model code review with OpenAI Codex. A different model reviews the diff, findings are triaged by severity, and contested findings are reconciled with Codex before you act — so Claude-authored changes get reviewed without self-review bias.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: '[--uncommitted | --base <branch> | --commit <sha>] [--focus security|performance|correctness|tests] [--intent "<what the change should do>"]'
disable-model-invocation: true
allowed-tools: Bash(codex *), Bash(git diff:*), Bash(git log:*), Bash(mktemp *), Read, Write, Edit, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        # Hooks run in the session's cwd, not the skill dir, so a relative path
        # never resolves. CLAUDE_PLUGIN_ROOT holds the skill dir in skill hooks;
        # the second path is the standard install location. If neither has the
        # script, block codex commands only (fail closed without locking up Bash).
        - type: command
          command: 'for d in "$CLAUDE_PLUGIN_ROOT" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/codex-review"; do [ -f "$d/scripts/validate-codex-command.sh" ] && exec bash "$d/scripts/validate-codex-command.sh"; done; grep -q codex && { echo "Blocked: codex validation hook script not found; reinstall the codex-review skill." >&2; exit 2; }; exit 0'
          onFailure: block
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
   codex review --uncommitted < /dev/null     # working-tree changes
   codex review --base main < /dev/null       # branch vs base
   codex review --commit <sha> < /dev/null    # one commit
   ```

   Keep `< /dev/null`: `codex review` reads stdin until it closes, and in an
   agent's shell stdin is often a pipe that never closes, so the review hangs
   forever (measured: a 22-second review took exactly as long as the pipe
   stayed open).

   For a `--focus` pass, or to get structured output, run a directed review over
   the diff instead. `codex exec` consumes **one** prompt — a second positional
   arg (`"$(cat review.diff)"`) is not reliably read, so the model can end
   up reviewing with no diff in front of it. Build a single brief that embeds the
   intent *and* the diff, then pass that one file **on stdin** (`-`). Don't
   inline it with `"$(cat …)"`: Linux caps a single argument at 128 KB, which a
   branch diff easily passes.

   ```bash
   D="$(mktemp -d)"     # fresh per run; fixed /tmp names collide between sessions
   git diff <scope> > "$D/review.diff"
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
     cat "$D/review.diff"
     echo '```'
   } > "$D/brief.md"
   codex exec --sandbox read-only --output-last-message "$D/review.md" - < "$D/brief.md"
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
   actually settle it rather than you silently overruling.

   This call is a **fresh, stateless** Codex: it has not seen the review, the
   diff, or the finding. A one-line "You flagged X" makes it judge a claim with
   no code in front of it. Give it a self-contained brief and run it in the repo
   so it can open the file itself. Write this to `$D/reconcile.md` with the
   Write tool:

   ```markdown
   ## Change under review
   <intent, one line>

   ## The finding
   <severity · category> <file>:<line> — <the finding as Codex stated it>

   ## The code
   <the diff hunk for that location, plus surrounding lines if they matter>

   ## Rebuttal
   <your position and the evidence for it>

   ## Question
   Open <file> yourself and check. Is the issue real as stated? Reply HOLD (with
   the concrete failing input or sequence) or WITHDRAW (with why). One paragraph.
   ```

   Then:

   ```bash
   codex exec --sandbox read-only --cd "$(git rev-parse --show-toplevel)" \
     --output-last-message "$D/reply.md" - < "$D/reconcile.md"
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

   The report lands inside the user's repo. If `codex-reviews/` is neither
   tracked nor gitignored there, say so in the report-back and offer once to
   add it to `.gitignore`, so it isn't swept into the next commit by accident.

   Apply accepted fixes only if the user asked for changes; otherwise hand back
   the triaged findings and the report path.

## Reporting
Lead with the blockers. State counts by severity, what you accepted vs rejected
(and why), how contested findings were reconciled, and the report path.
