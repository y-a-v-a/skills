---
name: codex-discuss
description: Reach agreement with OpenAI Codex on a design, plan, or approach through a turn-based discussion in a shared markdown file. Use during ideation or planning when you want a second model to challenge and sharpen an approach before any code is written.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: "[topic or question to work through]"
disable-model-invocation: true
allowed-tools: Bash(codex *), Bash(mktemp *), Read, Write, Edit, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        # Hooks run in the session's cwd, not the skill dir, so a relative path
        # never resolves. CLAUDE_PLUGIN_ROOT holds the skill dir in skill hooks;
        # the second path is the standard install location. If neither has the
        # script, block codex commands only (fail closed without locking up Bash).
        - type: command
          command: 'for d in "$CLAUDE_PLUGIN_ROOT" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/codex-discuss"; do [ -f "$d/scripts/validate-codex-command.sh" ] && exec bash "$d/scripts/validate-codex-command.sh"; done; grep -q codex && { echo "Blocked: codex validation hook script not found; reinstall the codex-discuss skill." >&2; exit 2; }; exit 0'
          onFailure: block
---

You drive a structured, turn-based discussion with OpenAI Codex to converge on a
plan **before** implementation. A second model that argues the other side is
worth more than a second model that agrees with you — so the roles are
deliberately adversarial.

## Topic

$ARGUMENTS

## Why two models

You review your own work with a positive bias and review others' work with a
critical one. This skill exploits that: **you propose, Codex challenges.** Codex
is instructed to find the weakest part of each proposal, not to validate it.
Agreement only counts once the objections have actually been answered.

## When to use this (and when not to)

Turn-based discussion is **not the default** — it costs several minutes per
Codex turn plus the upkeep of a shared artifact. For most design questions a
one-shot critique (a single `codex exec` over a brief, or `/codex-review`)
delivers most of the value at a fraction of the cost. Reach for `codex-discuss`
only when the decision has **durable architecture impact, irreversible
migration cost, or a live Blocker/Major disagreement** a single round can't
settle. Otherwise prefer the one-shot and stop there.

## The shared file

One markdown file is the entire conversation. **You are the only writer** —
Codex runs read-only, reads the file from disk, and returns its turn as text,
which you append. This keeps a single source of truth and prevents write races.

Create it in the invoking repo so the reasoning trail can be committed (or
ignored) as the user sees fit:

```
codex-discussions/<slug>.md      # slug = short kebab-case topic, e.g. caching-strategy
```

Template:

```markdown
# Discussion: <Topic>

- **Started:** <date>
- **Participants:** Claude (proposer) · Codex (challenger)
- **Status:** IN_PROGRESS    <!-- IN_PROGRESS | CONVERGED | IMPASSE -->
- **Round:** 1 / <max>

## Goal
<the decision to be made, in one or two sentences>

## Constraints
- <hard requirements, non-negotiables, context>

## Repo context
- <relevant files you found and what each implies>
- <conventions / invariants the challenger must not break>

## Live state
<!-- The canonical current surface — refresh it every round so a stateless Codex
     reads the latest proposal and open objections without mining the transcript
     below. The `## Turn N` sections are the audit log, not the source of truth. -->
- **Current proposal:** <one-paragraph latest proposal>
- **Accepted constraints / risks:** <what both sides have accepted so far>

## Objections (ledger)
<!-- Stable IDs, appended as Codex raises them. Codex's closing turn must address
     every entry by ID. Format:
     - O1: <claim> — OPEN | ANSWERED | ACCEPTED_RISK | WONT_FIX — closure: <turn/file/check> -->
- <none yet>

---

## Turn 1 — Claude (proposer)
<the proposal and the reasoning behind it>

