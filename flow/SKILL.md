---
name: flow
description: >
  Run and maintain a Ralph-style throwaway-session development workflow, where durable
  project state lives in PLAN.md (spec), TASKLIST.md (work queue), and PROCESS.md
  (append-only journal). Use to bootstrap these files, to execute one bounded unit of work
  per fresh-context iteration and record state back to disk, to report status, or to
  replan. Each run reconstructs state from the files, does one task, updates the files, and
  stops. Not for open-ended interactive coding within a single session.
argument-hint: "[init <description> | next | status | replan]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
---

# Flow

A guide and proxy for a "Ralph"-style development workflow: the durable state of a project
lives entirely in three files, and each coding session is **throwaway** — every run starts
with fresh, empty context. You are run in a loop with a fixed prompt; each iteration
rebuilds its understanding from the files on disk, does **one bounded unit of work**,
records what happened back to disk, and exits. The next run starts clean. This trades the
illusion of a long memory for durable, inspectable state and avoids long-session context rot.

The three files:

- **PLAN.md** — the PRD-like spec: goal, requirements, constraints. The slow-changing "why + what".
- **TASKLIST.md** — the decomposed, actionable work queue with status. The fast-changing "what's next".
- **PROCESS.md** — an append-only journal of what happened each iteration. The cross-session memory.

## Arguments

Arguments provided: $ARGUMENTS

Parse the first token as the mode:

- `init` — bootstrap the three files; the rest of the arguments is the project description.
- `next` (alias `work`) — execute one bounded unit of work, then stop.
- `status` — read-only report. **This is also the default when no arguments are given.**
- `replan` — deliberately revise PLAN.md and repair the tasklist.
- Anything else — treat the arguments as a free-form instruction, default to `status`, and
  ask the user what they want before changing anything.

## The three files

These formats are the contract. A fresh-context session can only orient if every session
writes them the same way. Keep machine-readable bits as simple inline conventions
(checkbox state, `id:` tags, sentinel lines) — do not embed YAML/JSON blobs that rot.

### PLAN.md

```markdown
# PLAN: <project name>

Status: active            <!-- active | needs-replan -->
Last reviewed: 2026-06-14

## Goal
One paragraph. The single outcome that defines "done" for the whole project.

## Requirements
- R1: <must-have, testable statement>
- R2: ...
(Number them. Tasks and PROCESS entries reference these IDs.)

## Non-goals
- Explicitly out of scope. Guards against drift.

## Architecture / approach
Key components, boundaries, and the chosen approach. Enough that a fresh agent
does not redesign from scratch.

## Constraints
- Language/runtime, libraries allowed/forbidden, performance, style, "don't touch X", etc.

## Definition of done
A checklist of conditions that mean the whole project is complete. The loop's terminal
"all done" check is: every item here is satisfied AND TASKLIST has no open tasks.
```

### TASKLIST.md

```markdown
# TASKLIST

<!-- Status markers: [ ] todo   [~] in-progress   [x] done   [!] blocked
     Each task has: a stable id, a one-line action, a mandatory verify command,
     the requirement it serves, and an attempts counter.
     attempts: bump on each failed verification; >= 3 means escalate to [!] blocked. -->

## Now
- [~] (t012) Implement token refresh in auth client
      req: R3
      verify: `npm test -- auth/refresh`
      attempts: 1
      note: started 2026-06-14, see PROCESS#it-018

## Next
- [ ] (t013) Add retry/backoff to token refresh
      req: R3
      verify: `npm test -- auth/retry`
      attempts: 0

## Blocked
- [!] (t009) Migrate to v2 config schema
      req: R5
      reason: PLAN ambiguous on backward-compat; needs human decision
      see: PROCESS#it-015

## Done
- [x] (t011) Scaffold auth client module   req: R3   verified: `npm test -- auth/client` ✓ it-017
```

Rules that matter:

- **Four states only:** `[ ]` todo, `[~]` in-progress, `[x]` done, `[!]` blocked.
- **Stable `id`** (e.g. `t012`) so PROCESS can reference a task even after it moves sections.
- **`verify:` is mandatory** on every actionable task. A task with no verify command is
  malformed — add one before working it. This is the mechanism that prevents marking work
  "done" without evidence.
