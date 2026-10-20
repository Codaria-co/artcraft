---
name: lightcraft
description: LightCraft is the open-source Lightroom (Classic) equivalent of the ArtCraft Crafting Apps — a photo library plus raw developer — and `lightcraft-cli` drives it headlessly. Use this skill to develop/edit photos non-destructively (exposure, contrast, highlights/shadows, white balance, vibrance, HSL mixer, color grading, B&W, sharpening, noise reduction, vignette, grain, crop), auto-tone them, apply built-in or user develop presets (.lcpreset, XMP, .lrtemplate), batch-develop and export a folder to JPEG/PNG/TIFF/WebP/AVIF/JPEG XL/PSD/DNG with resize, quality, color space, renaming and watermarks, merge HDR brackets or panoramas to DNG, and manage a persistent catalog (import, ratings, flags, keywords, titles, albums, XMP sidecars, Lightroom .lrcat import). Trigger on raw files (.CR3, .NEF, .ARW, .RAF, .DNG), "develop", "color-correct these photos", "batch export my shoot", "apply a preset/look", "make web-size copies", "auto-tone", "HDR merge", "photo catalog" — even if the user doesn't name LightCraft.
---

# LightCraft (`lightcraft-cli`)

LightCraft is a Lightroom-style photo library and raw developer from the ArtCraft Crafting Apps
(github.com/storytold/lightcraft, Rust). Edits are non-destructive develop settings stored in a
library (a folder holding `catalog.log`/`catalog.snap`), never written into originals. It reads JPEG,
PNG, TIFF and camera raws/DNG, and exports JPEG, PNG, TIFF, WebP, AVIF, JPEG XL, PSD and (from raws)
DNG. Every menu item is a command id with JSON params; the CLI dispatches the same commands as the GUI.

## Before you start
- Check `command -v lightcraft-cli` (`lightcraft-cli --version`). If missing, use the `artcraft`
  skill's installer (`skills/artcraft/scripts/craft-clis.sh install lightcraft`; Windows: `craft-clis.ps1`).
- Everything here runs headless; the desktop app is optional. Only `--connect [ADDR]` needs it
  (the user starts `lightcraft --control 7980` and the CLI drives that live window). Don't use
  `--connect` unless the user asks to drive their open app.
- Three headless modes for `run`:
  - `--import PATH` (repeatable): a throwaway in-memory session. Nothing persists. Use for one-off jobs.
  - `--library DIR`: open or create a persistent library; edits, ratings, keywords, presets are saved.
  - `--demo`: a procedural demo library (24 synthetic photos, albums). For trying commands safely.

## When to use / when not
- Use for photographic development, look/preset application, batch export and catalog work.
- Pixel-level retouch, layers, compositing, text on images → `photocraft` (Photoshop-like).
- Laying photos into a printed/publication layout → `designcraft`; slides → `deckcraft`.
- Generating new images from a prompt → the `genai` skill. LightCraft only develops existing photos.

## Core workflows

Develop one file and export it (the quickest path; no library involved):
```bash
lightcraft-cli render in.jpg -o out/in-edit.jpg \
  --set light.exposure=0.5 --set color.vibrance=30 --size 2048 --quality 85
```
`--set` is repeatable; output format comes from the extension. `--size` is the long edge (never enlarges).

Apply a built-in preset (ids from `presets.list`, e.g. `lc.bw-high-contrast`, `lc.golden-hour`):
```bash
lightcraft-cli render in.jpg -o out/in-bw.jpg --preset lc.bw-high-contrast --set light.exposure=-0.3
```

Apply a saved look from a file (`.lcpreset`, XMP preset, or partial develop-settings JSON):
```bash
lightcraft-cli render in.jpg -o out/in-look.jpg --settings my.lcpreset
```

Import + auto-tone + tweak + export, in one session (commands run left to right):
```bash
lightcraft-cli run --import in.jpg develop.auto develop.set control=light.exposure value=0.3 \
  crop.aspect aspect=1x1 app.export path=out/in-square.jpg longEdge=1600
```

Batch-develop a folder with the same settings (pass `ids`, see Gotchas):
```bash
lightcraft-cli run --import photos/ library.selectAll \
  preset.apply id=lc.crisp-landscape \
  app.export dir=out/web longEdge=2048 format=jpeg quality=85 naming='trip-{seq:3}'
```

Per-photo auto-tone for a whole folder (auto must run on each photo separately):
```bash
for f in photos/*.jpg; do
  lightcraft-cli run --import "$f" develop.auto app.export dir=out/auto longEdge=2048 || echo "FAIL $f"
done
```

Persistent library: import, edit, rate, tag, export later:
```bash
lightcraft-cli run --library ./MyLib --import photos/ catalog.query
lightcraft-cli run --library ./MyLib develop.set ids='[1]' values='{"light.exposure":0.6}' \
  photo.rate ids='[1]' rating=4 photo.setMeta ids='[1]' title="Blue sky" keywords='["sky"]'
lightcraft-cli run --library ./MyLib app.export ids='[1]' path=out/sky.jpg longEdge=1600
```

