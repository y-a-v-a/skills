---
name: social-preview
description: "Generate a GitHub social preview image (1280×640 PNG, under 1 MB) for the current repo: several distinct concepts built around the project's real visual, critiqued at full and half size, and iterated with the user until one is approved. Use when the user asks for a social preview, OG image, open-graph image, or repo card image."
license: MIT
compatibility: "Needs headless Chrome or Chromium and python3. Procedural backgrounds use Metal via swiftc (macOS); without it, they are rendered as WebGL2 shaders in Chrome."
metadata:
  author: Vincent Bruijn
  author-url: https://vincentbruijn.nl
---

# Social preview generator

Produce `social-preview.png` (exactly 1280×640, under 1 MB) in the repo root, ready for manual
upload at GitHub → repo **Settings → General → Social preview**. There is no API for that upload,
so always end by reminding the user to do it by hand.

**The quality bar is a card that looks art-directed, not generated.** It shows a real scene with
material, light and depth, and the project's own visual is the hero. Flat CSS gradients, dot grids,
stripes and other evidently mathematical fills fall short of that bar. They read as filler next to
anything organic or real.

Reaching the bar takes real effort:
- building small render tools;
- several rounds of zoomed-in critique per variant;
- verifying with numbers instead of eyeballing.

Spend that effort by default. Go lighter only when the user asks for something quick.

Read `<skill>/craft.md` before building. It holds the techniques, recipes and failure modes behind
this bar.

## 0. Paths and setup

- `<skill>` is this skill's base directory, given when the skill loads.
- `<W>` is a working folder `social-preview/` inside the session scratchpad. Nothing is written into the repo until the user approves.
- Shell variables don't survive between Bash calls. Start every command with `S=<skill>; W=<W>;`, both written out as absolute paths, and use `$S` and `$W` after that. JSON specs get literal absolute paths.

```sh
S=<skill>; W=<W>; mkdir -p "$W"/bg "$W"/layers "$W"/cards "$W"/out "$W"/sheets "$W"/final
```

## 1. Gather material

- **Name and tagline.** Read `README.md` (plus `package.json` or similar).
  - Write a tagline of at most about 60 characters. It may be set over 2–3 hand-broken lines.
  - Add at most one iconic secondary hook if the project has one: a keyboard shortcut, a CLI verb, an install one-liner.
  - Take the display name from the README when it is nicer than the repo name.
- **The current image.** If a social preview or OG image already exists, look at it.
  - Find out how it was made (`git log -- social-preview.png`, scripts in the repo).
  - Note what works and what doesn't.
  - It goes first on the final overview sheet for comparison.
- **The visual language.** Collect theme colours, fonts, icons (app icon, menu-bar icon, favicon, logo SVGs) and UI chrome.
  - For webapps, read the CSS and templates.
  - For native apps, read asset catalogs and drawing code.
  - Reuse the real icons and the real shortcut. Don't invent stand-ins.
- **The hero.** Find what the card should show for real; see craft.md, *Hero motif*. This could be:
  - the project's own renderer (a shader, a canvas or SVG generator, a plotting function, a snapshot flag, a demo page);
  - for projects with no visual of their own, real CLI output, a real code snippet, or a diagram from real data.
- **Available tools.** Check for `swiftc` (Metal, macOS), Chrome or Chromium, and `python3`.

**Building and running:**
- Compiling the project, or a scratch harness around its sources, is fine with toolchains that are already installed.
- So is running a dev server or CLI whose dependencies are already installed.
- Keep build output in the scratchpad: symlink the repo's sources into a scratch package rather than building inside the repo.
- Never modify the repo.
- Installing anything needs the user's OK first. That includes `npm install`, `pip install` and `brew`, even inside the scratchpad.

## 2. Concepts

Unless the user names a number, develop **3 distinct concepts**. Five works well when the user
wants to choose broadly.

Distinct means a different scene, not a recolour. Good axes to pull from:

- a macro close-up of the material or object the project is about;
- its native habitat (an OS desktop, a terminal, an editor, a browser) with convincing chrome;
- the real-world origin of its name or metaphor (the lab, workshop, kitchen, workbench);
- an art-historical or print idiom (still life, blueprint, woodcut, risograph, field guide, technical manual), with typography to match;
- a scientific or technical view (microscopy, X-ray, exploded diagram, map, oscilloscope).

Before building, write a one-line brief per concept covering:
- the scene;
- the light direction;
- the palette;
- the typeface;
- where the text block sits;
- where the hero sits.

Post the briefs as a short status line and **carry on without waiting**; the user can redirect at
any time. A useful order:
1. Build every concept to a rough first pass.
2. Look at them side by side in a `sheet.py` sheet. Drop or rethink any that are weak or too similar.
3. Polish.

## 3. Build each variant as layers

Each variant is one HTML card, `<W>/cards/<n>-<concept>.html`, at 1280×640 CSS px. It stacks
full-canvas layers from back to front:

1. **Background.** A procedural image rendered at 2× (2560×1280) and shown with `background-size: 1280px 640px`.
2. **Scene and props.** Window chrome, a menu bar with the real icon, a terminal, a dish, a ledge. Use HTML/CSS, or bake them into the background shader.
3. **Hero.** Rendered by the project's own code on transparency at 2×, or real output, hand-placed for the composition.
4. **Overlays.** Glass, a lid, reflections, a glow layer.
5. **Type.**

