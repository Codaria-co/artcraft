---
name: vectorcraft
description: Create, edit and convert vector art (SVG, PDF, AI, EPS, DXF, EMF) with VectorCraft (open-source Illustrator, `vectorcraft-cli`) - load it instead of hand-writing SVG markup or scripting Inkscape. For logos, icons, badges, outlined text, artboard and icon-set exports (SVG/PNG at any scale), PDF/X print files, Pathfinder booleans, image trace (PNG to vector), and inspecting fonts, artboards and color mode of .ai/.eps/.svg files. Not for CAD drawings (cadcraft), UI screens (figcraft) or photo edits (photocraft). Trigger on .svg/.ai/.eps files, 'vectorize', 'convert to SVG/PDF/EPS', 'outline fonts', 'make an icon/logo/badge', even if VectorCraft isn't named.
---

# VectorCraft (`vectorcraft-cli`)

VectorCraft is an Illustrator-style vector editor from the ArtCraft "Crafting Apps" suite. Its native
format is `.vectorcraft`. It reads `.vectorcraft .svg .svgz .pdf .ai .ait .eps .epsf .ps .dxf .emf .wmf
.psd .psb .af/.afdesign/.afpub` and raster images (`.png .jpg .gif .webp .tif .bmp`), and writes
`.vectorcraft .svg .svgz .pdf .ai .eps .dxf .emf .wmf .psd .png .jpg .gif .webp .tif .bmp .tga .txt`.
The output format is always picked from the output file's extension.

## Before you start

- Check `command -v vectorcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install vectorcraft`; Windows: `craft-clis.ps1`).
- Everything here is headless: `convert`, `info` and `run` open the file in an in-process session and
  never need the GUI. The running app only matters for `vectorcraft-cli mcp --connect ADDR` (drive a
  window someone has open with `vectorcraft --control PORT`); prefer `mcp --headless` with automation
  roots when you need MCP at all.

## When to use / when not

- Use for vector art: logos, icons, illustrations, diagrams, cut files, print-ready vector PDFs.
- Multi-page documents and PDF page surgery (merge, split, forms, OCR): `pdfcraft`.
- Photo retouching and pixel work: `photocraft`. Page layout with lots of text: `designcraft`.
- CAD drawings and real DXF engineering work: `cadcraft` (VectorCraft only imports/exports DXF art).
- Making new images from prompts is the `genai` skill's job; VectorCraft can trace the result.

## Core workflows

```bash
# Inspect: artboards [x, y, w, h] in pt, units, colour mode, object kinds, fonts (+ missing), import warnings
vectorcraft-cli info art.ai

# Convert anything readable to anything writable (extension picks the format)
vectorcraft-cli convert logo.ai logo.svg
vectorcraft-cli convert logo.svg logo.pdf
vectorcraft-cli convert drawing.eps drawing.svg

# Raster export: --scale is pixels per point (2 = @2x); PNG is transparent, JPG is flattened on white
vectorcraft-cli convert logo.svg logo@2x.png --scale 2

# One artboard (0-based) or a PDF page range (1-based)
vectorcraft-cli convert sheet.vectorcraft hex.png --artboard 1
vectorcraft-cli convert sheet.vectorcraft pages.pdf --range 2-3

# Text as paths (SVG only; for PDF/AI see recipes)
vectorcraft-cli convert logo.svg logo-outlined.svg --outline-text

# Build art from commands, export several files in one go
vectorcraft-cli run --cmd file.new --params '{"width":256,"height":256,"units":"Pixels"}' \
  --cmd shape.ellipse --params '{"x":28,"y":28,"width":200,"height":200}' \
  --cmd paint.setFill --params '{"color":"#2a9d8f"}' --cmd paint.setStroke --params '{"none":true}' \
  --export icon.svg --export icon.png --scale 4
```

`run` prints one JSON line per step (`{"step":"open"|"cmd"|"export", ...}`); read ids from
`"result":{"id":N}`. Every recipe, including artboard batches, PDF/X, text edits and image trace,
is in `references/recipes.md`.

