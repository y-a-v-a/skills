---
name: sendmail
description: Prepare a draft email in Microsoft Outlook on macOS via osascript, from an email address plus either literal body text or an instruction for what the mail should say; the subject is derived from the body. Opens the draft in Outlook for review — it never sends. Use when the user invokes /sendmail, or asks to draft, write, or prepare an email or mail to someone in Outlook ("mail kim@example.com that…", "draft an email to…").
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Sendmail — prepare an Outlook draft

Compose an outgoing message in Microsoft Outlook (macOS) and open it for the
user to review. **Never send.**

## Invocation contract

Arguments provided: $ARGUMENTS

The arguments **must** contain at least one email address. Parse as follows:

- **Recipients** — every token matching an email address (`local@domain.tld`),
  in order of appearance. The first one or more addresses are `To:` recipients.
- **Remainder** — everything left after removing the addresses. This is the
  body spec.
- **No address found** → stop. Say only: `Need an email address.` Do not run
  osascript, do not guess a recipient.
- **No remainder** → ask the user once what the mail should say. Do not invent
  a body.

## Body spec: literal or assignment

Decide which of the two the remainder is:

- **Literal body** — a finished message the user wants sent verbatim
  (e.g. `'Today it is Thursday'`). Use it as-is; do not embellish, do not add
  paragraphs the user did not write.
- **Assignment** — an instruction about what to write
  (e.g. `'ask Kim for the Q3 numbers'`, `'summarize what we just fixed'`).
  Write the body yourself, drawing on the current conversation context.

When it is ambiguous, treat it as a literal body — under-writing is recoverable
in the draft, over-writing is not.

Assignment-written bodies:

- Short. A greeting, one to three short paragraphs, a sign-off.
- Only facts established in the conversation or given in the arguments. No
  invented numbers, dates, names, links, or commitments.
- Sign off with the user's first name from `git config user.name` if that
  returns a value; otherwise no sign-off.

## Subject

Derive it — the user does not pass one. Rules:

- Short noun phrase, ~3-8 words, specific to this mail's content. No trailing
  period, no `Re:`, no `[skill]`-style prefixes.
- If the literal body is one short line, the subject may restate it
  (`Today it is Thursday`).
- If the user's arguments explicitly name a subject (`subject: X`, or
  `--subject X`), use that verbatim instead.

## Build the draft

The AppleScript is fixed: `scripts/draft.applescript`, in the directory this
SKILL.md is in. You never edit it or splice values into it. The three values
travel as UTF-8 **files**, so there is no AppleScript string escaping and no
shell quoting to get wrong, and non-ASCII text (`é`, `—`, a Dutch name) passes
through as-is.

1. Make a fresh directory: `D="$(mktemp -d)"`.
2. Write three files with the **Write tool** (not `echo`, not a heredoc — both
   put the text through shell quoting):
   - `$D/subject.txt` — the subject, one line.
   - `$D/body.html` — the body as HTML. Build it in this order:
     1. Escape HTML-significant characters the user typed as text: `&` →
        `&amp;`, `<` → `&lt;`, `>` → `&gt;`. Skip this only when the user
        clearly wrote HTML markup themselves.
     2. Then turn each newline into `<br>` (a blank line becomes `<br><br>`).

     The order matters: escaping after step 2 would turn your own `<br>` into
     visible `&lt;br&gt;` text.
   - `$D/recipients.tsv` — one recipient per line: display name, a tab, the
     address. Leave the name empty (line starts with a tab) unless the user
     gave one (`"Kim" <kim@example.com>` → `Kim<TAB>kim@example.com`).
3. Run it:

   ```bash
   osascript "<skill-dir>/scripts/draft.applescript" "$D/subject.txt" "$D/body.html" "$D/recipients.tsv"
   ```

   `<skill-dir>` is the directory this SKILL.md is in.

The script ends with `open msg` and `activate`, and contains no `send`. Never
add one, not even when the arguments say "send it": preparing a reviewable
draft is the whole contract of this skill. If the user wants it sent, they
click Send.

## After running

Report in at most two lines: the recipients, and the subject used. Do not
reprint the body — it is on screen in Outlook.

If osascript errors, show the error verbatim and stop. Common causes: Outlook
not running (it launches on `activate`, but a cold start can time out — retry
once), or the terminal lacking Automation permission for Outlook in System
Settings → Privacy & Security → Automation.

## Guardrails

- One draft per invocation. No loops over a recipient list, no bcc-style
  fan-out.
- Do not attach files, add cc/bcc recipients, or set flags unless the user
  asked in the arguments.
- Content leaves the machine the moment the user clicks Send: keep secrets,
  credentials, and tokens out of the body, and say so instead of including
  them if the conversation context contains any.
