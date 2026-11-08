# Craft notes

These are the techniques behind the quality bar in SKILL.md. The concrete numbers come from one
worked project, a macOS app that grows shader-rendered mould on the screen (see `examples/`). The
principles apply to any repo.

## What makes a card look art-directed

1. **One real hero.** The project's own output is the subject: its rendering, its UI, its terminal output, its data.
   - Everything else supports it.
   - An imitation, such as CSS blobs standing in for a shader, or invented "code" when real code exists, always shows.
2. **A scene, not a pattern.**
   - Use a material, a place or an object with a believable scale. "The background" should be *something*: peel, silk, paper, stone, a desk, a desktop, a bench.
   - Regular grids, dots and stripes read as mathematical next to anything organic.
3. **One light.**
   - Pick a key-light direction (top-left is the safe default) and apply it everywhere: background normals, props, the hero's shading, cast shadows and text shadows.
   - Tint shadows with the scene's shadow colour, never neutral grey or black on a warm scene.
4. **Depth.**
   - Large-scale form shading (the surface curves away).
   - Vignette.
   - Depth of field: sharp at the hero, soft behind the text.
   - Atmospheric falloff.
   - Depth also calms the text zone and shrinks the PNG.
5. **A calm zone for type.** The text block sits over the quietest, lowest-contrast part of the background. The hero lives in the other half and tapers towards the text without entering it.
6. **Story details.** One or two small, true touches make it feel real:
   - a menu bar with the app's real icon;
   - a terminal prompt with the real command;
   - a browser tab with the real favicon;
   - a handwritten label on a prop;
   - keycaps for the real shortcut.

   Use one or two, not ten.
7. **Edges that end naturally.**
   - Organic elements should bleed off the canvas or taper out.
   - They should never stop at a straight line, a clip edge or a UI outline.

## Hero motif

**Find the real thing.** Look for:
- shaders (`*.metal`, `*.glsl`, `*.wgsl`, `*.frag`);
- canvas, SVG or WebGL code;
- plotting or generator functions;
- a snapshot or export flag;
- a demo page or Storybook;
- example output in the README or `docs/`.

**When it isn't directly callable, build a scratch harness** in `<W>`:
- symlink the repo's source folders into a scratch package and add a small `main` that reads a JSON spec and writes a **transparent PNG at 2×**;
- `examples/harness/` is a SwiftPM version, and `examples/README.md` gives its layout;
- for JS, import from the repo path in a page or a Node script;
- for Python, put the repo on `sys.path` in a script that lives in the scratchpad.

Build products stay in the scratchpad.

**Projects with no visual of their own** (CLI tools, libraries, services):
- **CLI.** Use real output. Run the tool when that's cheap and safe, otherwise take output from the README or docs.
  - Set it in a convincing terminal window: the real prompt, ANSI colours rendered as spans, a monospace font at 2×.
  - The terminal is the scene's prop; the background is the scene (desk, wallpaper, material).
- **Library.** Use a real, short snippet from the README or examples, syntax-highlighted in an editor window, together with what it produces: a rendered result, a chart, a diagram.
- **Data or infrastructure tools.** Draw a diagram from real structure (actual module names, actual pipeline stages) in a style the concept dictates: blueprint, field guide, subway map.
- **Webapps.** Screenshot the real UI headless, from a static `index.html` or an already-running dev server, at 2× (`SHOT_SCALE=2 shot.sh page.html ui.png 1280 800`). Place it in a browser frame or as a tilted device in the scene.
- **Logo.** Use it when there is one, but as a prop or mark, not as the whole hero.

**Generative motifs.**
- First render a contact sheet of seeds and parameters (timing, density, theme) with `sheet.py` to learn the vocabulary.
- Then **hand-place** elements for the composition: a list of positions, sizes, ages and kinds in the spec.
- A good arrangement:
  - large, mature elements anchored at the far edge and corners, bleeding off the canvas;
  - medium ones in the middle;
  - a trail of small, young ones tapering towards the text block, but not into it.
