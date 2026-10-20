---
name: photocraft
description: PhotoCraft is the open-source Photoshop equivalent of the ArtCraft Crafting Apps; this skill drives its headless `photocraft-cli` to open, edit and export raster images and layered PSDs without the GUI. Use it to convert between PSD/PNG/JPEG/WebP/TIFF/EXR/GIF/BMP/TGA/DPX, resize, crop, rotate, change canvas, adjust (levels, curves, hue/saturation, brightness/contrast, black & white, CMYK/grayscale), apply filters (blur, sharpen, noise), add or replace text in type layers, add layers, adjustment layers and drop shadows, place a logo or watermark, remove a background, trim transparency, export layers to files, inspect a PSD's layer tree, or batch-process a folder of photos (Photoshop actions, .atn, droplets, Image Processor). Trigger on .psd/.pcraft files, "photoshop this", "edit this image", "make thumbnails", "batch resize", "watermark", "social card", "remove background", "export layers", even if the user doesn't name PhotoCraft.
---

# PhotoCraft (`photocraft-cli`)

PhotoCraft is a Photoshop-style raster editor (layers, masks, type, adjustment layers, actions) written
in Rust. Its native format is `.pcraft` (a zip); it reads and writes Photoshop `.psd` with layers, plus
PNG, JPEG, WebP, TIFF (flat or layered), OpenEXR, GIF, BMP, TGA and DPX. The CLI runs the same engine
headless: every menu item is an engine command (`image.imageSize`, `filter.blur.gaussianBlur`, …) that
you chain with `run`.

## Before you start
- Check `command -v photocraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install photocraft`; Windows: `craft-clis.ps1`).
- Everything here is headless. The GUI app is only needed for `mcp --bridge 127.0.0.1:<port>`, which
  forwards commands to a running `photocraft --control <port>` so the user sees edits live. Don't use it
  unless the user asks to drive their open window.

## When to use / when not
- Use for pixel work: photos, PSD templates, thumbnails, banners, composites, color/mode conversion,
  batch jobs over image folders.
- Vector logos, icons, SVG → `vectorcraft`. Raw development and photo libraries → `lightcraft`.
  Multi-page print layout → `designcraft`. UI mockups → `figcraft`. Video/motion → `filmcraft` /
  `effectcraft`. PDFs → `pdfcraft`.
- Making a new image from a text prompt is the `genai` skill's job; hand off, then retouch here.

## Core workflows
Every `run` opens one file (or `--new <json>`), runs each `--cmd` in order (each `--params` belongs to
the `--cmd` before it), prints one JSON line per command, then saves to `--out`.

```bash
X=photocraft-cli

# Inspect a file: size, mode, depth, layer tree with ids, names, kinds, bounds [x,y,w,h]
$X info poster.psd --compact

# Convert formats (format from the extension; --quality 1-100 for JPEG/WebP)
$X convert poster.psd poster.jpg --quality 85
$X convert poster.psd poster-layers.tif --tiff-layers      # TIFF keeping layers

# Resize keeping aspect (one side is enough), or fit inside a box without enlarging
$X run photo.jpg --cmd image.imageSize --params '{"width":1200}' --out photo-1200.jpg --quality 85
$X run photo.jpg --cmd file.automate.fitImage --params '{"width":1080,"height":1080,"dontEnlarge":true}' --out fit.jpg

# Crop (pixels, top-left origin) and adjust/filter in one pass
$X run photo.jpg \
  --cmd image.crop --params '{"x":400,"y":50,"width":350,"height":300}' \
  --cmd image.adjustments.brightnessContrast --params '{"brightness":30,"contrast":20}' \
  --cmd filter.sharpen.unsharpMask --params '{"amount":80,"radius":1.5}' \
  --out photo-edit.jpg --quality 90

# Replace the text of a named type layer in a PSD template and export flat + layered
$X run template.psd --cmd layer.select --params '{"name":"Title"}' \
  --cmd type.edit --params '{"text":"Sale 50% off"}' --out filled.psd
$X convert filled.psd filled.png

# New canvas from scratch: gradient + centered paragraph text
$X run --new '{"width":1080,"height":1080}' \
  --cmd layer.newFillLayer.gradient --params '{"from":"#1e3c72","to":"#2a5298","angle":90,"style":"linear"}' \
  --cmd type.create --params '{"box":[90,400,900,300],"text":"Summer Launch\nJune 21","align":"center","size":96,"color":"#ffffff","font":"Helvetica","fontStyle":"Bold"}' \
  --out card.png

# Batch a folder with a JSON action list (skips non-images; no recursion)
echo '[["file.automate.fitImage",{"width":400,"height":400}],"layer.flattenImage"]' > actions.json
$X batch --actions actions.json --in photos --out thumbs --format jpg --quality 80
```

