---
name: cadcraft
description: CadCraft is an open-source AutoCAD-like 2D CAD app driven headlessly through cadcraft-cli. Use this skill to read, create, edit, convert and render technical drawings from the command line - inspect a DXF/DWG (layers, entity counts, extents), convert DXF <-> DWG and export SVG/PNG/PDF with framing, run AutoCAD-style command scripts (.scr) or JSON commands to draw lines, polylines, rectangles, circles, arcs, text, dimensions, hatches and layers, query entities, measure distances and areas, move/erase by handle, and save the result. Trigger on .dxf, .dwg, .scr files, "CAD drawing", "AutoCAD", "floor plan", "technical drawing", "shop drawing", "dimension this part", "draw a plate/bracket/room", "convert DWG to PDF/SVG/PNG", "AutoCAD script", "layers", or "plot a drawing" - even if the user never names CadCraft.
---

# CadCraft (`cadcraft-cli`)

CadCraft is an AutoCAD-style 2D CAD program from the ArtCraft Crafting Apps suite. Its native formats
are DXF and DWG (DWG written as AutoCAD 2018 by default). The CLI reads DXF/DWG and writes DXF, DWG,
SVG, PNG (2400x1600) and PDF. Everything the app can do (426 commands) is a command id (`line`,
`circle`, `dimlinear`, `layer.new`, `entities`...) that `cadcraft-cli run` executes against a drawing,
either as typed AutoCAD command lines (`--script`, `--script-file`) or as JSON (`--cmd`).

## Before you start
- Check `command -v cadcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install cadcraft`; Windows: `craft-clis.ps1`).
- Headless by default: `info`, `convert`, `run`, `sample`, `commands` need no app. The CadCraft GUI is
  optional; only `mcp --connect HOST:PORT` (with `--launch` to start it) drives a running window.
  Plain `cadcraft-cli mcp` is a headless stdio MCP server.

## When to use / when not
- Use for 2D vector technical drawings: parts, plates, brackets, floor plans, layouts, dimensioning,
  DXF/DWG exchange and plotting to PDF/PNG/SVG.
- Illustrations, logos, artistic SVG: `vectorcraft`. Raster edits on an exported PNG: `photocraft`.
- Combining or editing the exported PDFs: `pdfcraft`. Putting a drawing in a report: `wordcraft`
  (insert the exported PNG/SVG). AI-generated imagery: the `genai` skill.

## Core workflows

Inspect a drawing (JSON: counts per entity type, layers with color/linetype, extents, view, styles):
```bash
cadcraft-cli info part.dxf          # DWG works too
```

Convert / render. Output format comes from the extension; prints `wrote <out> (<n> bytes)`:
```bash
cadcraft-cli convert part.dxf part.dwg
cadcraft-cli convert part.dwg part.dxf
cadcraft-cli convert part.dxf part.pdf                       # also .svg .png; fits drawing extents
cadcraft-cli convert part.dxf detail.png --window 0,0,6,4    # crop to a rectangle in drawing units
```

Draw a new drawing from an AutoCAD script, save DXF and a PNG preview. Use `--metric` for mm
drawings so text and dimension sizes are sane (see Gotchas):
```bash
cat > plate.scr <<'EOF'
-LAYER M Outline C 7 Outline 
RECTANG 0,0 120,80
-LAYER M Holes C 1 Holes 
CIRCLE 20,20 6
CIRCLE 100,60 6
-LAYER M Dims C 4 Dims 
DIMLINEAR 0,0 120,0 60,-15
TEXT 0,95 5 0 PLATE 120x80

ZOOM E
EOF
cadcraft-cli run --metric --script-file plate.scr --save plate.dxf --export plate.png
```
Inline form: `--script $'LINE 0,0 @100,0 @50<90 \nCIRCLE 50,25 10\n'`.

Same job as JSON commands (each `--cmd 'id {json}'`; returns JSON like `{"handle":"100"}` on stdout):
```bash
cadcraft-cli run --metric \
  --cmd 'layer.new {"name":"Walls","color":"red","current":true}' \
  --cmd 'rectang {"p1":[0,0],"p2":[4000,3000]}' \
  --cmd 'text {"at":[0,3300],"text":"ROOM A","height":200}' \
  --cmd 'dimlinear {"p1":[0,0],"p2":[4000,0],"at":[2000,-500]}' \
  --cmd 'hatch {"points":[[2000,1500]],"pattern":"ANSI31","scale":20}' \
  --save room.dwg --export room.svg
```

Edit an existing file (pass it first), always saving to a new path:
```bash
cadcraft-cli run floor.dxf --script $'CIRCLE 100,100 15\n' \
  --cmd 'text {"at":[10,250],"text":"REV B","height":10}' --save floor-revB.dxf --export floor-revB.pdf
```