- Follow the real system's logic (big means old; offspring near parents), so it reads as grown, not sprinkled.

**Translucent hero over UI chrome.** A soft or translucent hero lets window outlines show through.
- Let the window bleed off the canvas, past the right and bottom edges, so no outline crosses the hero.
- Or put the hero under the chrome.

**Clipping to an object.** Clip with `clip-path` and put an overlay layer (glass, lid, frame) on top so the clip edge is hidden by the rim.

**Wrapping the hero onto a 3D object.**
- Pass its PNG to the background shader as a texture (`BG_TEX`) and sample it in the object's surface coordinates, e.g. arc-length longitude and latitude on a sphere (`examples/vanitas.metal`).
- Light it with the scene's light so it turns into shadow with the object.

**Matching the backdrop.** Choose the hero's colour theme to suit it. Try two themes against the background on a small sheet and keep the one that looks physically plausible there.

## Procedural backgrounds

**bgrender kernel contract** (also in `scripts/bgrender.swift`):
- The kernel is `float4 shade(float2 p, constant U &u, texture2d<float> t1)`.
- `p` is in points; render with scale 2 at 2560×1280.
- `u.view = (Wpt, Hpt, scale, seed)`; `u.a`, `u.b` and `u.c` are 12 free parameters from the command line.
- Return straight sRGB plus alpha.
- `common.metal` provides:
  - `hash12/22`;
  - value noise `vnoise`/`fbm`;
  - quintic gradient noise `gnoise`/`gfbm` (smoother, no grid creases);
  - `voronoi`;
  - `worley(p, jitter)`, returning F1, F2 and cell id;
  - smooth F1 `sworley(p, jitter, k)`, with no creases where cells meet;
  - `srgb2lin`/`lin2srgb`, `hexc(0xRRGGBB)`, `luma`, `overlayBlend`.
- If the project has its own noise functions, paste them in so background and hero share a texture vocabulary.

**WebGL2 instead of Metal.** Use this off macOS, or when a live page is simpler.
- A full-screen triangle with a fragment shader on a 2560×1280 canvas, shown at 1280×640 CSS px.
- The same `shade(p)` structure with the uniforms in a `uniform vec4 u[4]`.
- Supersample by averaging 4 offsets inside the shader.
- Port `common.metal` and the kernel line by line:
  - `float2/3/4` → `vec2/3/4`, `float2x2` → `mat2`;
  - `saturate(x)` → `clamp(x, 0.0, 1.0)`;
  - `atan2(y, x)` → `atan(y, x)`;
  - `select(a, b, c)` → `mix(a, b, c)` with a `bvec3` c;
  - `thread float &g` → `inout float g`, and drop `constant U &u` for uniforms;
  - `const float2 offs[4] = {…}` → `const vec2 offs[4] = vec2[](…)`;
  - `fract`, `mix`, `smoothstep`, `dot`, `length` and `exp` are the same.
- Shoot with `SHOT_WEBGL=1`.
- Without a GPU, Chrome falls back to SwiftShader. A heavy shader at 2560×1280 with 4× supersampling can then trip the GPU watchdog or `SHOT_TIMEOUT` and come out blank. Drop the supersampling (render at 2× only), or draw in horizontal strips with `gl.scissor`, one draw per strip.
- Highp floats in fragment shaders are usual on desktops, but keep coordinates in points (not pixels times big constants) to avoid precision artefacts in hashes.

**The general recipe for any material:**
1. **Height field.**
   - Domain-warp the input first: `q = p + float2(gfbm(p/60), gfbm(p/60+9.1)) * 3.5`. Unwarped noise looks synthetic.
   - Build structure from cells (`worley` pits or bumps with per-cell radius and depth variation), folds (a few sines) or fbm.
