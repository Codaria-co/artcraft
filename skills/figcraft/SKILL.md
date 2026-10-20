---
name: figcraft
description: Design UI screens and mockups with FigCraft (open-source Figma, `figcraft-cli`) - visual design files, not code. For app and web screens, wireframes, landing page designs, dashboards, App Store screenshots, components and variants, auto layout, design tokens as variables with light/dark modes; open, inspect and export .figcraft, .fig or Figma REST API JSON to PNG/SVG/PDF per frame. Not for writing frontend code (React, CSS), logos (vectorcraft) or print layouts (designcraft). Trigger on 'mockup', 'wireframe', 'UI design', 'diseno visual', 'Figma file', 'export frames', even if FigCraft isn't named.
---

# FigCraft (`figcraft-cli`)

FigCraft is a Figma-like design tool from the ArtCraft "Crafting Apps" suite. Its native file is
`.figcraft`; it also reads FigCraft `.json`, the Figma REST API file JSON (`GET /v1/files/:key`
saved to a `.json`), `.fig` (best effort), `.svg` (as an editable frame) and raster images (as an
image layer). It writes `.figcraft`, `.json`, `.svg`, `.png/.jpg/.webp`, `.pdf` and `.fig`
(experimental). Everything in the app's command registry (569 commands: `node.*`, `layout.*`,
`component.*`, `variable.*`, …) is scriptable headless through `figcraft-cli run`.

## Before you start
- Check `command -v figcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install figcraft`; Windows: `craft-clis.ps1`).
- Headless by default: `info`, `run`, `render`, `export` and `convert` need no window, and the
  desktop app is optional. The app only matters for `figcraft-cli mcp --attach PORT`, which drives
  an app started with `figcraft --control PORT`; skip it unless the user wants to watch edits live.

## When to use / when not
- Use for screens, components, design systems, tokens, UI exports and Figma-file conversion.
- Multi-page print layout (brochures, books): `designcraft`. Illustration and logo vectors:
  `vectorcraft`. Photo retouching: `photocraft`. Slide decks: `deckcraft`. Reading or editing
  existing PDFs: `pdfcraft`.
- New images from a prompt (hero photos, illustrations): hand off to the `genai` skill, then place
  the file with `image.place {path, x, y, parent}`.

## Core workflows

Build a screen from a script and save it (one undo step, all-or-nothing):
```sh
figcraft-cli run screen.json --out screen.figcraft
```
A script is a JSON array of `{"command": id, "params": {...}}` (or `{"commands": [...]}`, or JSON
lines with `//` comments). `{"$step": n}` in params is the `id` returned by step n, so later steps
can target layers earlier steps made. Minimal screen with auto layout and a component:
```json
[
  {"command": "frame.create", "params": {"preset": "iPhone 16", "x": 0, "y": 0, "name": "Home"}},
  {"command": "node.set", "params": {"id": {"$step": 0}, "fill": "#F5F5F7", "layout": "vertical", "padding": 24, "gap": 16}},
  {"command": "text.create", "params": {"text": "Welcome back", "x": 0, "y": 0, "parent": {"$step": 0}, "props": {"fontSize": 32, "fontStyle": "Bold"}}},
  {"command": "node.create", "params": {"type": "component", "name": "Button", "x": 500, "y": 0, "width": 200, "height": 48,
    "props": {"fill": "#0A84FF", "cornerRadius": 12, "layout": "horizontal", "padding": [12,24,12,24], "mainAlign": "center", "crossAlign": "center", "sizingH": "hug"}}},
  {"command": "text.create", "params": {"text": "Continue", "x": 0, "y": 0, "parent": {"$step": 3}, "props": {"fontSize": 17, "fills": ["#FFFFFF"]}}},
  {"command": "instance.create", "params": {"component": {"$step": 3}, "parent": {"$step": 0}}}
]
```
`props` on any create command takes the `node.set` keys (fill, cornerRadius, layout, gap, padding,
mainAlign, crossAlign, sizingH/sizingV fixed|hug|fill, fontSize, fontFamily, fontStyle, …).

Inspect a file (pages, top-level frame ids and sizes, missing fonts):
```sh
figcraft-cli info screen.figcraft          # add --json for machines
```

Edit an existing file: run a script against it with `--in`; write to a new `--out`.
```sh
figcraft-cli run edit.jsonl --in screen.figcraft --out screen-v2.figcraft
```
To find ids first, run `node.get {id}` (a frame returns its direct children with ids; nested
frames show `childCount`, so call `node.get` again on them) or `select.byName {query}`.

Look at the result: render the whole page, or export one frame.
```sh
figcraft-cli render screen.figcraft -o page.png
figcraft-cli export screen.figcraft -o home.png --node Home --scale 2
```

