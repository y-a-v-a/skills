---
name: guide-me
description: Walk the user step by step through a manual task in a web dashboard or backoffice (Vercel, the Claude Console, AWS, Google Cloud, GitHub settings, a DNS registrar, Stripe, an app store console) until they reach a stated destination, one step at a time, checking what they see after each step. Use when the user says "guide me", "walk me through", "where do I click", "how do I do X in the Vercel dashboard" (or any other service's), needs to do something by hand in a UI the agent cannot operate, or invokes /guide-me.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Guide Me

The user has to do something by hand in a web UI, and you are the navigator sitting next to them. They have the hands and the screen; you have the map. Get them to the destination one step at a time, confirm where they are after every step, and correct course the moment what they see stops matching what you expected.

## Invocation

- `/guide-me <destination>`: for example `/guide-me add the RESEND_API_KEY env var to production on Vercel`, or `/guide-me create a Claude API key with a spend limit for this project`.
- `/guide-me` alone: guide the manual step already under discussion. If there is none, ask for the destination.

## 1. Pin down the destination

Before giving the first step, be sure of three things. Find each one yourself first, and ask the user only for what you cannot find.

1. **The end state.** Describe it as something you can check: "`RESEND_API_KEY` exists for the Production environment of project `shop-web`, and a new deployment picks it up". "Configure Resend" is not specific enough.
2. **The context.** The service, the account, organization, team or workspace, the project, and the environment. Read the repository first: `vercel.json`, `.vercel/project.json`, `.env.example`, `package.json`, CI workflows, `README`, and the infrastructure config usually hold the project name, team, region and the exact variable or record names. Getting the scope wrong (personal account instead of team, staging instead of production) is the most common way a guided task fails, so settle it explicitly.
3. **The inputs.** List every value the user will have to type or choose, and collect them up front so step 6 does not stall: names, domains, regions, plan tier, which roles to grant. Values you can derive from the code, you derive. For secrets, say where each one comes from, but never ask the user to paste a secret into the chat.

If the task has prerequisites, check them before step 1: the role or permission it needs (owner, admin, billing), an existing resource, a paid plan, a verified domain. Being told "you need to be an Owner" on step 7 is a failure of preparation.

Ask about **decisions** one at a time, each with your recommended answer: a later decision often depends on an earlier one. Plain **inputs** that don't depend on each other (a project name, a region, a plan tier) can go together in one message, up to four, so collecting them doesn't cost a round trip each.

## 2. Check the current UI, not your memory

Dashboards change their navigation and labels often, and your memory of them is probably out of date.

- If you have web search or fetch available, look up the vendor's current documentation for this exact task before step 1. Prefer the vendor's own docs and changelog over blog posts. Note the date of what you find.
- Prefer deep links when the vendor documents a URL pattern (for example `https://vercel.com/<team>/<project>/settings/environment-variables`). A link the user can click beats three navigation steps. Fill in the team and project you established in section 1. If you are not sure the pattern is still current, also give the navigation path as a fallback.
- If a CLI or API can do the same job reliably (`vercel env add`, `gh`, `aws`, `gcloud`), mention it once in one line, because it may be faster and repeatable. Then guide through the UI anyway unless the user switches. They asked to be guided.
- If you cannot verify the current UI, say so once ("these labels are from memory and may have moved"), and lean harder on the checkpoints below.

## 3. Show the route, then give one step at a time

Start with a short route map so the user knows how long the trip is, then give step 1 only:

```
Route (about 5 steps): Team → Project shop-web → Settings → Environment Variables → add variable → redeploy.
```

Then give exactly one step per message, in this shape:

```
**Step 2 of ~5: open the project settings**

Do: click **Settings** in the tab bar at the top of the project.
You should now see: a left sidebar starting with General, with Environment Variables a few items down.

Reply "done", or tell me what you see instead.
```

Rules for steps:

- **One screen per step.** One step is the set of actions on a single page or dialog. Never combine two pages in one step.
- **Re-anchor after a detour.** The previous step's checkpoint already says where the user is, so a normal step starts with **Do:**. After a mismatch, a pause, or a correction, start the next step with **Where you should be:** (the screen and a landmark on it), so you both agree on the starting point again.
- **Use the UI's exact words**, in bold, as they appear on the button, tab or menu item. Name a landmark when a label is ambiguous ("the **Settings** in the project tab bar, not the one in your avatar menu").
- **Put values in code blocks** so they can be copied exactly: names, URLs, DNS records, JSON, and policy snippets. For a form, list every field you want changed and say to leave the rest at their defaults.
- **End every step with a checkpoint**: what they should see if it worked. The checkpoint is how you both find out that you have gone off course.
- **Warn before any step that is hard to undo or costs money:** deleting, rotating or revoking keys, transferring a domain, changing billing or the plan, removing members, production DNS, anything that sends email to users. Say what it does and how to undo it (or that it cannot be undone) before they click.
- **Secrets:** when the UI shows a secret once (a new API key, a client secret, a webhook signing secret), stop on that step. Tell the user to copy it now and say where it goes (a password manager, `.env.local`, `vercel env add`, the CI secrets page). Do not ask for it in the chat. If you need to confirm it was stored, ask a yes/no question, or ask for the variable *name* or the key's prefix, never the value.

## 4. Correct course

The user's reply decides the next step.

- **"Done" and it matches:** give the next step.
- **What they see differs:** stop moving forward. Work out which kind of mismatch it is:
  - **Wrong scope.** They are in the wrong team, account, project, region or environment. This is the most common cause. Have them check the team or project switcher.
  - **Missing permission.** The button is greyed out or missing, or a banner says so. Say which role is needed and who usually has it.
  - **The UI has changed.** Ask for the exact labels they see, or a screenshot (they can paste one straight into the chat). Re-plan from what they actually have, and re-check the docs if you can.
  - **A step was skipped or something failed silently.** Go back to the last checkpoint that matched.
- **An error message:** ask for the exact text. Explain what it means in one or two sentences and give the fix as the next step.
- **They get lost or want to stop:** tell them where they are on the route and what is already done, so they can pick up again later without redoing steps.

Never answer a mismatch by repeating the same instruction more forcefully. If two different attempts at the same step fail, say what you know, and propose a different route (another page, a CLI or API, or the vendor's support).

## 5. Arrive and verify

Reaching the last screen is not the same as arriving at the destination. When the user finishes the last step:

1. **Verify the end state independently** where you can: `curl` the endpoint, `dig` the record, run `vercel env ls` or `gh secret list`, make a minimal API call, or check that a fresh deployment picked up the change. If you cannot verify it yourself, give the user one concrete check to do.
2. **Recap briefly:** what changed, where (account / project / environment), any secret they stored and where it lives, and the direct URL of the page they ended on, so they can find it again.
3. **Mention follow-ups** the change implies: redeploy so new env vars take effect, wait for DNS propagation, update `.env.example` or the README, revoke the old key after rotating. Do the local, reversible ones yourself (such as updating `.env.example` or the docs) if they are clearly part of the task.
4. If this is a task they will repeat, offer once in one line to write the route as a short runbook in the repository.

## Anti-patterns

- Dumping all steps in one message. That is a doc, not a guide.
- Giving a step without a checkpoint.
- Assuming the scope (team, project, environment) instead of confirming it before step 1.
- Asking the user for something the repository already says.
- Asking for or echoing a secret value.
- Inventing menu labels with confidence. If you are unsure, say so and ask what they see.
- Clicking for them through browser automation without being asked. The user drives. Only take over if they explicitly ask you to.
- Declaring success at the last click without checking the end state.
