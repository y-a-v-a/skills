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

## Author

Vincent Bruijn · [vebruijn@gmail.com](mailto:vebruijn@gmail.com) · [Buy me a coffee ☕](https://buymeacoffee.com/y4v4)
