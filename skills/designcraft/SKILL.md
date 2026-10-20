---
name: designcraft
description: DesignCraft is the open-source InDesign equivalent in the ArtCraft Crafting Apps suite; this skill drives its headless CLI (designcraft-cli) to build and export page layouts. Use it to create multi-page print or digital documents (Letter/A4/custom, facing pages, margins, columns, bleed), add text frames, paragraph/character styles, swatches, placed images, parent (master) pages with page numbers, threaded/autoflowed long text, data merge (CSV to cards/badges), preflight and packaging; and to export PDF (marks, bleed, page ranges), PNG/JPG page renders, IDML, EPUB, HTML or PPTX. Also opens .designcraft, .idml and InDesign .indd/.indt files. Trigger on brochures, flyers, magazines, catalogues, zines, booklets, books, business cards, posters, newsletters, print-ready PDFs, "lay out these pages", "make an IDML", "export each page as PNG", or any desktop-publishing task, even if the user doesn't name DesignCraft.
---

# DesignCraft (`designcraft-cli`)

DesignCraft is an InDesign-like page layout app (Rust, open source, by storytold). Its native file is
`.designcraft` (images embedded); it also opens IDML and InDesign `.indd`/`.indt` (converted to IDML),
and writes PDF, PNG/JPG, IDML, EPUB, HTML, PPTX, plain/RTF text and packages. Every menu action is a
registry command (`file.new`, `frame.create`, `style.paragraph.apply`, …, 521 in v0.10.0) that the CLI
runs headless against an in-memory document.

## Before you start
- Check `command -v designcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install designcraft`; Windows: `craft-clis.ps1`).
- Headless by default: `run`, `script`, `describe`, `commands` need no GUI. The DesignCraft app is
  optional. Only `script --connect PORT`, `mcp --connect PORT` and `app --port PORT …` talk to a
  running app started with `designcraft --control PORT`; use them only when the user wants to watch or
  edit the live document.

## When to use / when not
- Use for anything page-based: fixed layouts, multi-page documents, print PDFs, IDML hand-off.
- Not for: slide decks (deckcraft), long manuscripts/word processing (wordcraft), editing an existing
  PDF (pdfcraft), vector illustration/logos (vectorcraft), photo retouching (photocraft), UI mockups
  (figcraft), spreadsheets (gridcraft). New images from prompts are the `genai` skill's job; place the
  result here with `file.place`.

## Core workflows

All coordinates and sizes are **points** (72/inch), origin top-left of the spread. See Gotchas.

1. Smoke test / see what the engine can do (sample magazine):
   ```bash
   designcraft-cli run --sample --export sample.pdf --all-pages pages/
   ```
2. One-off commands chained with `run` (no result references between steps):
   ```bash
   designcraft-cli run --cmd 'file.new={"preset":"Letter","pages":4,"facingPages":true}' \
     --cmd document.inspect
   ```
