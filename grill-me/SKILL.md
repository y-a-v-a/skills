---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree in rounds. Use when the user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
license: MIT (see LICENSE in this directory)
metadata:
  author: Matt Pocock
  source: https://github.com/mattpocock/skills/blob/7739eaed7f8f/skills/productivity/grilling/SKILL.md
  adapted-by: Vincent Bruijn
  adapted-by-url: https://vincentbruijn.nl
---

<!-- Adapted from Matt Pocock's `grilling` skill (MIT, see LICENSE here).
     Changes: merged into a single skill (upstream splits a user-only
     `grill-me` command from a model-invocable `grilling` skill), a fallback
     for agents without sub-agents, and an explicit hand-back at the end.
     The earlier one-question-at-a-time version is in this repo's history. -->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent with a fresh context window to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. Without sub-agents, look the fact up yourself before the round that needs it. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## Hand back

When the frontier is empty, close with a **decision list**: one line per settled decision (what was decided, and the reason in a few words), then any assumptions you are still carrying. This is the shared understanding in a form the user can check, paste into a plan, or hand to whoever builds it. Ask whether to save it to a file; don't write one unasked.