## Finding the right command

- `vectorcraft-cli commands` prints all 785 commands as JSON (`id`, `label`, `menu`, `params`, `enabled`).
  Pull the full spec for one: `vectorcraft-cli commands | python3 -c 'import json,sys;[print(c["params"]) for c in json.load(sys.stdin) if c["id"]=="document.export"]'`.
- Offline: grep `references/commands.md` (specs clipped). Ids mirror Illustrator's menus:
  `shape.*`, `text.*`/`type.*`, `paint.*`, `stroke.*`, `object.*` (transform, align, pathfinder,
  clipping masks, blends), `select.*`, `artboard.*`, `effect.*`, `imageTrace.*`, `document.*` (export,
  exportPdf, exportForScreens, find, info).
- Reading a spec: `x?` is optional, `a|b` alternatives, `pt=612` default, `→ {...}` the result.
- Commands with `ids?` default to the current selection; new shapes and text become the selection, so
  a `paint.*` right after `shape.*` paints that shape.

## Safe defaults

- Write to new files. `convert` overwrites OUT silently, and OUT may even be IN when the read was
  lossless, so never reuse the input name unless asked.
- Keep the user's original `.ai`/`.eps` and convert to a working copy (`.vectorcraft` keeps everything
  editable; SVG/AI v7 drop features and say so in `warnings`).
- Always read `warnings` and `importWarnings` in the JSON result and report them to the user.
- Quote paths (spaces work). For MCP, confine with `--automation-read-root DIR --automation-write-root DIR`.

## Gotchas

- **Coordinates are points, y down, origin at the first artboard's top-left**, whatever the document
  units. In a Millimeters document `{"x":10,"width":50}` is 10 pt / 50 pt; convert mm × 2.8346.
  Only `file.new` width/height accept strings like `"85 mm"`; shape params reject them.
- `text.create` `y` is the **baseline**, not the top of the text box.
- New shapes get the current default paint (initially white fill, 1 pt black stroke). Set
  `paint.setStroke {"none":true}` explicitly; `paint.setFill` also changes the default for later shapes.
- `--artboard` is 0-based, `--range` 1-based. Without either, PDF gets every artboard, EPS the art
  bounds, and SVG/PNG/others only the **first** artboard. Further artboards sit to the right
  (`file.new artboards:3` → x = 0, 220, 440 with 20 pt spacing).
- `--outline-text` on `convert` only affects SVG (and `--ai-version 7`). For PDF/AI run
  `select.object.textObjects` + `type.createOutlines`, or `document.exportPdf` `advanced.outlineText`.
- Unknown fonts are accepted without error and drawn in the fallback (Source Sans 3). Check
  `info` → `fonts[].status` (`exact|substitute|missing`) and `text.fontList` for real family names.
- Default PDFs embed the native document for re-editing (`preserveEditing`), so they are ~2x larger;
  pass `"preserveEditing":false` to `document.exportPdf` for a lean deliverable. A partial `--range`
  drops it with a warning.
- `--ai-version 7` writes one file per artboard (`OUT-<artboard>.ai`).
- Exit codes: 0 on success, 1 on any error (missing file, parse error, unknown command, bad params,
  invalid JSON, bad artboard index, unknown extension). `run` stops at the first failing step and writes
  none of the `--export` files, so a non-zero exit means no output.
- Object ids are per session. In `run` there is no variable passing between steps: discover ids with
  `document.find` in one run, then use them in the next, or work on the selection (`select.*`).

## References

- `references/recipes.md`: tested end-to-end recipes (conversion matrix, artboard and icon exports,
  outlines, PDF/X, building art, editing text, Pathfinder, image trace, DXF). Read it before any
  non-trivial job.
- `references/commands.md`: generated catalog of every command and the CLI help. Grep it for an id or
  keyword when you don't know the command name; ask `vectorcraft-cli commands` for the unclipped spec.