3. Real layouts: write a script file (one `command.id {json}` per line, `#` comments, `$N.field`
   refers to step N's result, 0-based, `$last` = previous step), then save and export:
   ```bash
   designcraft-cli script layout.dcs --save out.designcraft --export out.pdf --export out.png
   ```
   A complete styled brochure (styles, parent folio, image, body) is recipe 3 in references/recipes.md.
4. Edit an existing document: `--in FILE` opens `.designcraft` or `.idml` first.
   ```bash
   designcraft-cli script edits.dcs --in out.designcraft --save out-v2.designcraft
   ```
5. Export variants from a saved file (`--page`, `--scale`, `--pdf-options` apply to the exports that
   follow them):
   ```bash
   designcraft-cli run --in out.designcraft --export plain.pdf \
     --pdf-options '{"marks":true,"bleed":true}' --export press.pdf \
     --export out.idml --page 0 --scale 0.5 --export thumb.jpg --all-pages pages/
   ```
6. Long text: `file.place {"path":"story.txt","page":1,"rect":[…],"autoflow":true}` adds pages and
   threads column frames until the text fits (recipe 5).
7. Data merge from CSV into one record per page (recipe 7); preflight and package for print (recipe 9).

Key text/style moves (all tested):
- `frame.create {"spread":0,"rect":[x0,y0,x1,y1],"content":"text","text":"Para 1\nPara 2"}` → `{id, story}`.
- Apply a paragraph style to a whole frame: `selection.set {"ids":[id]}` then `style.paragraph.apply {"name":…}`.
- Style part of a story: `text.select {"story":s,"anchor":0,"focus":8}` (UTF-8 byte offsets) then
  `style.character.apply` / `style.paragraph.apply`.
- Replace text: `story.setText {"story":s,"text":…}`.
- Image in a frame: `frame.create {…,"content":"graphic"}`, `file.place {"path":…,"frame":id}`,
  `object.fit {"mode":"fillProportionally","ids":[id]}`.
- Parent page items: `frame.create {"spread":{"kind":"parent","index":0},…}`; page number = the
  character `` in the text. New parent: `layout.parents.new {"prefix":"B","name":"Chapter"}`,
  then `layout.pages.applyParent {"pages":[1,2],"parent":"B"}` (0-based page indexes).

## Finding the right command
- `designcraft-cli commands FILTER` prints matching commands as JSON (id, label, params).
- `designcraft-cli describe COMMAND` prints the full param spec. Read it before using a command: specs
  are `{name?: type, …} → result`; `?` marks optional; enums are `a|b|c`.
- `document.inspect {}` returns pages (bounds, margins, parent), spreads with item ids/bounds, stories
  (id, frames, overset, preview), styles, swatches, parents. Use it to discover ids before editing.
- Offline: grep references/commands.md (generated catalog; long specs are clipped there).

## Safe defaults
- Save and export to new paths; keep the user's `.designcraft`/`.idml` input untouched unless asked.
- Quote paths and JSON (`--cmd 'id={"k":"v"}'`). Use absolute paths for data sources (relative CSV
  paths warn and fall back to cached rows).
- `file.package {"dir":…}` overwrites files in an existing folder without asking; give it a fresh dir.
- MCP mode: confine file access with `designcraft-cli mcp --automation-read-root DIR --automation-write-root DIR`
  (a root left out grants no access of that kind).
- After building, check `document.inspect` for `"overset": true` and run `preflight.run {}` before
  calling a print PDF done.

## Gotchas
- Units: every numeric param is points, whatever `units` says. `file.new {"units":"millimeters","width":148}`
  makes a 148 pt page, not 148 mm; multiply mm by 2.8346. `units` only changes the display.
- Spread coordinates: on a facing spread the left page is x 0–W and the right page x W–2W. Page 1 of a
  facing document is a right page alone on spread 0. Parent spreads use the same layout, so a parent
  item at x < W shows only on left pages.
- Page numbering differs by command: `--page N` is 0-based; `file.exportPdf.pages` and
  `layout.pageSize.pages` are 1-based; `layout.pages.applyParent.pages` and `layout.overrideParentItems.page`
  are 0-based indexes. `--page` past the end fails with `no such page`.
- PNG size: `run --export x.png` renders page 0 at 1 px/pt (plus bleed if the document has bleed:
  612×792 Letter becomes 630×810 with 9 pt bleed). `script --export x.png` renders page 1 at 2×.
  Use `run --in … --page N --scale S --export` for control.
- `--pdf-options` sticks to every later `--export`; put the plain export first.
- `script` stops at the first failing step (exit 1, JSON with `failedIndex`); `--keep-going` records
  `{"error":…}` per step but exits 0, so check the results yourself.
- Unknown params are rejected (`unknown parameter 'bogus'; the command takes: …`), and malformed values
  can give a misleading message (a 3-number `rect` reports `missing rect`).
- Story ids and frame ids are different numbers (`frame.create` → `{id: 13, story: 14}`); pass the
  story id to `story.*`/`text.select`. Ids survive save/reopen.
- Data placeholders insert `<<field>>` text and shift later offsets: add them from the end backwards.
- `file.place` of `.md` brings the text literally (`# Heading` stays as text, blank lines become empty
  paragraphs). Style it afterwards.
- A fresh process already has an empty `Untitled-1`; `file.new` becomes index 1 / `Untitled-2`, and
  `file.package` names its files after the document title, so pass `title` to `file.new`.
- `data.merge` opens the merged result as a new active document; `--save`/`--export` then act on it.
- Bundled font is Source Serif 4 (Regular/Italic/Bold); check `font.list {}` for `missing` fonts after
  opening IDML/INDD from elsewhere.

## References
- references/recipes.md — tested end-to-end recipes (sample render, new doc, styled brochure script,
  export matrix, autoflow + parents, edits, data merge, IDML round trip, package, error handling).
  Read it before writing a script from scratch.
- references/commands.md — the full generated command catalog; grep it for an id or keyword, then run
  `describe` for the unclipped spec.