- **`attempts:` counter** bumps on each failed verify; at `>= 3` the task escalates to `[!]
  blocked` instead of being retried forever.
- **Sections are a coarse priority queue:** pick the top of `Now`, else the top of `Next`.

### PROCESS.md

Append-only, **newest at the bottom**, one entry per iteration, fixed schema. Never edit
past entries.

```markdown
# PROCESS LOG
<!-- Append-only. Newest at the bottom. Never edit past entries.
     One entry per iteration. Orientation reads the last ~3 entries plus all
     dead-end: lines before doing anything. -->

---
## it-017  ·  2026-06-14T09:12Z
task: t011 — Scaffold auth client module
action: created src/auth/client.ts with stub methods; added test scaffold
result: DONE — verify `npm test -- auth/client` → 4 passing
decisions: chose fetch over axios (constraint: no new deps in PLAN)
dead-end: none
next: t012 (implement token refresh)
```

Entry schema (every entry, exactly these keys): `it-NNN` + UTC timestamp, `task`, `action`,
`result` (one of `DONE` / `IN-PROGRESS` / `BLOCKED` / `NO-OP`, plus the verify command and
its observed output), `decisions`, `dead-end`, `next`.

`dead-end:` is the most valuable field for a fresh session: it records what was tried and
must NOT be retried. Orientation greps `^dead-end:` across the whole file so each session
inherits the scar tissue of every prior one.

## Orientation protocol (always run first)

Run this before any mode except `init` on an empty project:

1. Read **PLAN.md** fully (small and slow-changing).
2. Read **TASKLIST.md** fully.
3. Read the **last ~3 entries of PROCESS.md**, and `grep` all `^dead-end:` lines across the
   whole file.
4. **Reconcile against reality.** Code + tests are ground truth; TASKLIST is only a hint. If
   a `[~] in-progress` task exists, run its `verify:` — a prior session may have died
   mid-task, so it may actually be done, or abandoned and needing a clean restart.
5. Form a 3–5 line internal summary: current goal, last action, open/blocked tasks, known
   dead-ends. This is your reconstructed state.

## Mode: status

Read-only. Print the orientation summary as a report: the goal, progress (done/total tasks,
blocked count), the next recommended task, any drift or blockers, and the exact command to
run next (usually `/flow next`). **Modify nothing.** This is the default when no mode is given.

## Mode: next (alias: work)

The core loop step. Do exactly one bounded unit of work:

1. Run the orientation protocol.
2. **Pick one task:** top of `Now`, else top of `Next`. Skip `[!] blocked`. If there are no
   open tasks, emit the all-done signal (see STOP signals) and stop.
3. **Bound it.** If the task cannot be completed *and verified* in this single iteration,
   do not start it — instead split it into smaller tasks in TASKLIST, append a `NO-OP`
   PROCESS entry recording the split, emit `FLOW: CONTINUE`, and stop. (Splitting is itself
   a complete, durable, verifiable unit of work.)
4. Mark the task `[~] in-progress`, ensure it has `verify:` and `attempts:`, and **write
   TASKLIST to disk before doing the work** so a mid-task death is recoverable.
5. Do the work, staying within PLAN constraints. **Do not edit PLAN.md.** If you discover
   the spec is wrong or ambiguous, do not silently work around it — stop and record drift
   as a blocker (see step 8 / `FLOW: REPLAN`).
6. **Verify:** run the task's `verify:` command and capture the actual observed output.
7. **On success:** mark the task `[x] done`, move it to the `Done` section with `verified:
   <cmd> ✓ it-NNN`, append a PROCESS entry (`result: DONE` + verify output), optionally
   commit (see durability), then emit `FLOW: CONTINUE` (or `FLOW: DONE` if this was the last
   task and the PLAN definition-of-done is met) and stop.
8. **On failure:** bump `attempts`. If `attempts >= 3`, mark the task `[!] blocked` with a
   `reason:`, append a PROCESS entry, emit `FLOW: BLOCKED`, and stop. Otherwise leave it
   `[~]`, append a PROCESS entry capturing the failure as a `dead-end:`, emit `FLOW:
   CONTINUE`, and stop — the next iteration retries with that dead-end recorded. **Never
   mark a task done on a failed verify.**