2. **Normals** by finite differences: `n = normalize(float3(-(hx-h)/e*bump, -(hy-h)/e*bump, 1))`, with `e` of about 0.35–0.8 pt.
3. **Albedo**, separate from height:
   - large-scale and subtle hue drift (fbm at 100–400 pt);
   - darker or more saturated inside pits or troughs.
4. **Lighting in linear space:**
   - diffuse with a little wrap;
   - for organic or translucent materials, a warm subsurface tint where the diffuse light falls off;
   - Blinn-Phong specular, with higher exponents for wax, glass or lacquer;
   - highlights gathered in a broad Gaussian "softbox" region rather than uniform glints.
5. **Large-scale form**: the surface curves away from the light. Then a vignette tinted towards the material's shadow colour.
6. **Depth of field.** Scale the bump amplitude and specular sharpness by a focus mask around the hero, with a minimum of about 0.15 behind the text.
7. **Output.** `lin2srgb`. Supersample 4×. Dither only smooth gradients.

**Material lessons (each came out wrong first):**
- **Pitted skin** (citrus peel, leather, porous stone).
  - A mid-scale albedo contrast came out blotchy, like camouflage. Keep albedo variation large-scale and subtle.
  - Pits shaded as bumps read as droplets. Pits need a dark interior and a lit far rim, i.e. negative height.
  - Hard Worley F1 cushions crease along cell borders like a mesh. Use `sworley`.
  - Choose the cell size from the real-world scale: if the hero is about 1–2 cm across, pores of about 1 mm.
- **Folds and abstract wallpaper** (silk, satin, OS-style backdrops).
  - fbm folds turned into lava marble. Use 2–3 large sines along slightly different diagonal directions, phase-warped by low-frequency `gnoise`.
  - A fold depth of about 70–110 pt.
  - Add satin sheen on the crests and saturated occlusion in the troughs.
  - Try 4–6 seeds and pick at full size.
- **Gel, glass and liquids.**
  - High-frequency cloudiness reads as smoke. Real gel is smooth, low-contrast and translucent: fbm at about 140 pt, 3 octaves, very weak.
  - Add a meniscus at the rims and the surface underneath seen through it.
  - Glass works as a separate overlay pass: rim glints and a curved softbox reflection on transparency.
- **Painted still life.**
  - Lighting too frontal kills chiaroscuro. A strongly side-on key such as `L = (-0.80, -0.55, 0.36)` gives a lit side and a shadow side that falls into the dark ground.
  - The terminator should glow (subsurface) instead of going grey.
  - Add a dark rim on the shadow side, a cast shadow and a contact shadow on the ledge, and reflected colour on the ledge.
  - Finish: craquelure from Worley `F2 - F1` edges at two scales, a warm varnish tint, a wall with anisotropic "dragged brush" fbm, and a heavy vignette.
- **Dark and luminous scenes.** Use a near-black ground with a faint radial lift behind the hero. Luminous strokes need a glow pass (next section).

## Canvas growth (strokes, agents, particles)

Use this for hyphae, roots, cracks, rivers, flow lines, circuits and constellations. See `examples/hyphae.js`.

- Use a seeded PRNG (mulberry32) so re-renders are stable.
- Tips grow from the hero's edges with a damped random turn (`da = da*0.9 + (rnd-0.5)*0.07`) and branch with a small probability, each branch thinner and shorter.
- **Cap the work:**
  - a density grid (stop a tip when its cell is crowded);
  - a global segment cap (about 120k–340k);
  - a generation cap.

  An uncapped first attempt produced millions of segments and hung Chrome.
- **Batch drawing.** Bucket segments by (width, alpha) into `Path2D`s and stroke each bucket once. Never stroke per segment.
- **Glow.** Render once into an offscreen canvas, then draw a blurred copy (`ctx.filter = 'blur(6px)'`) and a sharp copy with `'lighter'`. Don't blur per stroke.
- **Depth.** Add a second, sparser layer behind, CSS-blurred (`filter: blur(2.5px)`) at about 50 % opacity.
- **Resolution.** Size canvases at 2× and display them at 1280×640.
- **Defaults.** Read options with `??`, not `||`, so an explicit 0 works.

