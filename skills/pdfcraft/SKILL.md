---
name: pdfcraft
description: PdfCraft is a free, open-source Acrobat-style PDF reader and organizer with a headless CLI (`pdfcraft-cli`). Use this skill to inspect PDFs (page count, metadata, encryption, fonts), extract text, render pages to PNG/JPEG, rotate/delete/move/insert pages, combine, extract and split, convert images and .txt to PDF, optimize/reduce file size, OCR scans, add watermarks, headers/footers and Bates numbers, edit metadata, add or remove passwords, apply real redactions (SSN, email, phone, find text) and audit for faux redactions, fill forms, export to Word/HTML, and script any of its 170 automation tools. Trigger on any .pdf file or on verbs like merge, split, rotate, reorder, extract pages, compress, OCR, redact, watermark, password-protect, unlock or "what's in this PDF", even if the user doesn't name PdfCraft.
---

# PdfCraft (`pdfcraft-cli`)

PdfCraft is the ArtCraft suite's Acrobat: a Rust desktop app for reading, organizing and editing PDFs.
The CLI has direct subcommands for the common jobs (`info`, `text`, `render`, `edit`, `combine`,
`extract`, `split`, `batch`, `audit`, `check`) plus `run`, which reaches every one of the app's 170
automation tools (forms, bookmarks, redaction, watermarks, security, optimization, export…). It reads
and writes PDF; it also turns PNG/JPEG/TIFF/GIF/BMP/JPEG 2000 and `.txt` into PDF, and exports
pages to PNG/JPEG/TIFF and documents to .docx/.pptx/.html/.rtf/.txt.

## Before you start
- Check `command -v pdfcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install pdfcraft`; Windows: `craft-clis.ps1`).
- Everything runs headless. The running app is only needed for `pdfcraft-cli ui --control FILE …`,
  which drives a GUI that was started with `--control FILE`; you rarely want that.
- `pdfcraft-cli mcp` exposes the same tools as an MCP server on stdio (opt-in). Confine it with
  `--automation-read-root DIR --automation-write-root DIR`.

## When to use / when not
- Use for anything done *to* an existing PDF: inspect, read, reorganize, merge/split, secure,
  redact, stamp, optimize, OCR, fill forms, compare two versions.
- Writing a document and *producing* a PDF from it: `wordcraft` (Word-like) or `designcraft`
  (print layout). Slides to PDF: `deckcraft`. Vector artwork from a PDF page: `vectorcraft`.
- Retouching a rendered page image: `photocraft`. New images from a prompt: the `genai` skill.

## Core workflows
```bash
# What is this file? JSON: pages, page size (pt), title/author, encrypted, bookmarks, fields, warnings
pdfcraft-cli info in.pdf

# Read the text (all pages, separated by form feeds \f), or one page
pdfcraft-cli text in.pdf
pdfcraft-cli text in.pdf --page 3

# Look at a page (default page 1, 96 dpi; .png .jpg .tif .pam)
pdfcraft-cli render in.pdf --page 2 --dpi 150 --out page2.png

# Reorganize pages; options run left to right, each on the result of the previous one
pdfcraft-cli edit in.pdf --out out.pdf --delete 2 --move 4:1 --rotate 1:90 --insert-blank 1 \
  --title "Report" --author "Ops"

# Merge (PDFs only), pull pages, split
pdfcraft-cli combine a.pdf b.pdf c.pdf --out merged.pdf
pdfcraft-cli extract in.pdf --pages 5,1-3 --out picked.pdf       # order is kept as given
pdfcraft-cli split in.pdf --every 2 --out-dir parts             # parts/in-p1-2.pdf, in-p3-4.pdf…
pdfcraft-cli split in.pdf --before 3,7 --out-dir parts          # cut before pages 3 and 7

# Convert images/.txt to PDF and shrink, a folder at a time (never touches the sources)
pdfcraft-cli batch scans/ --steps convert,optimize --out-dir out --ppi 150 --quality 60

# Redaction check before sending a file out (exit 1 when something readable is hidden)
pdfcraft-cli audit in.pdf
```

Anything beyond these goes through a JSON script of tool calls. Open the file, refer to it as
`"doc": 1` (ids count from 1 in each run), act, save to a new path:
```bash
cat > steps.json <<'EOF'
[
 {"tool":"doc_open","args":{"path":"in.pdf"}},
 {"tool":"redact_mark","args":{"doc":1,"pattern":"ssn"}},
 {"tool":"redact_apply","args":{"doc":1}},
 {"tool":"doc_save","args":{"doc":1,"path":"redacted.pdf"}}
]
EOF
pdfcraft-cli run --script steps.json --report     # one JSON document: ok + per-step status/result
```
Tools that don't need an open document run directly, with `key=value` args (arrays/objects as JSON):
```bash
pdfcraft-cli run doc_combine 'paths=["a.pdf","notes.txt","photo.jpg"]' out=merged.pdf
```

