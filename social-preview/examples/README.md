# Examples: Mould (October 2026)

These are the five social preview variants made for the Mould macOS app, which grows the app's own
shader-rendered mould over the screen. Use them as technique references; don't reuse their look for
another project.

| File | What it shows |
|---|---|
| `rind.metal` | Macro citrus peel. Domain-warped Worley pits in smooth cushions (`sworley`), waxy softbox specular, large-scale form shading, a depth-of-field mask (`u.a.yzw` = focus uv, minimum bump). |
| `silk.metal` | OS-style abstract wallpaper. Three phase-warped sines instead of fbm, satin sheen, trough occlusion. Try several seeds. |
| `agar.metal` | Petri dish on a dark bench, rendered in two passes from one kernel: `u.a.w = 0` for the plate and agar, `1` for a transparent glass-lid overlay placed above the motif layer. |
| `vanitas.metal` | Still life with a sphere wrapping the motif texture (`BG_TEX`) in arc-length coordinates. Side key light, subsurface terminator, ledge with cast and contact shadows, craquelure and varnish. |
| `hyphae.js` | Luminous branching growth on canvas: seeded, density and segment caps, `Path2D` batching, one-pass glow, brush-shaped heads at some tips. |
| `card-*.html`, `base.css` | Layer stacks and type for three of the cards: menu bar, bleeding window, keycaps, SVG `textPath` label, Google Fonts with `display=block`. |
| `harness/` | SwiftPM scratch harness that renders hand-placed colonies with the app's own shader to a transparent 2× PNG. `spec-rind.json` is the hand placement used for the rind card. |

**Layout the cards expect** (the `<W>` layout from SKILL.md):
- the card, `base.css` and `hyphae.js` in `<W>/cards/`;
- backgrounds in `<W>/bg/`;
- motif layers in `<W>/layers/`.

**Commands that reproduce the delivered backgrounds.** Run them in `<W>` after building `bgrender`
there (SKILL.md § 3):

```sh
S=<skill>; W=<W>; cd "$W"
BG_DITHER=0 ./bgrender $S/examples/rind.metal bg/rind.png 2560 1280 2 1  0.5 0.78 0.62 0.15  0.52 0.06 0.45 0.9
./bgrender $S/examples/silk.metal bg/silk-2.png 2560 1280 2 2  110             # seed 2 picked from 6; fold depth 110 pt
./bgrender $S/examples/agar.metal bg/agar.png     2560 1280 2 1  925 330 392 0  # dish centre x y, radius, mode
./bgrender $S/examples/agar.metal bg/agar-lid.png 2560 1280 2 1  925 330 392 1
BG_TEX=layers/sphere-map.png ./bgrender $S/examples/vanitas.metal bg/vanitas.png 2560 1280 2 1  915 296 228 446  552 800 10 120
#   sphere x, y, radius, ledge back y | ledge front y, motif map size (pt), map offset y, map offset x
```

**Harness layout** (Swift; the same idea works for npm, Python or Rust):

```
<W>/harness/Package.swift            from examples/harness/Package.swift
<W>/harness/Sources/comp/main.swift  from examples/harness/main.swift
<W>/harness/Sources/MouldCore   ->   <repo>/Sources/MouldCore     (symlink)
<W>/harness/Sources/MouldRender ->   <repo>/Sources/MouldRender   (symlink)
```

- Copy these settings from the repo's own `Package.swift` for the symlinked targets:
  - `swift-tools-version`;
  - `platforms`;
  - `resources`;
  - `swiftSettings`, e.g. the language mode.
- Build with `swift build -c release --package-path <W>/harness` so `.build/` stays in the scratchpad.
- Run it as `<W>/harness/.build/release/comp spec.json`. Replace `<W>` in the spec's `out` with the absolute path first; JSON doesn't expand variables.