Query, measure and modify by handle:
```bash
cadcraft-cli run part.dxf --cmd 'entities {"layer":"Holes"}'          # {count, entities:[{handle,type,layer,geometry}]}
cadcraft-cli run part.dxf --cmd 'dist {"p1":[0,0],"p2":[3,4]}' --cmd 'area {"handle":"101"}'
cadcraft-cli run part.dxf --cmd 'move {"handles":["101","102"],"delta":[5,0]}' \
  --cmd 'erase {"handles":["103"]}' --save part-edit.dxf
cadcraft-cli run part.dxf --cmd 'getvar {"name":"INSUNITS"}'
```

Samples for testing: `cadcraft-cli sample bracket|floorplan OUT.(dxf|dwg|svg|png)`; or `run --sample`.

More (older DWG versions, export framing after zoom, hatch, ordering): references/recipes.md.

## Finding the right command
- `cadcraft-cli commands <filter>` prints JSON for matching commands: `id`, `label`, `aliases`,
  `enabled`, and `params`, the full spec, e.g. `{p1, p2, at, rotation? (degrees...), text?}`.
  `?` marks optional keys; `|` separates alternative forms; points are `[x,y]`; angles are degrees.
- The filter matches loosely (it searches more than the id), so pipe through a JSON tool and select
  by `id`.
- Script (typed) syntax follows AutoCAD: command name, then each prompt answer separated by a space
  or newline; `-LAYER`, `-INSERT` etc. are the prompt-driven forms. JSON is easier to get right
  for anything with many options.
- Offline: grep references/commands.md (generated; long specs are clipped there).

## Safe defaults
- Always `--save`/`convert` to a new file. Both overwrite an existing output without asking, and
  `run in.dxf --save in.dxf` replaces your input.
- `run` without `--save` (or `--export`) discards every change.
- After a script run, verify with `info` (counts, layers) or an `--export` PNG; a script that went
  wrong can still exit 0 (see Gotchas).
- Quote `--cmd` arguments with single quotes; JSON keys must be double-quoted.
- `mcp --connect` opens a TCP connection to a running app; only point it at localhost.

## Gotchas
- Units: a new drawing is imperial by default (INSUNITS 1, DIMTXT 0.18, text height 0.2). Drawing in
  mm without `--metric` gives unreadably tiny dimension text. `--metric` sets INSUNITS 4, DIMTXT 2.5.
  `FILE`, `--sample` and `--metric` each pick the starting drawing and the last one wins:
  `run part.dxf --metric` silently drops part.dxf and starts an empty metric drawing (exit 0), while
  `run --metric part.dxf` opens the file unchanged. Never combine `--metric` with a FILE.
- In scripts, an empty line (or extra space) is Enter, and Enter at the command prompt REPEATS the
  last command. A blank line after `-LAYER ...` re-enters LAYER and swallows the rest of the script
  as "Invalid option keyword", with exit 0 and an empty drawing.
- `-LAYER M Name C 7 Name ` needs the trailing space to end the LAYER command (that space is Enter).
- `TEXT` works like DTEXT: it keeps taking lines until an empty line. Without the blank line after
  it, the next script line (`ZOOM E`) becomes a second text line. Text after the rotation keeps its
  spaces. `TEXT J MC x,y h rot value` sets justification.
- Exit codes: 1 for unknown command (`unknown command \`FOOBAR\``), bad JSON (`key must be a string`),
  missing params (`` `radius` or `diameter` is required ``), missing input, unsupported extension
  (`jpg`), bad `--window`; nothing is saved then. But a bad answer inside a script command (e.g.
  `CIRCLE 0,0 abc` -> "Requires numeric distance or second point.") still exits 0 and saves.
- Output streams: the `Command: ...` script log goes to stderr; `--cmd` results and `info` JSON go
  to stdout, one JSON object per line, so `2>/dev/null` gives clean JSON.
- Flags run in command-line order, mixing `--script`, `--script-file` and `--cmd`, and each can
  repeat. A `--cmd` placed before a `--script` sees the drawing before the script ran.
- Export framing in `run`: `zoom {"mode":"window","p1":..,"p2":..}`, `view.set {center,height}` and
  script `ZOOM W` change the exported view. `zoom.window {"p1","p2"}` silently does nothing
  (view unchanged); use the `zoom` form or `--window x0,y0,x1,y1` instead.
- `--window` needs the lower-left corner first (x0<x1, y0<y1), else exit 1.
- PNG renders on a dark background (screen colors); SVG renders on white. For print-style output use
  PDF or SVG.
- Saving to DWG does not keep the current layer (CLAYER reads back as `0`); DXF keeps it.
- `info` on a file with no entities shows `"counts": {}` and `"extents": null`.
- DWG version: `--save x.dwg` writes AutoCAD 2018; for older targets use
  `--cmd 'saveas {"path":"x.dwg","version":2000}'` (2000|2004|2007|2010|2013|2018).
- `mcp --help` is not a flag (prints usage); there is no `describe` subcommand, use `commands`.

## References
- references/recipes.md: tested end-to-end recipes with commands and expected output (samples, info,
  conversions and framing, scripts, JSON drawing, layers, dimensions, hatch, edit by handle, DWG
  versions). Read it before a multi-step job.
- references/commands.md: full command catalog (426 commands). Grep it for an id or param name when
  offline; ask `cadcraft-cli commands <id>` for the unclipped spec.
