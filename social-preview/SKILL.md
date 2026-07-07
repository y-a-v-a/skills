---
name: social-preview
description: Generate a GitHub social preview image (1280×640 PNG) for the current repo. Builds a throwaway social-preview.html styled after the project's own look (webapp theme colors, fonts, layout) with a minimal tagline from the README, screenshots it with headless Chrome, and iterates with the user until approved. Use when the user asks for a social preview, OG image, open-graph image, or repo card image.
license: MIT
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Social preview generator

Produce `social-preview.png` (exactly 1280×640) in the repo root, ready for manual
upload at GitHub → repo **Settings → General → Social preview**. There is no API
for that upload — always end by reminding the user to do it by hand.

## 1. Gather material

- Read `README.md` (and `package.json` description or similar) to learn what the
  project is. Distill a **very short tagline** — one line, roughly ≤ 60 characters.
  The project name comes from the repo/package name unless the README uses a
  nicer display name.
- Detect whether this is a webapp: look for `public/`, `index.html`, stylesheets,
  framework configs, templates. If so, read its CSS/HTML for **theme colors,
  fonts, and layout idioms** and echo that visual language in the card.
- Only render the real app for reference if it costs nothing: a static
  `index.html` you can open directly, or a dev server that is already running.
  Never install dependencies or start builds just for this skill.
- Not a webapp (CLI, library)? Fall back to a tasteful typographic card derived
  from the README's tone and any logo/badge assets in the repo.
- **Byline name**: ask the user which name to credit via an **AskUserQuestion**
  tool call. Offer `git config user.name` as the recommended first option, plus
  a "No byline" option; the user can type any other name via "Other". Ask once,
  here — never re-ask during the iteration loop.

## 2. Write the throwaway HTML

Write `social-preview.html` in the **session scratchpad directory** (not the repo).

Rules for the page:

- Canvas is exactly 1280×640: `html,body{margin:0}` and a single
  `1280×640` container with `overflow:hidden`. No scrollbars, no page margins.
- **Safe area**: keep the name, tagline, and anything essential at least **40pt
  from every edge** (GitHub's own template rule — edges get cropped on some
  surfaces). At CSS 96dpi that is ~53px on the 1280×640 canvas; use **≥ 54px**
  insets. Decorative elements may bleed to the edges.
- Default composition: project **name** large, the **tagline** under it, plus a
  **decorative motif in the project's visual language** (shapes, gradients,
  patterns echoing the app's theme). No GitHub logo, no URL, no clutter.
- **Attribution**: include a small, quiet byline with the name chosen in
  step 1 (omit the byline entirely if the user chose none). Small type, muted
  color, inside the safe area, never competing with the name/tagline.
- **Legibility at half size**: the 1280×640 canvas is typically displayed at
  ~640×320 CSS pixels (retina/2×), so every text size is effectively halved.
  Keep even the smallest text (byline, captions) at ≥ 28px on the 1280-wide
  canvas so it stays readable at 640×320.
- Fonts: prefer fonts shipped in the repo or the font stack its CSS declares
  (system fonts are fine). Only pull a webfont (e.g. Google Fonts `<link>`) when
  the project's identity hinges on it — headless Chrome will fetch it.

## 3. Screenshot with headless Chrome

Find a Chrome binary, first hit wins:

1. `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
2. `command -v google-chrome || command -v chromium || command -v chromium-browser`

Then:

```sh
"$CHROME" --headless --disable-gpu \
  --screenshot="<repo-root>/social-preview.png" \
  --window-size=1280,640 \
  --force-device-scale-factor=1 \
  --hide-scrollbars \
  --virtual-time-budget=5000 \
  "file:///<scratchpad>/social-preview.html"
```

(`--virtual-time-budget` gives webfonts time to load before capture.)

Verify the output: `sips -g pixelWidth -g pixelHeight social-preview.png` must
report 1280×640. If not, fix the HTML/flags — do not ship a wrong-size image.

## 4. Approval loop, then clean up

- Send the PNG to the user (SendUserFile) and ask for reactions.
- Iterate: tweak the HTML, re-run the same screenshot command, resend. Keep
  `social-preview.html` alive during this loop.
- Once the user approves: delete the throwaway HTML, leave `social-preview.png`
  in the repo root, and do **not** commit it unless asked.
- Close with the reminder: upload it manually at GitHub → **Settings → General →
  Social preview** (minimum 640×320, this file is the recommended 1280×640).