Export every top-level frame (one file per frame, named after it) in any format:
```sh
figcraft-cli export screen.figcraft -o exports/ --scale 2            # PNG per frame
figcraft-cli export screen.figcraft -o pdfs/ --format pdf             # PDF per frame
figcraft-cli export screen.figcraft -o hero.svg --node Home           # one SVG
figcraft-cli export screen.figcraft -o screens.pdf                    # all frames, one page each
figcraft-cli export screen.figcraft -o print.pdf --node Home --bleed 3mm --crop-marks --bleed-marks --cmyk
```

Convert by extension (Figma REST JSON, .fig, SVG, images in; .figcraft/.json/.svg/.png/.pdf/.fig out):
```sh
figcraft-cli convert figma-file.json design.figcraft
figcraft-cli convert design.figcraft handoff.fig
```

Start from a starter template (`template.list`: mobile-app, landing-page, dashboard, …):
```sh
echo '[{"command":"file.newFromTemplate","params":{"template":"dashboard"}}]' > start.json
figcraft-cli run start.json --out dashboard.figcraft
```

Reproducible renders (CI, golden images): add `--no-system-fonts` (or `FIGCRAFT_NO_SYSTEM_FONTS=1`)
so only FigCraft's built-in fonts are used (Inter, Roboto, Poppins, Montserrat, Lato, Open Sans,
Merriweather, Playfair Display, Source Sans 3, Liberation, Noto Sans Arabic, …).

## Finding the right command
- `figcraft-cli commands --filter TEXT` lists matching commands with their param spec; `*` marks
  undoable ones. `--json` gives `{id, label, params, undoable}` for parsing. The filter matches ids,
  labels and param text, so `--filter node.set` also returns `node.create`.
- Read the spec literally: `x?` is optional, `a|b` are the allowed values, `(…)` explains units.
  `node.set`'s spec is the full property list for `props`; an unknown key fails with the whole list.
- Discovery commands worth running inside a script: `frame.presets`, `template.list`, `text.fonts`,
  `component.list`, `component.properties`, `style.list`, `variable.list`, `page.list`.
- Offline: grep `references/commands.md` (generated catalog, params clipped; ask the CLI for full
  text). Task-shaped examples: `references/recipes.md`.

## Safe defaults
- Write to a new `--out`/`-o` path. Outputs are overwritten silently, including `--in X --out X`.
- Quote paths and layer names (`--node "Hero card"`).
- When an agent or untrusted script drives the CLI, confine it:
  `--automation-read-root in --automation-write-root out`. Roots must exist; the script file for
  `run` must also sit inside a root. `mcp` takes the same flags.
- Never run `plugin publish` or `mcp --attach` unless the user asks; both talk to a server or app.

## Gotchas
- Ids are integers assigned in order: the first page is 1, the first layer 2. Prefer `{"$step": n}`
  over hard-coded ids; ids differ after a `.fig` round trip (page becomes 2, frame 3).
- Variable ids are strings (`VariableID:1`); reference variables and collections by name instead.
- `export -o dir/` writes one file per top-level frame **of the first page only**, components
  included; for multi-page files run `figcraft-cli info` and export each page with `--page NAME`.
  Use `--node` for one frame. A frame stroke drawn outside adds its width to the PNG (a 1440×960
  frame with a 1 px outside stroke exports 2884×1924 at 2x).
  `--node` takes a name, an id (`7`) or `0:7`; a bad node or `--page` exits 1 and names the pages.
- A component made at the top level is also a top-level frame, so it shows up in `render` and in
  directory exports. Put components on a separate page if exports must be screens only: `page.add`
  makes the new page current, so later creates without `parent` land there (recipe 4).
- `render` crops to the page's content bounds, so its size is not a frame size.
- A failing step prints `"ok":false,"rolledBack":true`, rolls the whole script back and skips
  `--out` (exit 1). Bad CLI arguments print usage and exit 2; other failures exit 1.
- Result JSON goes to stdout; `wrote <file>` and errors go to stderr.
- Fonts not installed render in a fallback and `info` lists them as `missing font` lines (on stdout;
  `missingFonts` with `--json`). On macOS, "Helvetica" works with system fonts but is missing under
  `--no-system-fonts`, so renders differ between the two modes.
- `--bleed` grows the PDF sheet (MediaBox) by the bleed plus room for marks; TrimBox stays the frame.
  `--cmyk` is a naive sRGB→DeviceCMYK conversion with no output profile: proof before printing.
- `.fig` output is experimental; other apps may not open every file.
- `text.create` lists `x, y` as required but runs without them (lands at 0,0); inside auto layout
  the position is ignored anyway.

## References
- `references/recipes.md`: tested end-to-end recipes (screen build, edit, component properties,
  tokens and dark mode, exports, print PDF, Figma REST JSON, confinement). Read it before writing
  a non-trivial script.
- `references/commands.md`: the generated catalog of all 569 commands. Grep it for a namespace
  (`### layout`, `component.`, `variable.`) when you need a command not shown here.
