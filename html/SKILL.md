---
name: html
description: Use this skill when the user wants to export the current "situation" — the state of the conversation, work done, findings, data, or context — to a standalone HTML file they can open in a browser. The agent decides what is most valuable to capture and visualize. Invoked as /html, optionally with hints about what to focus on.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# HTML Export

Export the current situation to a self-contained HTML file and give the user
a clickable link to open it.

## Optional focus hints

Arguments provided: $ARGUMENTS

If arguments are present, treat them as a hint about what to emphasize or
what kind of document to produce (e.g. `/html focus on the architecture`,
`/html as a slide-style summary`). If there are no arguments, you decide
everything.

## Decide what to capture

This is the core of the skill: judge, from the current state of the
conversation and context, what would be genuinely valuable to put in front
of the user as an HTML page. You are not transcribing the chat — you are
producing a useful artifact. Consider, and pick whatever fits:

- A summary of the work done, decisions made, and their rationale.
- Findings, analysis, or research results.
- Code changes, file structures, or architecture (diagrams welcome).
- Data worth visualizing as tables or charts.
- Status / checklist of what is done vs. outstanding.
- Anything else that is the real "payload" of this session.

Prefer signal over completeness. If one thing clearly dominates the
session, build the page around that. Give the page a meaningful `<title>`
and top-level heading that reflect the actual situation, not "HTML Export".

## Build the file

- Produce a single, **self-contained** HTML5 document: all CSS inline in a
  `<style>` block, no external stylesheets, fonts, scripts, or CDN links,
  so it opens correctly offline with a single click.
- Make it clean and readable: a constrained content width (e.g.
  `max-width: 1024px; margin: auto`), comfortable line height, system font
  stack, sensible spacing, and styled tables/code blocks. Keep it tasteful,
  not flashy.
- Use a default font size of 16px and use `em` font sizes throughout, but
  do not use font sizes below `1em`.
- If a visualization genuinely helps (timeline, flow, simple chart), draw
  it with inline SVG or CSS rather than pulling in a library.
- Ensure the markup is valid and the document is complete
  (`<!DOCTYPE html>`, `<html>`, `<head>` with `<meta charset="utf-8">` and a
  viewport meta, `<body>`).

## Keep secrets out

An export outlives the session and gets shared. Never put a credential,
token, API key, password, private key, or connection string in the page,
even when it appears in the conversation: show the variable name or
`sk-…(redacted)` instead. Same for personal data the session touched but the
page doesn't need.

## Choose the location and filename (never overwrite)

Name the file after its content and date: `<slug>-<YYYY-MM-DD>.html`, where
`<slug>` is a short kebab-case version of the page title (e.g.
`skills-review-2026-11-08.html`). Never `index.html`: in a web project that
name collides with the real page.

Directory:

- Normally the current working directory.
- **Not** when the current directory is served or deployed as a site (it has
  an `index.html`, or is a `public/`, `static/`, `www/` or docs directory):
  a stray export there can be committed or published. Use `~/Downloads`
  instead, or the system temp directory if that doesn't exist, and say where
  it went.

If the name is taken, append `-2`, `-3`, … and pick the first that does not
exist. Never overwrite an existing file.

## Report the path

After writing the file, output its location as a `file://` URL with the
absolute path, on its own line, so the user can cmd-click / ctrl-click it
to open it in a browser. For example:

```
file:///home/user/project/skills-review-2026-11-08.html
```

Resolve the real absolute path (do not hardcode the example above). Briefly
mention what you chose to include and why.

Then make it one step to open:

- If the user may be on another device (a remote or web session) and a tool
  for sending files to the user is available, send the file with it.
- Otherwise offer once to open it (`open <file>` on macOS, `xdg-open` on
  Linux). Don't open a browser window without asking.