More (watermark, remove background, layers to files, recursive batch, CMYK, serve): `references/recipes.md`.

## Finding the right command
- `photocraft-cli commands --filter <text>` lists matching ids, labels and menu paths
  (`--filter rotat` → `image.imageRotation.90cw`, `image.rotation.arbitrary`, …). Ids follow the
  Photoshop menus: `image.adjustments.*`, `filter.<group>.*`, `layer.new.*`, `layer.newAdjustmentLayer.*`,
  `select.*`, `type.*`, `file.automate.*`, `file.scripts.*`, `file.export.*`.
- `photocraft-cli commands --filter <id> --json` prints the full `params` spec, e.g.
  `{"radius":0.1..1000=1}` = key, range, default; `?` = optional; `|` = choices.
- `references/commands.md` is the same registry offline (specs clipped); grep it by id or keyword, then ask
  the CLI for the full spec.
- Unknown keys and out-of-range values are rejected with a precise message, so a failed run tells you
  what to fix.

## Safe defaults
- Always pass `--out` to a new file. `run` without `--out` saves nothing (useful as a dry run);
  `convert` and `run --out` overwrite an existing file silently.
- Keep the layered master (`.psd`/`.pcraft`) and export flat copies; flat formats print
  `warning: N layer(s) flattened`.
- `batch` refuses `--out` equal to `--in`; only pass `--in-place` when the user asked to overwrite.
- Quote JSON params in single quotes; build paths with spaces into the JSON carefully.
- For an agent-facing server, confine file access: `serve` or `mcp` with
  `--automation-read-root <dir> --automation-write-root <dir>` (parent traversal is rejected). Prefer stdio;
  don't open `--port` unless the user wants it.

## Gotchas
- Commands act on the **active layer**, not the whole image. A PSD opens with its top layer active, so a
  filter hits only that layer. Select first (`layer.select {"name":…}`) or `layer.flattenImage` first.
- Selections persist across commands: `select.rect` then `edit.fill` fills only the rect; end with
  `select.deselect` before whole-image steps.
- Units: pixels, origin top-left. Type `size` is in points; at the default 72 ppi 1 pt = 1 px.
  `image.imageSize {"resolution":300}` alone only changes ppi (no resample).
- Opacity scales differ: `layer.setProps` uses 0..1, layer styles (`dropShadow`) use 0..100.
  Quality differs too: CLI `--quality` is 1..100, in-command `quality` (saveACopy, imageProcessor,
  layersToFiles) is 0..12.
- Bounds formats differ: `info`, `layer.removeBackground`, `select.subject`, `image.trim` report
  `[x,y,w,h]`; `type.create`/`type.edit` and `file.placeEmbedded` report `[x0,y0,x1,y1]`.
- Gradient `angle` 90 runs `from` at the bottom to `to` at the top (Photoshop convention).
- A missing font only warns (`font 'X' is not installed`) and renders with a fallback; check stderr.
- `image.mode.cmyk` defaults to a synthetic built-in profile; pass `"profile":"/path/to/printer.icc"` for
  real print work.
- `batch` does not recurse into subfolders. For trees, use `file.automate.batch` or
  `file.scripts.imageProcessor` with `"includeSubfolders":true` (recipes).
- Exit codes: 0 ok; 1 command/param/IO error or any failed file in `batch` (the rest still get written);
  2 bad CLI usage. A failing command mid-chain aborts the run and writes nothing.
- JSON results go to stdout, warnings and errors to stderr, so `2>/dev/null` keeps stdout parseable.

## References
- `references/recipes.md`: read when the job goes beyond the core workflows above (watermark, cutout,
  layers to files, adjustment layers, recursive batch, CMYK/print, headless server). Every recipe was run.
- `references/commands.md`: grep for a command id or keyword when `commands --filter` isn't handy;
  it lists all 918 commands with clipped param specs.
