---
name: sendmail
description: Prepare a draft email in Microsoft Outlook on macOS via osascript. Invoked as /sendmail with an email address followed by either literal body text or an assignment describing what the mail should say; the subject is derived from the body. Opens the draft in Outlook for review — it never sends.
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

## Escaping — do this before building the script

`content` is HTML, and both `subject` and `content` are AppleScript string
literals. In that order, per field:

1. `\` → `\\`
2. `"` → `\"`
3. In `content` only: each newline → `<br>`, and a blank line → `<br><br>`.
   A literal newline inside an AppleScript string is a syntax error.
4. Non-ASCII characters → HTML entities in `content` (`é` → `&eacute;`,
   `—` → `&mdash;`). Keep `subject` plain ASCII; transliterate if needed.
5. In `content` only: escape HTML-significant characters the user typed as
   text — `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;` — unless the user clearly
   intended HTML markup.

## Script

Write the AppleScript to a file in the session scratchpad directory (fall back
to `"$TMPDIR"`) and run it with `osascript`. Do not pipe a heredoc through the
shell — the shell adds a second layer of quoting to get wrong.

```bash
cat > "$SCRATCH/sendmail.scpt" <<'EOF'
tell application "Microsoft Outlook"
  set msg to make new outgoing message with properties {subject:"SUBJECT", content:"BODY_HTML"}
  tell msg
    make new recipient at end of to recipients ¬
      with properties {email address:{name:"ADDRESS", address:"ADDRESS"}}
  end tell
  open msg
  activate
end tell
EOF
osascript "$SCRATCH/sendmail.scpt"
```

- Replace `SUBJECT`, `BODY_HTML`, `ADDRESS` with the escaped values. Set
  `name` to the address itself unless the user supplied a display name
  (`"Kim" <kim@example.com>` → `name:"Kim"`).
- Multiple recipients: repeat the whole `make new recipient ... end` block,
  one per address, inside the same `tell msg`.
- Keep `open msg` and `activate`. **Never** emit `send msg` — not even when
  the arguments say "send it". Preparing a reviewable draft is the whole
  contract of this skill; if the user wants it sent, they click Send.
- `¬` is the AppleScript line-continuation character. Keep it, or put the
  `with properties` clause on one line.

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
