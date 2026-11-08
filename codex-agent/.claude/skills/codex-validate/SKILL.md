---
name: codex-validate
description: Validate the codex, codex-review, and codex-discuss skills end-to-end in a session where the Codex CLI is available — preflight, hook unit tests, and per-skill smoke tests that prove context actually reaches Codex — then self-improve by recording each run and tightening checks when something breaks. Use when codex is installed and you want to confirm the skills still work.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
argument-hint: "[all | codex | codex-review | codex-discuss | hooks | drift] [--fix]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        # Hooks run in the session's cwd, not the skill dir, so a relative path
        # never resolves. CLAUDE_PLUGIN_ROOT holds the skill dir in skill hooks;
        # the fallbacks are this project-local skill's own locations. If none
        # has the script, block codex commands only (fail closed without
        # locking up Bash). Tested as wired by scripts/check-hook-wiring.sh.
        - type: command
          command: 'for d in "$CLAUDE_PLUGIN_ROOT" "$CLAUDE_PROJECT_DIR/.claude/skills/codex-validate" "$CLAUDE_PROJECT_DIR/codex-agent/.claude/skills/codex-validate"; do [ -f "$d/scripts/validate-codex-command.sh" ] && exec bash "$d/scripts/validate-codex-command.sh"; done; grep -q codex && { echo "Blocked: codex validation hook script not found; check .claude/skills/codex-validate/scripts." >&2; exit 2; }; exit 0'
          onFailure: block
---

You validate that the sibling Codex skills actually work against a *live* Codex
CLI, and you keep this validation flow sharp over time. The hard part of these
skills isn't running a command — it's proving the **context handoff** works:
`codex exec` is stateless, so every smoke test below is designed to confirm that
what you put in the prompt actually reached Codex, not just that a command exited 0.

## Scope

`$ARGUMENTS`

- No target, or `all` → run preflight, hooks, drift, and all three skill smoke tests.
- `codex` | `codex-review` | `codex-discuss` | `hooks` | `drift` → run just that suite
  (`hooks` includes the §1a wiring check; `codex` includes §2b).
- `--fix` → when a check fails, apply the fix to the offending skill (not only
  this validator) instead of only reporting it. Without `--fix`, propose the fix
  and ask before editing a sibling skill.

The skills under test live at `skills/codex/SKILL.md`,
`skills/codex-review/SKILL.md`, `skills/codex-discuss/SKILL.md`.

## 0. Preflight (always run first)

```bash
command -v codex && codex --version    # must exist — this skill is pointless without it
codex login status                     # must be authenticated
command -v jq                          # the validation hook needs jq
```

If `codex` is missing, **stop** and tell the user — there is nothing to validate.
Do the rest of the work in a throwaway directory so the repo stays clean. Make
it a git repo so `--cd "$SANDBOX"` is a real working tree:

```bash
SANDBOX="$(mktemp -d)"
( cd "$SANDBOX" && git init -q && git config user.email v@v && git config user.name v )
echo "$SANDBOX"
```

