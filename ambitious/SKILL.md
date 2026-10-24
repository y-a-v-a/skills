---
name: ambitious
description: Push a task, prompt, or plan toward its most ambitious worthwhile version, and hold both the user and Claude to it. Applies Felix Rieseberg's Altitude, Depth, and Range lenses — the goal beyond the goal, the raw material and instruments a field-leading expert would use, and the fields nobody thought to bring in — challenges the user's framing, audits Claude's own tendency to undershoot, then rewrites the ask and executes at the level the user picks. Use when the user says "be more ambitious", "aim higher", "think bigger", "what's the ambitious version of this", "we're not ambitious enough", or invokes /ambitious.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
  source: https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/
---

# Ambitious

Based on Felix Rieseberg's [How to be more ambitious: A tutorial for humans with models](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/) (October 2026).

Most requests ask for the small version of what the user actually wants, and models deliver exactly that. This skill breaks the loop in both directions: challenge the user's framing, and refuse to let yourself default to the literal, safe, self-graded answer.

## Input
- The argument is the task, prompt, or plan to make more ambitious: $ARGUMENTS. If it is a path to an existing file, read it.
- No argument → use the task under discussion in this conversation. Nothing in progress → ask once what they are working on.

Ambition comes in four types. **Speed** (the same work in less time) is the default; skip it. Work the other three: **Altitude**, **Depth**, and **Range**.

## 1. Name the small version
In one or two sentences, state what was literally asked and what you would have produced by default. Be honest. This is the baseline everything below must beat.

## 2. Altitude — the goal beyond the goal
Ask what the user wants to happen *after* this is done, and after that. Build a ladder of three rungs, each a concrete instruction to you, each one level higher:

1. **Understand.** Do the task with all the context you can reach, not just the template. *"Tell me what changed this quarter, why, and what we should do about it."*
2. **Decide.** Drive the decision the task exists to serve. *"Work out which three decisions are most urgent and start on directions, with arguments for and against."*
3. **Replace the ritual.** Serve the underlying purpose better than the current process does, prove it on history, and run it beside the old one. *"Design a better way than a quarterly deck to catch problems early and move money and people. Show from our history that it would have caught things sooner."*

Then ask what would let this run without the user handing you task after task. Felix went from "fix this crash" to "keep our apps crash-free", which first required fetching crash reports, mapping app versions to commits, and machines to reproduce and verify fixes on. List the access, data, and verification loops this task needs; mark which ones this session has and which are missing.

Altitude suits outcome-driven work; a good tell is that there will be meetings about it. It suits creative work less, so lean on Depth and Range there.

## 3. Depth — deeper, not bigger
Answer Felix's four questions:

> I want a deeper version of this task, not a bigger one. Before rewriting it: (1) say what a top professional in this field would do here that I'm not asking for; (2) name the rawest material they would start from instead of what has already been digested for me; (3) name the specific methods and tools they would use; (4) say what, other than you or me, would show the result is right. Then rewrite my prompt to ask for exactly that.

On (3): instruments, not vocabulary. An "expert persona" that still produces a markdown table has changed nothing. Use the database, the statistical model, the profiler, the fuzzer, the actual design tool.
On (4): the judge is outside you, ideally something you can run for immediate feedback: a test suite, a benchmark, held-out data, a type checker, a real user, or a fresh agent that never saw your reasoning.

Then add three more:
- **An unreasonable target.** Make it specific and hard: not "faster" but "200 ms instead of 10 s". Specific hard goals beat "do your best" (Locke & Latham). Never write "improve X".
- **An assumption to attack.** Name something the user believes and how you would try to reproduce it from raw data. *"We believe churn is an onboarding problem. Try to reproduce that from the raw data."*
- **New knowledge.** Once you are deep in the material, name the blind spot you would hunt for and how you would show it holds on data you have not seen.

## 4. Range — bring in the crew
- **Turn nouns into verbs** (Kelley & Littman, *The Art of Innovation*). Restate the artifact as the activity it serves. A quarterly review isn't "a deck"; it's "getting busy people to believe a story about cause and effect, and to decide under uncertainty, in 30 minutes." The verbs show which fields have something to offer.
- **Assemble the crew.** Imagine the result must be extraordinary or the world ends: who joins the heist? Pick 3–6 fields, including at least one adversary (short seller, forensic accountant, pen tester, hostile referee). For each, name the method they would apply.

Do not role-play. "Write like a short seller" changes the prose; "do what a short seller does to research a position" changes the result. When the crew is large and subagents are available, give each member its own brief and run them in parallel.

## 5. Challenge the user
Belief in what's possible limits people more than ability does; psychology calls this self-efficacy. Find where the user's framing caps the outcome and ask 1–3 pointed questions about it. Ask; don't lecture. Common caps:
- **Narrow identity.** "I'm a backend dev, not a designer." Michelangelo was a sculptor, not a painter, and he still painted the Sistine Chapel. Ask what they would try if the discipline were not a barrier.
- **Assumed impossibility.** George Dantzig solved two open statistics problems because he thought they were homework. Ask what would have to be true for this to be possible.
- **No precedent.** Bannister's four-minute mile stood alone for 46 days before someone matched it. Find an existence proof: someone who did a comparable thing. Search for one if you can.
- **Fear of failure.** Frame the ambitious rung as a bounded experiment with the small version as the fallback. Linux was announced as "just a hobby, won't be big and professional".

## 6. Challenge yourself
Before presenting anything, audit your answer for the ways models undershoot, and fix every hit:
- Did you default to the literal ask, or to the version that is easiest to satisfy?
- Did you swap vocabulary but keep the same method?
- Are you planning to grade your own work? Name the outside judge.
- Are you starting from digested material when the raw material is reachable?
- Did you call something impossible or out of scope without trying it?
- Is any target vague ("better", "robust", "scalable")? Make it a number.
- Are you hedging where you could be attempting?

## Output: the ambition brief
Keep each item to a line or two:

- **Small version** — one line.
- **Altitude** — the three rungs; what is needed to run without the user (have / missing).
- **Depth** — the four answers; the unreasonable target; the assumption to attack; the blind spot to hunt.
- **Range** — the verb sentence; the crew as `field → method`, one per line.
- **Rewritten prompt** — the ambitious ask in a fenced block, ready to run: specific hard targets, raw inputs, real instruments, an outside judge, and the crew.
- **Challenge** — your 1–3 questions.

End by asking which level to go for: the small version, rung 1, 2, or 3, or the full rewritten prompt.

## Executing
Once the user picks a level, work at that level:
- **Hold the bar.** Use the instruments and the judge you named. When a target looks out of reach, treat it as reasonable and keep going. If you must concede, report what you hit, the number you reached, and what would close the gap. Never fall back to the small version without saying so.
- **Get real access.** Ambition needs a computer that can install software and reach the data. If access is missing, ask for it; don't simulate it.
- **Ambition is not license.** Still confirm before destructive, irreversible, or outward-facing actions: deleting, publishing, sending, spending money.

## Small tasks
Even a small task usually has a rung above it: fix this typo → spell-check prose in CI; fix this crash → keep the app crash-free. When the task is genuinely small, skip the full brief: name the rung above in one line and ask whether to take it or just do the small version. Manufactured ambition is noise.