## Typography

- **Title.**
  - Fit the name to the text column; never let it wrap or crowd the hero.
  - Short names (≤ 7 letters): a sans at 150–185 px, weight 800, letter-spacing about −4 % (−6 px at 156 px), line-height about 0.9. Or a display serif at about 180 px, weight 600.
  - Longer names: scale down to keep the title within about 45 % of the canvas width in side layouts. Or switch to a centred layout with the hero framing it from the edges. Two lines only at a natural word break.
- **Tagline.** 40–46 px, weight 600–650, broken by hand into balanced lines with `<br>`, line-height about 1.1–1.15. Use italic for serif concepts.
- **Byline.** 28–30 px at 55–90 % opacity of the text colour. Small caps plus about 4 px tracking for serif concepts.
- **Keycaps or a command.**
  - Keycaps: one element per key, about 50–54 px square, styled to the scene: frosted on bright scenes, dark plastic on dark ones, outlined on painted ones.
  - A command: monospace at ≥ 28 px with the prompt dimmed.
- **Text shadows** are tinted and soft, e.g. `0 2px 16px rgba(110,30,0,.45)` on orange. Use black only on near-black scenes.
- **Labels on props** go along a curve with SVG `<textPath>`.

## Critique checklist

Answer each question explicitly every round.

- **Half size (640×320).** Does the background read as a material or scene, or as a pattern? Is the tagline easy to read? Is the title clearly the first read?
- **1:1 crops.** Look for:
  - creases along cell borders;
  - banding in gradients;
  - aliasing or shimmer;
  - blotches;
  - droplets where pits should be;
  - repetition or grid-aligned features;
  - seams where layers meet.
- **Light.** Does everything (background, props, hero, cast shadows, text shadows) agree on one direction? Probe both sides of round objects to be sure.
- **Hero edges.** Does the hero end by tapering or bleeding off? Do any outlines (windows, clips) cut through it?
- **Text zone.** Is it calm? Are there at least about 40 px between text and the nearest busy element? Does the safe area hold, is the byline present, and is all readable text ≥ 28 px?
- **Honesty.** Is the hero real output from this project (not invented code, fake UI or a lookalike)?
- **Distinctness.** Do the variants differ in concept, or are some just recolours?
- **The portfolio test.** Would this look at home on a designer's portfolio? If not, name the single thing that gives it away and fix that first.

## File size

PNG size is driven by high-frequency detail, so cut detail where nobody sees it:
- `BG_DITHER=0` for textured backgrounds; the texture already hides banding.
- Remove sub-pixel micro-noise that is invisible at 640×320.
- Strengthen depth of field behind the text.
- Together, these three took one card from 1,115,578 to 1,006,041 bytes.
- Then run `pngtool.py opt` (lossless, typically 2–7 %; 1,006,041 → 982,132 bytes on that card).
- Re-encoding with sips or ImageIO makes files **bigger**.
- Last resort: JPEG at quality 90–92 (`sips -s format jpeg -s formatOptions 92`). Check text edges at 1:1.

## Gotchas

- **Headless Chrome.**
  - It gives no progress output, so a hang just means too much synchronous JS. `shot.sh` kills it after `SHOT_TIMEOUT` seconds.
  - Check for stragglers with `pgrep -fl 'Chrome.*--headless'`.
  - `--virtual-time-budget` fast-forwards timers and font loading but not the CPU time of your scripts.
  - WebGL needs `SHOT_WEBGL=1`, because the default `--disable-gpu` turns it off.
- **Colour.** Chrome screenshots are sRGB, and bgrender writes sRGB. Convert Display P3 assets before using them.
- **Shader edits.** Edit shader parameters by exact string replacement (assert the old text exists) so a silent no-op edit doesn't send you comparing two identical renders.