**Signal:** PROPOSE
**Questions for Codex:** <what you most want pressure-tested>
```

## The loop (autonomous)

Run to a conclusion without pausing for the user. Each Codex turn takes
minutes, so after every round print **one line** to the user, for example
`Round 2/5: Codex DISAGREE · open O3, O4 · revising the cache-key proposal`.
A silent multi-minute loop looks the same as a hung one.

Create a fresh scratch directory once, before round 1 (`D="$(mktemp -d)"`);
fixed `/tmp` names collide with a concurrent discussion. Each round:

1. **Codex's turn.** Capture it to a temp file, then append it verbatim under a
   `## Turn N — Codex (challenger)` heading:

   ```bash
   codex exec --sandbox read-only --skip-git-repo-check --cd "$(pwd)" \
     --output-last-message "$D/turn-N.md" \
     "You are the challenger in a design discussion. Read the discussion file at \
      codex-discussions/<slug>.md — start from its '## Live state' and any OPEN \
      '## Objections' — AND open the actual repo files it lists under \
      '## Repo context'; argue from the code itself, not from the proposer's \
      summary of it. Respond with ONLY your next turn as markdown: attack the \
      latest proposal — surface risks, edge cases, hidden costs, and a concrete \
      alternative where you have one. End with a line: \
      'Signal: AGREE | AGREE_WITH_CAVEATS | DISAGREE | NEEDS_INFO'. \
      On the first round you MUST raise at least one substantive objection — do not \
      agree yet. Do not modify any files."
   ```

   `--cd "$(pwd)"` runs Codex in the repo so it can read those files directly;
   `--skip-git-repo-check` avoids the trusted-directory refusal.

   **Round 1 only — point the challenger at the code; don't summarize it for
   it.** Codex runs read-only and starts cold. Write the `## Repo context`
   section as an **index of files to read** — each path plus one line on why it
   matters and any invariant it must not break. This list is a *pointer*, **not
   the evidence**: the prompt above `--cd`s Codex into the repo and tells it to
   open those files itself, so its objections are anchored to the actual code —
   including the negative space (an omitted invariant, a stale command, a
   sibling-skill mismatch) that a prose digest silently hides. Never let the
   digest stand in for the read.

   **Once the ledger has entries,** append to the prompt: `For each OPEN
   objection in the ledger, reply ANSWERED / ACCEPTED_RISK / WONT_FIX with one
   line of closure evidence, or keep it OPEN and say what would close it.` This
   is what makes convergence checkable instead of a prose vibe.

2. **Your turn.** Read Codex's turn. Address each objection honestly — concede
   what's right, defend what's wrong with reasons, revise the proposal. Update
   the **ledger**: give each new objection a stable ID, and set status + closure
   evidence on the ones you've answered. Append a `## Turn N+1 — Claude
   (proposer)` heading ending in a `**Signal:**` line. Then **refresh the
   `## Live state` block** (current proposal + accepted constraints + open O#s)
   so the next, stateless Codex turn reads the canonical surface rather than
   re-deriving it from — and relitigating — the whole transcript.

3. **Check convergence** (see below). If not converged and under the round cap,
   re-run Codex.

### Convergence
- **Maintain the ledger every round.** Each new objection gets a stable ID
  (O1, O2, …); when addressed, set its status (ANSWERED | ACCEPTED_RISK |
  WONT_FIX) with one line of closure evidence — a turn, a file, or a passing
  check. An `AGREED_FOLLOWUP` (design settled, only implementation left) counts
  as closed *for the plan* when both sides name its acceptance test.
- **CONVERGED** only when the two most recent turns both signal `AGREE` or
  `AGREE_WITH_CAVEATS` **and** Codex's final turn has addressed every ledger
  entry by ID with no `OPEN` left. Convergence rests on the ledger, never on a
  prose vibe — and the proposer doesn't declare it alone: Codex must sign off on
  each closure.
- **IMPASSE** when the round cap is hit (default **5** round-trips) without
  convergence, or the same disagreement repeats two rounds running.

When the loop ends, fill in an `## Outcome` section:

```markdown
## Outcome
- **Result:** CONVERGED | IMPASSE
- **Decision:** <the agreed approach, or "no agreement">
- **Agreed plan:**
  1. <concrete, ordered steps both sides accept>
- **Caveats / risks accepted:** <from AGREE_WITH_CAVEATS>
- **Unresolved (impasse only):** <the specific points still in dispute, each
  side's position, and what would settle it>
```

## Variations
- **Codex proposes.** When you want Codex's design instead, write the goal and
  ask Codex for Turn 1; you take the challenger role. Same loop, roles swapped.
- **Deeper context.** Add the global flag `--search` before `exec`
  (`codex --search exec …`; `codex exec` rejects it) to let Codex consult
  external sources, or add `--model <model>` to pick the reviewer model.

## Reporting
After the loop, tell the user: the **result** (converged or impasse), the
**agreed plan** (or the open disagreements with both positions), the number of
rounds, and the **path to the discussion file**. Do not start implementing
unless the user asks — converging on the plan is the deliverable.
