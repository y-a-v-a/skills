# Skills Collection

A set of [pi](https://github.com/mariozechner/pi-coding-agent) / Claude Code skills I've built over the past months.

## Skills

### 🔧 [Codex Agent](./codex-agent)

Two skills that delegate work to the [OpenAI Codex CLI](https://developers.openai.com/codex/cli):

- **`/codex`** — Delegate coding tasks (generation, refactoring, debugging) to Codex. Gathers context first, then runs `codex exec`, and reports a summary of what changed.
- **`/codex-review`** — Run code reviews via `codex review`. Supports reviewing uncommitted changes, diffs against a base branch, or specific commits.

### 🔍 [Google Programmable Search Engine](./gpse-skill)

- **`/google-search`** — Search the web using Google's Custom Search API. Supports date filtering, site-specific search, exact phrase matching, exclusions, and pagination. Zero external dependencies — plain Node.js with native `fetch`.

Requires a Google API key and Programmable Search Engine ID (free tier: 100 queries/day).

### 🧐 [Stern Code Review](./stern-code-review)

- **`/stern-code-review`** — A rigorous, senior-engineer-style code review focused on correctness, data safety, security, and operational reliability. Produces a structured verdict (`approve` / `approve with fixes` / `request changes` / `reject`) with serious issues, suspicious choices, expected tests, and a minimal acceptable fix.

Direct, practical, and unsentimental — assumes the code will run in production and edge cases matter.

### ✍️ [Attribution](./attribution)

- **`/attribution`** — Add author attribution to a project (e.g. `README.md` or a website footer). With no arguments it falls back to `git config user.name`; arguments can supply a name, email, and/or website, plus a free-form placement instruction (e.g. `/attribution Vincent Bruijn, add name to html page footer`). Defaults to a copyright-style credit with the current year and never silently overwrites an existing attribution.

### 🖼️ [HTML Export](./html)

- **`/html`** — Export the current "situation" — the state of the conversation, work done, findings, or data — to a self-contained `index.html` you can open in a browser. The agent decides what is most valuable to capture; the output is a single file with inline CSS and no external dependencies, and it never overwrites (falls back to `index1.html`, `index2.html`, …).

### 🔥 [Grill Me](./grill-me)

- **`/grill-me`** — Get interviewed relentlessly about a plan or design until you and the agent reach shared understanding. Walks down each branch of the decision tree one question at a time, resolving dependencies between decisions, and offers a recommended answer with every question. Questions answerable from the codebase are answered by exploring it instead of asking.

### 📝 [Strunk](./strunk)

- **`/strunk`** — Rewrite prose to conform to William Strunk Jr.'s *The Elements of Style* (1918). Takes a file path or inline text and prints only the rewritten text — no commentary. Applies all chapters (punctuation, composition, the misused-words list, spelling) at moderate aggressiveness: tightens, activates, and cuts while preserving meaning, paragraph order, and the author's claims. Code, URLs, and quoted speech pass through verbatim; dated 1918 rules (singular *they*, *shall*/*will*) are applied with judgment.

### 📸 [Social Preview](./social-preview)

- **`/social-preview`** — Generate a GitHub social preview image (1280×640 PNG) for the current repo. Builds a throwaway HTML card styled after the project's own look (theme colors, fonts, layout) with a short tagline from the README, screenshots it with headless Chrome, and iterates until you approve. Keeps essentials inside GitHub's 40pt safe area and verifies the exact output size. See [explainer.html](./social-preview/explainer.html) for a visual walkthrough.

### 🚀 [Ambitious](./ambitious)

- **`/ambitious`** — Challenge both you and the agent to aim higher on a task, prompt, or plan. Based on Felix Rieseberg's [How to be more ambitious: A tutorial for humans with models](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/). It names the small version you asked for, then pushes along three axes: **Altitude** (the goal beyond the goal), **Depth** (the raw material, real instruments, and outside judge a field-leading expert would use), and **Range** (nouns turned into verbs, plus a crew from other fields applying their actual methods rather than role-playing). It asks pointed questions about where your framing caps the outcome, audits its own answer for the ways models undershoot, and then works at whichever level you choose.

### 📦 [Scpush](./scpush)

- **`/scpush`** — A minimal stage, commit, and push. Stages only the files that belong to the current work, by name, and skips secrets, build output, and unrelated edits (and says what it skipped). It commits in the style of the recent log, pushes to the branch's upstream (setting one if missing), and reports the hash and branch in one line. It's the lightweight counterpart of `/gg`.

### 🚢 [gg](./gg)

- **`/gg`** — Stage, commit, and push in one pass, with more safeguards. It reads every untracked file before staging and refuses secrets, build output, editor cruft, and large or unmentioned binaries. It stages explicit paths only, shows what it staged, writes the message in the repository's own style, and reports the short SHA. `/gg <message>` sets the subject, and `/gg <path>…` limits what gets staged. It never force-pushes, never bypasses hooks, and stops when the repository is mid-merge, mid-rebase, or detached.

### ✉️ [Sendmail](./sendmail)

- **`/sendmail`** — Prepare a draft email in Microsoft Outlook on macOS through `osascript`, for example `/sendmail kim@example.com ask Kim for the Q3 numbers`. Email addresses in the arguments become recipients. The rest is either a literal body, used verbatim, or an instruction the agent writes the body from, using only facts from the conversation. The subject is derived from the body. The draft opens in Outlook for review; it never sends.

### 🧹 [Purge](./purge)

- **`/flushcache`** — Purge Akamai edge cache through the [Akamai CLI](https://github.com/akamai/cli). `/flushcache https://example.com` invalidates that URL on production; CP codes and cache tags are recognized from the arguments, and `--staging` and `--delete` switch network and operation. Verifies the CLI and `~/.edgerc` credentials before running (with setup instructions when they are missing), and asks first whenever the blast radius is wider than a handful of URLs.

### ⚡ [JFDI](./jfdi)

- **`/jfdi`** — "Just do it": work autonomously to a high standard. The agent decides based on verified facts instead of asking, finishes the whole job, proves it works with tests and builds, and reviews its own diff before reporting. It still stops at hard stops (destructive, outward-facing, security or compliance, real ambiguity), but only after finishing all safe work, and then asks once with a recommendation for each question. Critically important decisions (and only those) go into a decision record: the project's own ADR directory if it has one, otherwise `DECISIONS.md`.

## Installing

Use `link-skill.sh` to symlink skills from this repo into `~/.claude/skills`:

```bash
./link-skill.sh --all      # link every skill
./link-skill.sh html       # link just one skill
```

Each skill is linked under its own name (e.g. `~/.claude/skills/html`), taken from the skill's `name:` frontmatter, so nested skills like `codex` and `google-search` land under the right name. Pass `--force` to replace an existing entry, and set `CLAUDE_SKILLS_DIR` to target a different directory.

## Author

Vincent Bruijn · [vebruijn@gmail.com](mailto:vebruijn@gmail.com) · [Buy me a coffee ☕](https://buymeacoffee.com/y4v4)
