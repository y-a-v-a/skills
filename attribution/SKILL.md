---
name: attribution
description: Use this skill when the user wants to add author attribution to a project, for example to a README.md or as a footer on a website. Handles bare invocation (falls back to git config), explicit name/email/website arguments, and free-form placement instructions.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Attribution

Add an author attribution to the project.

## Arguments

Arguments provided: $ARGUMENTS

Parse the arguments as follows:

- **No arguments**: use the local git configuration for identity. Run
  `git config user.name` to get the author's name. If that prints nothing
  (no repository, or no name configured), ask the user for the name; never
  guess one from the OS account or a commit author. Do NOT include the email
  address from `git config user.email` — emails in public files attract spam
  scrapers and must only appear when the user explicitly provides one.
- **Identity arguments**: arguments may contain any combination of a name
  (e.g. `Vincent Bruijn`), an email address, and/or a website URL. Recognize
  email addresses by the `@`/domain shape and websites by `http(s)://` or a
  bare domain. Anything explicitly provided this way IS meant to be published,
  including an email address.
- **Instructive arguments**: arguments may also (or instead) contain a
  free-form instruction, e.g. `add name to html page footer` or
  `put it in CONTRIBUTORS.md`. Identity and instruction can be combined,
  typically separated by a comma:
  `/attribution Vincent Bruijn, add name to html page footer`.
  Use judgement to split identity from instruction.
- Any identity field not given as an argument and not needed can simply be
  omitted; only fall back to git config for the name when no name was given
  at all.

## Where to add the attribution

1. If the arguments contain a placement instruction, follow it. Use the
   project context to resolve vague targets: "the html page footer" means
   locate the site's main page/template (e.g. `index.html`, a layout or
   footer partial) and add the attribution inside its `<footer>` — create a
   minimal `<footer>` element at the end of `<body>` if none exists.
2. Without a placement instruction, add the attribution to `README.md` in
   the project root. Place it at the very end of the file as a final
   section or line, matching the document's existing style. Create
   `README.md` if it does not exist, after confirming with the user.

## Format

Default to a copyright-style credit. The shapes below use placeholders: fill
in only what you have, and drop the parts you don't (no website given means
no ` · <domain>` part at all).

- Markdown: `© <YEAR> <NAME> · [<domain>](<website URL>)`
- HTML: `<p>&copy; <YEAR> <NAME> &middot; <a href="<website URL>"><domain></a></p>`

Rules:

- **Year:** the current year for a new project. For an existing one, a range
  from the first commit's year (`git log --reverse --format=%ad --date=format:%Y | head -1`)
  to now, e.g. `2023–2026`; a single year when they are the same.
- **Match the LICENSE.** If the project has a `LICENSE` (or `LICENSE.md`,
  `COPYING`) with a copyright line, the credit must name the same holder. If
  it names someone else (an employer, a previous owner), don't silently add a
  conflicting `©`: point out the mismatch and ask which is right.
- Include only the identity fields that are available: name always; website
  and email only when provided. Link emails with `mailto:` in HTML, render
  the website as a link with the bare domain as link text.
- Adapt the markup to the target file type (Markdown, HTML, plain text),
  and match surrounding indentation and style.
- In Markdown, separate the attribution from preceding content with a
  horizontal rule (`---`) unless the file already ends with one.

## Existing attribution

Before writing, check whether the target file already contains an
attribution (a copyright line, "Created by", "Author", an existing footer
credit, etc.). If one exists, do NOT silently replace or duplicate it —
show the user what is there and ask whether to replace it, add alongside
it, or leave it untouched.
