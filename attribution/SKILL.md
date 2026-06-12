---
name: attribution
description: Use this skill when the user wants to add author attribution to a project, for example to a README.md or as a footer on a website. Handles bare invocation (falls back to git config), explicit name/email/website arguments, and free-form placement instructions.
---

# Attribution

Add an author attribution to the project.

## Arguments

Arguments provided: $ARGUMENTS

Parse the arguments as follows:

- **No arguments**: use the local git configuration for identity. Run
  `git config user.name` to get the author's name. Do NOT include the email
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

Default to a copyright-style credit including the current year:

- Markdown: `© 2026 Vincent Bruijn · [vincentbruijn.nl](https://www.vincentbruijn.nl)`
- HTML: `<p>&copy; 2026 Vincent Bruijn &middot; <a href="https://www.vincentbruijn.nl">vincentbruijn.nl</a></p>`

Rules:

- Use the actual current year, not a hardcoded one.
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