See `references/recipes.md` for tested scripts: passwords on/off, metadata, watermark, header/footer
page numbers, find text, export pages as images, export to .docx, faux-redaction audit.

## Finding the right command
- `pdfcraft-cli tools` prints every tool as JSON (`name`, `description`, `input_schema`, `read_only`).
  Pull one schema with:
  `pdfcraft-cli tools | python3 -c "import json,sys;print(json.dumps([t for t in json.load(sys.stdin) if t['name']=='doc_protect'][0],indent=1))"`
- Names are grouped by prefix: `doc_*` (whole document: save, info, protect, watermark, optimize,
  export, compare, print), `page_*`, `text_*`, `form_*`, `bookmark_*`, `redact_*`, `comment_*`,
  `link_*`, `content_*`, `measure_*`.
- `references/commands.md` is the same catalog, offline and greppable (long specs are clipped there;
  the CLI's `tools` output is the full truth). `pdfcraft-cli --help` lists the subcommands.
- Coordinates in tools are points (1/72 in) from the **top-left** of the displayed page; pages are
  1-based everywhere.

## Safe defaults
- Write to a new file. `edit --out` *will* overwrite its own input if you pass the same path, and
  `split` silently replaces same-named parts in the output folder. `batch` is the exception: it
  never replaces, it writes `name (2).pdf`.
- In scripts always give `doc_save` a `path`; without one it saves in place (incremental update).
- Quote paths with spaces; pass JSON args in single quotes.
- Use `--root DIR` with `run` when the paths come from someone else: relative paths resolve inside
  DIR and `../` escapes are refused.
- Passwords given with `--password` or in a script are never echoed back, but they land in shell
  history and in the script file; delete the script after use.

## Gotchas
- `--password` works on `info`, `text`, `render`, `edit`, `extract` and `audit`, though `--help`
  shows it only on `info`/`audit`. The open (user) password lets you read and render; text copy and
  page changes need the owner (permissions) password when the file restricts them.
- `edit` on an encrypted file keeps the encryption in the output; `extract` writes an unencrypted
  file. To remove security on purpose use `doc_open` (owner password) → `doc_unprotect` → `doc_save`.
- `edit` ops are sequential: in `--delete 2 --move 4:1`, "4" is the 4th page *after* the delete.
  `--move P:T` puts page P at position T counted before the move (`1:5` on a 5-page file = last).
  Rotation is clockwise, multiples of 90 only, and needs a page list (`--rotate 1-5:90`, not `90`).
- Page lists accept `1,3,5-8`; open ranges like `2-` and words like `all` are rejected. Out-of-range
  pages fail the whole command (exit 1, nothing written).
- `combine` and `extract` print nothing on success; `split` prints the files it wrote. Check exit
  codes: 0 ok, 1 for any error, faux redactions found, or failed batch files.
- `combine` takes PDFs only and needs at least two. For images or .txt use `run doc_combine` or
  `batch --steps convert`.
- `run <tool>` is one fresh process: tools that need `doc` can't be called that way (no document is
  open). Use `--script`. `run --script … --out x.png` ignores `--out`; use `doc_export_images`.
- A failing script step stops the run: later steps show `skipped` and nothing is saved (exit 1).
- OCR (`batch --steps ocr`, `doc_ocr`) needs PdfCraft's text-recognition models. A CLI-only
  install doesn't have them: the step fails with "models are not installed". The desktop app ships
  them, so point the CLI there: on macOS
  `PDFCRAFT_MODELS=/Applications/PdfCraft.app/Contents/Resources/models pdfcraft-cli batch … --steps ocr`
  (verified). Without the app, install it (ArtCraft Launcher or the release page) first.
- `check` (open/render health scan) exits 0 even when files fail to open and skips non-PDFs silently;
  read its summary line or `--json` report.
- `audit` finds dark filled rectangles painted over live text and unapplied redaction marks. It did
  not flag a black *image* placed over text, so render the page too when a file looks suspicious.
- Watermark, header/footer and redaction overlay text become real page text: `text` will return it.
- `info` shows title/author but not subject/keywords; use `doc_info` in a script for those.
- `render` accepts up to 700+ dpi on the CLI, `page_render` caps at 600. Large dpi = huge PNGs.

## References
- `references/recipes.md` — read when the job goes beyond the core workflows (security, metadata,
  redaction, stamping, exports, batch); every recipe there was run and its output shown.
- `references/commands.md` — grep it to find a tool by keyword (`grep -n watermark`), then read the
  full schema from `pdfcraft-cli tools`.