**Codex CLI gotchas (keep the flags below — don't "simplify" them away):**
- The sandbox isn't a trusted dir, so every `codex exec` needs
  `--skip-git-repo-check` and `--cd "$SANDBOX"`, or it exits with "Not inside a
  trusted directory" and writes nothing — a fake context-drop. `--cd` also keeps
  Codex from ingesting the whole invoking repo.
- `codex exec` can take several minutes — give shell calls a 10+ min timeout.
- **Every `codex exec` and `codex review` needs stdin redirected**: the brief on stdin (`- < brief.md`),
  or `< /dev/null` when the prompt is an argument. With an argument prompt,
  codex also reads stdin until EOF; an inherited pipe that never closes (a
  background job, an agent's shell) hangs it forever at 0% CPU. The drift
  suite's STDIN check enforces this in the guidance.

## 1. Hooks suite — the safety gate must hold

Run the allow/block unit tests against **every** script copy (all four:
codex, codex-review, codex-discuss, and this skill's own copy):

```bash
for s in skills/codex skills/codex-review skills/codex-discuss .claude/skills/codex-validate; do
  echo "== $s =="
  echo '{"tool_input":{"command":"codex exec test"}}' | bash "$s/scripts/validate-codex-command.sh"; echo "allow exit=$?"
  for c in "codex exec --dangerously-bypass-approvals-and-sandbox test" \
           "codex exec -s danger-full-access test" \
           "codex exec -c sandbox_mode=danger-full-access test" \
           "codex exec --dangerously-bypass-hook-trust test"; do
    printf '{"tool_input":{"command":"%s"}}' "$c" | bash "$s/scripts/validate-codex-command.sh" 2>/dev/null; echo "block exit=$? ($c)"
  done
done
md5 -q skills/*/scripts/validate-codex-command.sh .claude/skills/codex-validate/scripts/validate-codex-command.sh | sort -u | wc -l   # must be 1
```

**Pass:** every danger spelling blocks (exit 2) everywhere; a plain `codex exec`
is *not* blocked by the script's own rules (with codex on PATH, the allow case
exits 0). **Fail:** any script lets a danger flag through, or the four scripts
diverge — they must stay identical.

### 1a. Wiring — the hook as Claude Code actually runs it

The unit tests above call the script by full path. Claude Code doesn't: it runs
the frontmatter `command:` string from the **session's cwd**, and a hook that
can't start (exit 127) is non-blocking, so a bad path fails *open*. That is
exactly how a relative `bash scripts/…` path shipped and blocked nothing.

```bash
bash .claude/skills/codex-validate/scripts/check-hook-wiring.sh; echo "exit=$?"
```

**Pass:** exit 0. For every skill, from a foreign cwd: danger blocked via
`CLAUDE_PLUGIN_ROOT` and via the fallback install path; with the script
missing, codex commands are blocked and other commands still pass; the hook
has `onFailure: block`. **Fail:** any line marked FAIL.

For a live check (recommended after changing the hook command), install a copy
of a skill as a project skill **under a unique name**: a same-named user-level
skill in `~/.claude/skills` wins over a project one, so you'd test the wrong copy.
Have it `echo` a danger command and confirm the session reports a block.

## 1b. Drift suite — copied guidance must not go stale

Identical hook md5 (section 1) proves one unsafe command is blocked; it says
nothing about whether the *instructions users copy* have drifted (e.g. a flag a
newer Codex CLI deprecated). Scan the user-facing guidance surfaces:

```bash
bash .claude/skills/codex-validate/scripts/check-cli-drift.sh; echo "exit=$?"
```

The script runs three checks:

- **FORBIDDEN** — hand-curated patterns known to be wrong (e.g. `--full-auto`).
- **EXISTS** — every `--flag` the guidance names is accepted by `codex`,
  `codex exec`, or `codex review`, generated from the installed CLI's `--help`.
- **POSITION / GLOBAL-ONLY** — flags on a `codex exec`/`codex review` command
  line must be accepted by that subcommand, and global-only flags (e.g.
  `--search`) must be placed before the subcommand or labelled global wherever
  they are mentioned. This caught `codex exec --search`, which the CLI rejects,
  in three guidance files.

**Pass:** exit 0. **Fail:** exit 1 with the offending `file:line`. With
`--fix`, correct it and re-run to green; otherwise report the drift. A guidance
file that has moved also fails: update `FILES` rather than letting it skip.

EXISTS and POSITION track every CLI release on their own. Add to the
`FORBIDDEN` list only for flags that still parse but are wrong to teach. The validator's own SKILL.md and `scripts/` are intentionally
not scanned: they name deprecated flags in order to test for them.

## 2. `codex` smoke test — does the brief reach Codex?

The point is to prove the gathered context drives the output, not just that a
file appeared. The brief goes in on stdin (`-`), exactly as the skills teach. Plant a unique sentinel in the brief's constraints and assert it
shows up in the result:

```bash
SENT="csv_parse_$RANDOM"     # unique marker the model can only know from the brief
cat > "$SANDBOX/brief.md" <<EOF
## Intent
A working CSV parser exists in parser.py.
## Constraints / conventions
- The function MUST be named exactly: $SENT
## Task
Create parser.py with that one function; parse a comma-separated line into a list.
EOF
codex exec --sandbox workspace-write --skip-git-repo-check --cd "$SANDBOX" --output-last-message "$SANDBOX/out.txt" - < "$SANDBOX/brief.md"
grep -q "$SENT" "$SANDBOX/parser.py" && echo "PASS: brief reached Codex" || echo "FAIL: sentinel missing — context was dropped"
```

**Pass:** `parser.py` exists and contains the sentinel name. **Fail (the
regression we care about):** the file is missing the sentinel → the brief didn't
reach Codex, i.e. the skill is back to throwing context away. Fix `skills/codex`.

### 2b. Does a model *following the skill* carry the context?

§2 writes the brief itself, so it proves the CLI contract, not the skill: a
SKILL.md that stopped telling the model to gather context would still pass. This
test puts the skill's own instructions in front of a model that has never seen
the task. (`/codex` has `disable-model-invocation: true`, so a subagent can't
invoke it; it gets the text instead.)

1. Plant the fact in a **file**, not the task, so it can only travel if the
   model reads the repo and writes it into the brief:
   ```bash
   SENT2="slugify_$RANDOM"
   printf '# Conventions\nEvery public helper in this repo is named exactly: %s\n' "$SENT2" > "$SANDBOX/CONVENTIONS.md"
   ( cd "$SANDBOX" && git add CONVENTIONS.md && git commit -qm conventions )
   ```
2. Spawn a fresh subagent (Agent tool, general-purpose) with: the full text of
   `skills/codex/SKILL.md`, the task *"Add a helper that turns a title into a
   URL slug, following this repo's conventions"* with `$ARGUMENTS` replaced by
   it, and the instruction to follow the skill exactly with `$SANDBOX` as the
   repo (`--cd "$SANDBOX" --skip-git-repo-check` on every `codex exec`). Do
   **not** mention CONVENTIONS.md or the sentinel.
3. Check: `grep -rq "$SENT2" "$SANDBOX" --include='*.py' --include='*.js' --include='*.ts'`.

**Pass:** the new helper carries the sentinel name, so the model gathered
context, wrote it into the brief, and Codex used it. **Fail:** fix the
"Gather context" / "Build a brief" steps in `skills/codex`, not this test.

## 3. `codex-review` smoke test — does the diff reach the reviewer?

Feed a diff with one obvious, specific defect and assert the review names it:

```bash
printf 'def charge(amount):\n    API_KEY = "sk-live-1234567890"\n    return bill(API_KEY, amount)\n' > "$SANDBOX/pay.py"
( cd "$SANDBOX" && git init -q && git add pay.py && git commit -qm seed && \
  printf 'def charge(amount):\n    API_KEY = "sk-live-1234567890"\n    return  bill(API_KEY, amount)\n' > pay.py && git diff > review.diff )
cat > "$SANDBOX/rbrief.md" <<EOF
## Intent
Billing helper; must not leak secrets.
## Instructions
For each finding give severity, category, file:line, problem, and a fix.
## Diff
\`\`\`diff
$(cat "$SANDBOX/review.diff")
\`\`\`
EOF
codex exec --sandbox read-only --skip-git-repo-check --cd "$SANDBOX" --output-last-message "$SANDBOX/rout.md" - < "$SANDBOX/rbrief.md"
grep -qiE 'api_key|secret|hardcoded' "$SANDBOX/rout.md" && echo "PASS: diff reached reviewer" || echo "FAIL: hardcoded secret not flagged — diff was dropped"
```

**Pass:** the review flags the hardcoded key (proving the diff content reached
Codex). **Fail:** generic output with no reference to the planted defect → the
diff was dropped (e.g. passed as a stray second positional arg). Fix `skills/codex-review`.

## 4. `codex-discuss` smoke test — structure and grounding

Run a short, capped discussion on a trivial topic and check the *shape* of the
artifact rather than the conclusion:

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "$SANDBOX" --output-last-message "$SANDBOX/turn.md" \
  "You are the challenger in a design discussion. Read nothing; the proposal is: \
   'store config in a single JSON file'. Raise one substantive objection and end \
   with a line: 'Signal: AGREE | AGREE_WITH_CAVEATS | DISAGREE | NEEDS_INFO'." < /dev/null
grep -qE '^Signal:' "$SANDBOX/turn.md" && echo "PASS: challenger emits a Signal" || echo "FAIL: no Signal line — convergence detection will break"
```

Also confirm by reading `skills/codex-discuss/SKILL.md` that the round-1 prompt
still grounds the challenger in repo context and the loop still defines
CONVERGED / IMPASSE. **Fail:** no `Signal:` line, or the convergence rules went
missing.

## 5. Cleanup & report

```bash
rm -rf "$SANDBOX"
```

Report a table: each suite → PASS / FAIL / SKIPPED, with the one-line reason for
any failure. Lead with failures. End with the path to this skill's validation
log (below) so the user can see the trail.

## Self-improvement (do this every run — it is part of the job)

This skill is the single source of truth for *how we validate*, and it is
expected to get better each time you run it. After reporting:

1. **On any failure, find the root cause and fix the right file.**
   - Skill regression (context dropped, Signal gone, hook weakened) → fix the
     offending sibling skill. With `--fix`, edit it now; otherwise propose the
     diff and ask first. Re-run that suite to confirm green.
   - A flaky check (e.g. an over-strict `grep`) → fix the check *here* so it
     stops crying wolf.

2. **When the Codex CLI surface changes** (a flag renamed, `codex review`
   behavior shifts, a new sandbox mode) and a check breaks because of it: update
   the smoke test here AND the affected skill/`docs/reference.md` to match, so
   the skills track reality.

3. **When you discover a sharper check** — a failure mode these tests would have
   missed — add it as a new step rather than leaving it in your head. The next
   run should catch what this run only caught by luck.

4. **Always append one entry to the log below**, even on a clean pass. Keep it to
   the newest ~10 entries; summarize and drop older ones. This is what makes the
   skill self-improving instead of self-forgetting: each run leaves the next run
   a better map of where these skills tend to break.

Never edit a sibling skill silently — every change you make to one must show up
as a log entry here describing what broke and what you changed.

The log is committed and read on other machines. Record what you tested and
found, not the state of this machine (where `~/.claude/skills` points, which
copies are installed): that is true only here and goes stale silently.

## Validation log

<!-- Newest first. Template:
### <date> — target: <all|codex|...>  result: <PASS|FAIL>
- Suites: hooks <P/F>, wiring <P/F>, drift <P/F>, codex <P/F>, codex 2b <P/F>, codex-review <P/F>, codex-discuss <P/F>
- Failure & root cause: <what broke, in which file>
- Fix applied: <file(s) changed, or "none">
- Check added/changed: <new or tightened check here, or "none">
-->

### 2026-11-08 — target: all (live)  result: PASS (after fixing a hang)
- Suites: hooks PASS, wiring PASS, drift PASS, codex PASS (19s), codex 2b PASS,
  codex-review PASS (10s), codex-discuss PASS (8s, after the fix). codex-cli 0.166.0.
- Failure & root cause: §4 hung for 30 min at 0% CPU. With the prompt as an
  argument, `codex exec` also reads stdin until EOF (to append it as a
  `<stdin>` block), and a background job's inherited stdin never closes.
  Measured: an open pipe held 25 s made a 5 s call take 30 s; `codex review`
  (no prompt) waits too (22 s vs 90 s with a 90 s pipe). The same applies to
  the skills: codex-discuss's challenger call and codex-review's three
  `codex review` commands could hang the same way in an agent shell. (The
  original codex and codex-review briefs via `"$(cat …)"` had it too; the
  move to `- < brief.md` fixed those.)
- Fix applied: `< /dev/null` on the argument-prompt `codex exec` in
  skills/codex-discuss and on the `codex review` lines in skills/codex-review,
  with the reason inline; §4 here likewise; §2/§3 now pass the brief on
  stdin, as the skills do.
- Check added/changed: drift STDIN rule: every fenced `codex exec`/`codex
  review` command needs a stdin redirect (placeholders like `<sha>` don't
  count; quoted payloads like the hook tests' JSON aren't commands). It flags
  all four hang risks in the previous commit. §0 gotchas document it.
- §2b detail: a fresh subagent given only skills/codex/SKILL.md and the task
  read CONVENTIONS.md unprompted, put the sentinel name in its brief's
  Constraints, and Codex used it (`slugify_<n>` in utils.py).

### 2026-11-08 — target: hooks, wiring, drift  result: PASS (after fixing the skills)
- Suites: hooks PASS, wiring PASS (new), drift PASS (extended). Live smoke
  tests (§2–§4, §2b) not run in this pass.
- Failure & root cause:
  1. **Hook never ran outside the skill dir.** All four frontmatters used
     `command: bash scripts/validate-codex-command.sh`. Hooks run in the
     session cwd, so from any user project bash exited 127, which Claude Code
     treats as non-blocking: `codex exec -s danger-full-access` went through.
     Confirmed in a live `claude -p` session. §1 called the script by full
     path, so it could not see this.
  2. **jq checked before the codex filter.** Skill hooks stay registered for
     the whole session, so without jq every Bash command was blocked.
  3. **Bypass spellings not caught:** `-s danger-full-access`,
     `-c sandbox_mode=danger-full-access`, `--dangerously-bypass-hook-trust`.
     The "Warning:" lines on exit 0 were never shown to Claude.
  4. **`codex exec --search` is rejected by codex 0.166** (`--search` is a
     global flag). Taught in skills/codex, skills/codex-discuss and
     docs/reference.md. The drift suite missed it: it only knew `--full-auto`.
- Fix applied: validate-codex-command.sh (all four copies, still identical);
  hook command in all four frontmatters (`$CLAUDE_PLUGIN_ROOT`, then the
  install path, fail closed for codex commands only, `onFailure: block`);
  `--search` guidance in the three files; briefs now go to `codex exec` on
  stdin (`-`) from a `mktemp -d` dir instead of `"$(cat /tmp/…)"`;
  codex-review's reconcile step now gets a self-contained brief.
- Check added/changed: §1 covers every danger spelling; new §1a
  `check-hook-wiring.sh` runs the frontmatter command from a foreign cwd (fails
  on the old hooks with 127 in all six scenarios); §1b drift now generates its
  EXISTS / POSITION / GLOBAL-ONLY checks from `--help` (catches the `--search`
  mistakes in the old files) and fails on a missing guidance file; new §2b
  tests the skill's instructions, not just the CLI.

### 2026-11-07 — target: all  result: PASS
- Suites: hooks PASS, drift PASS, codex PASS, codex-review PASS, codex-discuss PASS.
- Context: first run after merging this repo into the `skills` repo as the
  `codex-agent/` subtree. Hooks were unit-tested by full script path (all four
  md5-identical). (Correction, 2026-11-08: this entry also said
  `~/.claude/skills/codex*` "now link here". That was true on one machine only;
  see the note above the log.) codex-cli
  0.163.0 (last validated on 0.141.0): no flag changes broke the checks.
- Timings: codex 43s, codex-review 13s, codex-discuss 9s (run in parallel).
- Failure & root cause: none in the skills. §3 as written used GNU `sed -i`,
  which errors on macOS (BSD sed takes the expression as the backup suffix),
  so the review diff would be empty there.
- Fix applied: none to sibling skills.
- Check added/changed: §3 now rewrites `pay.py` with `printf` instead of
  `sed -i`, so it builds the same diff on macOS and Linux.

### 2026-06-26 — target: drift  result: PASS (closes codex-discuss objection O5)
- Suites: drift PASS.
- What & why: a `codex-discuss` run on the skill suite agreed (O5) that md5-identical
  hooks prove safety but not that copied *guidance* stays current. Added
  `scripts/check-cli-drift.sh` + the §1b drift suite to catch that.
- Acceptance test met: check FAILED on the stale `--full-auto` in
  skills/codex/SKILL.md (×3) and docs/reference.md (×1), then PASSED after
  replacing them with `--sandbox workspace-write`.
- Fix applied: skills/codex/SKILL.md, docs/reference.md (user-approved fix-forward);
  new drift script + §1b in this skill. The validator's own SKILL.md/scripts are
  excluded from the scan (they name deprecated flags to test for them).
- Check added: §1b drift suite. Extend its `FORBIDDEN` list on each CLI deprecation.

### 2026-06-25 — target: all  result: PASS (after fixing this validator)
- Suites: hooks PASS, codex PASS, codex-review PASS, codex-discuss PASS.
- Failure & root cause: codex smoke test (§2) failed first — **not** a skill
  regression. codex 0.141.0 deprecated `--full-auto` and now refuses to run
  outside a trusted dir, so with `--cd "$SANDBOX"` (a fresh mktemp) and no
  `--skip-git-repo-check` Codex exited with "Not inside a trusted directory" and
  wrote no file → looked like a context-drop. Re-running with a git-init'd
  sandbox + `--sandbox workspace-write --skip-git-repo-check` confirmed the
  sentinel reached Codex. Also caught the review smoke test (§3) hanging ~7 min
  because it ran without `--cd`, ingesting the whole invoking repo.
- Fix applied: this skill only — §0 git-inits the sandbox + documents the CLI
  surface; §2 uses `--sandbox workspace-write --skip-git-repo-check`; §3/§4 add
  `--cd "$SANDBOX" --skip-git-repo-check`. No sibling skill edited (`--fix` not
  passed).
- Check added/changed: added generic Codex CLI gotchas (trusted-dir +
  `--cd`, long timeouts) so these env failures aren't misread as context drops.
  Scoped §3/§4 to the sandbox.
- Open item: RESOLVED 2026-06-26 (see entry above) — `--full-auto` replaced with
  `--sandbox workspace-write` in skills/codex/SKILL.md + docs/reference.md, now
  guarded by the §1b drift suite.