Tools in `<skill>/scripts/`:

| Tool | What it does |
|---|---|
| `shot.sh page.html out.png [w h]` | Takes a headless Chrome screenshot with a hard timeout, checks the size, prints the bytes, warns at 1 MB, and writes `out-half.png` (what viewers actually see). Set `SHOT_WEBGL=1` for pages that use WebGL. |
| `bgrender.swift` + `common.metal` | Metal compute renderer for backgrounds (macOS). The kernel contract is in the file header. Build it once: `swiftc -O $S/scripts/bgrender.swift -o $W/bgrender && cp $S/scripts/common.metal $W/` |
| `pngtool.py info\|probe\|crop\|half\|opt` | Stdlib-only image tool: pixel probes and box means, crops with zoom, half-size previews, lossless PNG squeeze. Run it with `python3 -I`. |
| `sheet.py out.html IMG "caption" …` | Writes a captioned contact-sheet page and prints the `shot.sh` line to render it. |

**Without macOS or Metal:** write the background as a WebGL2 fragment shader inside a page and
shoot it with `SHOT_WEBGL=1`. Porting `common.metal` to GLSL is mechanical. Use a canvas for
strokes and particles. craft.md has notes for both.

`<skill>/examples/` holds the kernels, canvas script, harness and cards from one earlier project
(a macOS app that grows mould on the screen), with a README of exact commands. Read them for
technique. Don't reuse their look for a different project.

## 4. Card rules (hard)

- **Canvas.** Exactly 1280×640: `html,body{margin:0}` and one 1280×640 container with `overflow:hidden`. The final image is opaque.
- **Safe area.** Keep the name, tagline and everything essential at least **40px** from every edge, since some surfaces crop. Decoration may bleed to the edges, and usually should.
- **Composition.** The project **name** is large, the **tagline** sits under it, and the hero scene fills the rest. No GitHub logo, no URL, no clutter.
- **Byline.** Add a small, quiet byline with the author's full name, by default **Vincent Bruijn**.
  - If `git config user.name` gives a different full name, use that.
  - If the repo clearly belongs to someone else or an organisation, ask.
  - Use muted colour, keep it inside the safe area, and never let it compete with the name or tagline.
- **Legibility at half size.** The card is usually shown at about 640×320, so keep every text the viewer is meant to read at **≥ 28px**: name, tagline, hook, byline. Check every card's `-half.png`.
  - Incidental text that belongs to the scene may be smaller: a menu-bar clock, window chrome, a label on a prop. It should still look right, but nobody has to read it.
- **Fonts.**
  - Default to the system stack or fonts shipped in the repo.
  - A Google Font is fine when the concept calls for one, e.g. a display serif for a still life or a marker for a handwritten label.
  - Add `&display=block` to the font URL so the capture never shows the fallback font.
- **File.** PNG under **1 MB**, as GitHub requires ([docs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)). Whether that means 10⁶ or 2²⁰ bytes isn't stated, so stay at or below 990,000 bytes.

## 5. Critique loop, per variant

Every round has the same steps:
1. Render.
2. Look at three scales:
   - the full 1280×640;
   - `-half.png`;
   - 1:1 or enlarged crops of every textured or detailed area: `pngtool.py crop in.png x,y,w,h crop-3.png [zoom]`.
3. Name what is wrong in concrete words, e.g. "blotchy like camouflage", "pits read as droplets", "lava marble", "smoke, not gel", "lit evenly although the light is top-left".
4. Fix the cause.
5. Re-render.

Run craft.md's *Critique checklist* each round. Expect 3–6 rounds on a background and 2–3 on composition. Stop when nothing on the checklist fails, not when the image is merely acceptable.

Two traps when looking at your own output:
- **Stale previews.** Give every preview a new filename (`a-v3.png`, `crop-2.png`). The image viewer can show a cached picture for a reused path.
- **Unreliable tone.** Large downscaled previews can misrepresent tone. When something looks wrongly lit, too dark or too bright, check it with `pngtool.py probe` or a small crop before you change the shader.

## 6. Finish and present

1. Run `python3 -I $S/scripts/pngtool.py opt $W/out/<card>.png $W/final/social-preview-<n>-<concept>.png` for each variant.
2. Confirm 1280×640, opaque, at most 990,000 bytes (`pngtool.py info`). If a file is over, see craft.md, *File size*.
3. Build an overview with `sheet.py`: the current image first (if any), then the variants, each with a short caption ("2 · Terminal · real CLI output on a walnut desk").
4. Send the overview first, then each variant, with SendUserFile. If that tool isn't available, give the absolute paths and offer to `open` them.
5. Reply with:
   - a few sentences per variant (concept, what makes it work);
   - which fonts are webfonts;
   - each file's size;
   - the full absolute paths.

   Then ask which one to use, or what to mix or change.

## 7. Approval loop, then clean up

- Iterate on feedback: tweak the card or the shader, re-render, resend. Keep `<W>` alive throughout.
- Once the user approves:
  - copy the chosen file to `<repo>/social-preview.png`;
  - delete `<W>` (cards, layers, harness builds);
  - don't commit unless asked.
- Close with the reminder: upload it manually at GitHub → **Settings → General → Social preview** (minimum 640×320; this file is the recommended 1280×640).