9. Do not pick up a second task. One bounded unit per run, then stop.

**Durability (optional, recommended):** the hard boundary is that the three files are
written and internally consistent before you stop. If the project clearly uses git and you
are on a working branch, also commit the three files plus the code change as the iteration
boundary — but the files on disk, not the commit, are the source of truth. Do not introduce
git into a project that is not already using it.

## Mode: init <description>

Bootstrap a new project. If PLAN.md / TASKLIST.md / PROCESS.md already exist, **do not
overwrite** — report what is there and ask the user how to proceed.

Otherwise:

1. Draft **PLAN.md** from the description: goal, numbered requirements, non-goals,
   architecture/approach, constraints, and a definition-of-done checklist. If the
   description is thin, ask a few targeted questions before writing.
2. Decompose the plan into an initial **TASKLIST.md**, each task with a `verify:` command
   and `attempts: 0`.
3. Create **PROCESS.md** with an `it-000` "project initialized" entry.
4. Finish by recommending `/flow next`.

## Mode: replan

The **only** mode permitted to edit PLAN.md. Triggered by a human, or when drift has
accumulated.

1. Run orientation.
2. Surface drift: blocked tasks citing PLAN ambiguity, requirements with no tasks, tasks
   with no requirement, definition-of-done items that no longer hold.
3. Propose PLAN edits and **confirm with the user** before applying them.
4. Apply the edits, set `Status: active`, bump `Last reviewed`.
5. Repair/re-derive TASKLIST to match the revised plan; resolve tasks the replan unblocks.
6. Append a PROCESS entry documenting what changed and why.

## Discipline rules

- One bounded unit of work per `next`, then STOP. Never greedily continue.
- Write durable, consistent state before stopping. Files on disk are the source of truth.
- PLAN.md is read-only outside `replan`. Flag drift as a blocker; never silently rewrite the spec.
- Never mark a task done without a recorded, passing `verify:`.
- Ground truth is code + tests, not the tasklist. Re-verify in-progress tasks on orientation.
- Record every dead-end in PROCESS, and read prior dead-ends before acting.
- Escalate to `[!] blocked` after 3 failed attempts instead of retrying forever.
- PROCESS.md is append-only. Never edit past entries.

## STOP signals

Every `next` iteration prints exactly one sentinel line as the **last line of stdout**:

```
FLOW: CONTINUE   — work done, more tasks remain
FLOW: DONE       — all tasks done AND the PLAN definition-of-done is met
FLOW: BLOCKED    — needs human input; the reason is on the preceding line
FLOW: REPLAN     — drift detected; a human should run /flow replan
FLOW: FAILED     — repeated verification failure (attempts >= 3)
```

The line matches `^FLOW: (CONTINUE|DONE|BLOCKED|REPLAN|FAILED)\b`, optionally followed by
` — <reason>`. `CONTINUE` is the **only** signal that should keep a loop running; every
other signal halts and hands control back to a human. That makes "stop on anything
unexpected" the safe default.

Driving the loop is then a shell one-liner — no extra tooling needed. The agent command is
pluggable (`pi -p`, `claude -p`, etc.):

```bash
while out=$(pi -p "/flow next" 2>&1); echo "$out"; \
      echo "$out" | tail -1 | grep -q '^FLOW: CONTINUE'; do :; done
```

Add a `sleep` between iterations to be gentle on rate limits, and cap the iteration count
(e.g. with a `for` instead of `while`) if you want a hard ceiling on an unattended run.

## Failure modes to avoid

- **Lying about done** — marking `[x]` without a recorded passing verify.
- **Dead-end repetition** — retrying an approach a prior session already recorded as failed.
- **Scope drift** — quietly editing PLAN.md or working around the spec instead of flagging it.
- **Infinite retry** — not escalating to blocked after repeated failures.
- **Greedy runs** — doing several tasks in one session and defeating the throwaway model.
- **Editing PROCESS history** — it is append-only.
- **Overlapping iterations** — running two loops over the same project at once; on
  orientation, treat a stale `[~]` task with a passing verify as already done rather than
  redoing it.
