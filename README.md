# Skills Collection

A set of [pi](https://github.com/mariozechner/pi-coding-agent) / Claude Code skills I've built over the past months.

## Skills

### 🔧 [Codex Agent](./codex-agent)

Three skills that bring the [OpenAI Codex CLI](https://developers.openai.com/codex/cli) in as a second model, so Claude's work is not only checked by Claude:

- **`/codex`** — Hand a coding task (generation, refactoring, debugging) to `codex exec` with a written brief of the gathered context, then verify the result against `git diff`.
- **`/codex-review`** — Cross-model review of uncommitted changes, a diff against a base branch, or a commit. Findings are triaged by severity, and contested ones are reconciled with Codex.
- **`/codex-discuss`** — Work through a design or plan with Codex in a shared Markdown file until you agree or record an impasse, before any code is written.

The repo also includes `codex-validate`, a project-local skill that tests the three skills against a live Codex CLI. It is not linked globally.

### 🔍 [Google Programmable Search Engine](./gpse-skill)

- **`/google-search`** — Search the web through Google's Custom Search API, with date, site, exact-phrase, and exclusion filters plus pagination. Plain Node.js, no dependencies. Needs an API key and search engine ID (free tier: 100 queries/day).

### 🧐 [Stern Code Review](./stern-code-review)

- **`/stern-code-review`** — A blunt, senior-level review focused on correctness, data safety, security, and production risk. Ends in a verdict (`approve` / `approve with fixes` / `request changes` / `reject`), the tests that should exist, and the minimal acceptable fix.

### ✍️ [Attribution](./attribution)

- **`/attribution`** — Add a copyright-style author credit to `README.md` or wherever you say (e.g. `/attribution Vincent Bruijn, add name to html page footer`). Falls back to `git config user.name` and never silently replaces an existing credit.

### 🖼️ [HTML Export](./html)

- **`/html`** — Export the current state of the session (work done, findings, data) to a self-contained `index.html`. The agent picks what is worth showing, and it never overwrites a file (`index1.html`, `index2.html`, …).

### 🔥 [Grill Me](./grill-me)

- **`/grill-me`** — Get interviewed about a plan or design, one question at a time, each with a recommended answer, until you reach shared understanding. Questions the codebase can answer get answered from the codebase.

### 🧭 [Guide Me](./guide-me)

- **`/guide-me`** — Get walked through a manual task in a web dashboard (Vercel, AWS, GitHub settings, a DNS registrar), e.g. `/guide-me add RESEND_API_KEY to production on Vercel`. Settles scope and inputs first, checks the vendor's current docs, then gives one step at a time with a checkpoint. Re-plans when the screen doesn't match, warns before irreversible steps, and never asks for secrets in the chat.

### 📝 [Strunk](./strunk)

- **`/strunk`** — Rewrite prose (a file or inline text) to follow Strunk's *The Elements of Style*, and print only the result. Tightens and cuts while keeping meaning and claims. Code, URLs, and quotes pass through untouched.

### 📸 [Social Preview](./social-preview)

- **`/social-preview`** — Create a 1280×640 GitHub social preview PNG in the project's own style, screenshot it with headless Chrome, and iterate until you approve. See [explainer.html](./social-preview/explainer.html).

### 🚀 [Ambitious](./ambitious)

- **`/ambitious`** — Push a task toward its most ambitious worthwhile version, using Felix Rieseberg's [Altitude, Depth, and Range](https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/) lenses. Challenges your framing and the agent's own undershooting, rewrites the ask, then works at the level you pick.

### 📦 [Scpush](./scpush)

- **`/scpush`** — Minimal stage, commit, and push: stages only files that belong to the current work, commits in the style of the recent log, and reports the hash. The lightweight counterpart of `/gg`.

### 🚢 [gg](./gg)

- **`/gg`** — Stage, commit, and push with more safeguards. Reads untracked files first, refuses secrets and build output, stages explicit paths only, and shows what it staged. Optional message or paths as arguments. Never force-pushes or bypasses hooks.

### 🔐 [Scan Secrets](./scan-secrets)

- **`/scan-secrets`** — Find plaintext secrets (cloud keys, API tokens, passwords, private keys) in a repository. Uses a built-in Node.js scanner, plus [gitleaks](https://github.com/gitleaks/gitleaks) for gitignored files and the full git history when it is installed. Read-only, and every value in the output is masked. Fixture tests: `node --test scan-secrets/tests/scan-secrets.test.js`.

### ✉️ [Sendmail](./sendmail)

- **`/sendmail`** — Draft an email in Outlook on macOS, e.g. `/sendmail kim@example.com ask Kim for the Q3 numbers`. The text is used as the body verbatim or as an instruction to write one, and the subject is derived from it. Opens the draft for review; never sends.

### 🧹 [Purge](./purge)

- **`/flushcache`** — Purge Akamai edge cache for URLs, CP codes, or cache tags through the [Akamai CLI](https://github.com/akamai/cli). Invalidates on production by default (`--staging`, `--delete` to change that), checks credentials first, and asks before broad purges.

### ⚡ [JFDI](./jfdi)

- **`/jfdi`** — "Just do it": work autonomously to a high standard. Decides from verified facts instead of asking, finishes and verifies the whole job, and only stops for destructive, outward-facing, or security-related steps. Critical decisions go into an ADR or `DECISIONS.md`.

### 🔗 [Local URL](./local-url)

- **`/local-url`** — Give a locally served web app a bookmarkable address like `http://myapp.localhost:3000`, with no `/etc/hosts` entry and no sudo (`*.localhost` resolves to loopback per RFC 6761). Adds the name to the app's host allow-list, restarts it, and verifies with curl. Addresses that already worked, including a `tailscale serve` URL, keep working.

## Installing

Use `link-skill.sh` to symlink skills from this repo into `~/.claude/skills`:

```bash
./link-skill.sh --all      # link every skill
./link-skill.sh html       # link just one skill
```

Each skill is linked under its own name (e.g. `~/.claude/skills/html`), taken from the skill's `name:` frontmatter, so nested skills like `codex` and `google-search` land under the right name. Pass `--force` to replace an existing entry, and set `CLAUDE_SKILLS_DIR` to target a different directory.

## Author

Vincent Bruijn · [vebruijn@gmail.com](mailto:vebruijn@gmail.com) · [Buy me a coffee ☕](https://buymeacoffee.com/y4v4)