HDR merge of brackets (writes `<first>-HDR.dng` next to the inputs), then develop it:
```bash
lightcraft-cli merge hdr brackets/*.dng
lightcraft-cli render brackets/IMG_1-HDR.dng -o out/hdr.jpg --size 2048
```

## Finding the right command
- `lightcraft-cli controls` — every develop slider id with range and default (`--json` for machine use).
  Ids are `section.name`: `light.exposure` (-5..5 EV), `light.contrast|highlights|shadows|whites|blacks`
  (-100..100), `wb.temp` (2000..50000 K), `wb.tint`, `color.vibrance|saturation`,
  `mixer.<color>.hue|sat|lum`, `grading.<shadows|midtones|highlights|global>.hue|sat|lum`,
  `effects.texture|clarity|dehaze`, `vignette.amount`, `grain.amount`, `detail.sharpenAmount` (0..150),
  `detail.nrLuminance`, `crop.angle` (-45..45).
- `lightcraft-cli commands` lists all ~370 command ids with params (`--filter` is ignored; pipe to
  `grep`). For one command's full, unclipped param spec:
  `lightcraft-cli commands --json | python3 -c "import json,sys;[print(c['params']) for c in json.load(sys.stdin) if c['id']=='app.export']"`
- `lightcraft-cli run presets.list` — built-in preset ids (41, groups Color/Film/B&W/Landscape/Portrait/…).
- `run` prints one JSON line per command: `{"command","ok","result"|"error","ms"}`; parse with `python3`/`jq`.
- Offline: grep `references/commands.md` (generated catalog; long specs are clipped there).

## Safe defaults
- Always write to a new output path or a separate `dir=`. LightCraft refuses to write over a photo's
  original (exit 1), but it does silently overwrite an earlier export at the same `-o`/`path`.
- For folder exports use `dir=` with `conflict=unique` (the default: `-2` suffix) or `conflict=skip`.
- Use `--import` sessions for one-off jobs; reach for `--library` only when the user wants a catalog
  that persists. `library.import` defaults to `mode=add` (references files in place, nothing copied).
- `photo.saveMetadataToFile`, `merge`, `photo.convertToDng`, `photo.rename`, `folder.*` and
  `library.import mode=move` write into the user's photo folders; ask before using them.
- Quote paths and JSON values (`values='{"light.exposure":0.4}'`, `ids='[1,2]'`).
- Don't run `denoise-serve` (opens a network port) or `segment.model.download` (3.4 GB) unless asked.

## Gotchas
- `develop.set` and `develop.auto` only change the **active** photo, even after `library.selectAll`.
  For several photos pass `develop.set ids='[1,2]' …`, or follow with `develop.sync` (copies the active
  photo's settings to the selection). `preset.apply` does apply to the whole selection.
- `develop.auto` overwrites light/color sliders set before it. Run it first, then `develop.set`.
- After `--import`, every imported photo is selected; photo ids are assigned by sorted path (1, 2, …).
  Check them with `catalog.query` before targeting `ids`.
- Out-of-range slider values are silently clamped (`light.exposure=9` becomes 5). Unknown control or
  preset ids fail with exit 1 (`unknown control`, `unknown preset`).
- `--preset` takes the id (`lc.bw-high-contrast`), not the display name. User presets live inside a
  library; `render` can't see them by id — export them (`preset.export path=x.lcpreset`) and use `--settings`.
- `--settings` JSON uses the snake_case keys of `develop.get` (`{"light":{"exposure":0.8}}`), not the
  dotted control ids.
- `render` takes one file. Given a folder it silently renders just one photo — loop in the shell or use
  `run --import DIR … app.export dir=…`.
- `app.export path=FILE` with several photos ignores the file name and writes each photo under its own
  name into the **current directory**. Use `dir=` for multi-photo exports.
- Export never enlarges: `--size`/`longEdge` larger than the photo keeps the original size. Default
  `app.export` long edge is 3000; `longEdge=0` is full size.
- `.dng` output needs a raw input ("DNG export needs a raw photo"); `.gif` is not supported.
- Exports carry title/keywords/rating as XMP by default; `metadata=none` strips everything.
- `run` exits non-zero if any command failed; it stops at the first failure unless `--keep-going`
  (still exits 1 at the end).
- `merge` writes its DNG next to the first input file; there is no `-o`. Use `--preview OUT.png` for a
  dry look.

## References
- `references/recipes.md` — tested end-to-end recipes (render variants, batch, library, presets,
  metadata, HDR, script files) with expected output. Read it when building a multi-step job.
- `references/commands.md` — generated catalog of every command and the `--help` text. Grep it for a
  command id or parameter name before guessing.
