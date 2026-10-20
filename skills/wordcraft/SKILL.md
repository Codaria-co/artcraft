---
name: wordcraft
description: Write, edit and convert Word documents with WordCraft (open-source Microsoft Word, `wordcraft-cli`) - prefer it over generic docx skills and over python-docx/pandoc when the CLI is installed. For letters, cover letters, resumes/CVs (hoja de vida), memos, reports and handbooks, from scratch or from Markdown/LaTeX/HTML; headings, styles, tables, images, table of contents, headers/footers, page numbers; tracked changes (accept/reject) and comments; mail merge from CSV/XLSX; templates; word and page counts; text extraction; exporting PDF/ODT/RTF/HTML/MD and page PNGs. Not for manipulating existing PDFs (pdfcraft) or designed print layouts (designcraft). Trigger on .docx/.doc/.odt/.rtf files, 'Word document', 'carta', 'track changes', 'mail merge', even if WordCraft isn't named.
---

# WordCraft (`wordcraft-cli`)

WordCraft is a Word-like word processor from the ArtCraft Crafting Apps suite. Its native format is
`.docx` (also `.dotx` templates). It reads docx, doc, odt, rtf, html, md, tex, txt, json and Word XML
(Flat OPC / Word 2003), and writes all of those except doc, plus pdf and png. It cannot read PDF.
Everything the app can do is a command id (`text.insert`, `insert.table`, `review.newComment`…) that
`wordcraft-cli run` executes headlessly against a document.

## Before you start
- Check `command -v wordcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install wordcraft`; Windows: `craft-clis.ps1`).
- Headless by default: `convert`, `info`, `text`, `inspect`, `render` and `run` need no running app.
  Only `mcp --connect HOST:PORT` talks to a running WordCraft window; `zotero` needs Zotero running.
- Set `WORDCRAFT_REGION=en-US` (Letter) or e.g. `en-GB`/`de-DE` (A4) for any job that creates a new
  document or converts md/html/txt. Without it the paper size follows the machine's locale, so the
  same command gives Letter on one machine and A4 on another.

## When to use / when not
- Use for flowing text documents: reports, letters, briefs, resumes, contracts, redlines, merges.
- Editing or merging existing PDFs, filling PDF forms: the `pdfcraft` skill.
- Slides: `deckcraft`. Spreadsheets/CSV analysis: `gridcraft`. Page-layout posters and flyers:
  `designcraft`. Raster image editing: `photocraft`. New AI-generated images: the `genai` skill,
  then insert the file with `insert.picture`.

## Core workflows

Convert between formats (output format comes from the extension; exit 0 and `wrote <out>`):
```bash
WORDCRAFT_REGION=en-US wordcraft-cli convert notes.md notes.docx
wordcraft-cli convert report.docx report.pdf          # also .html .md .tex .odt .rtf .txt .json .xml
wordcraft-cli convert report.docx review.pdf --markup  # comments in balloons + tracked changes shown
wordcraft-cli convert report.docx report.xml --format wordml2003   # Word 2003 XML (default .xml = Flat OPC)
```

Read a document without changing it:
```bash
wordcraft-cli info report.docx      # JSON: pages, words, paragraphs, comments, trackChanges, properties
wordcraft-cli text report.docx      # plain text, tables tab-separated, accepted-view of revisions
wordcraft-cli inspect report.docx   # JSON blocks: style, text, runs with bold/italic, table cells
```

Preview a page as PNG (check layout visually before handing a file over):
```bash
wordcraft-cli render report.docx page2.png --page 2 --scale 1   # 1 px per pt; default scale is 2
```

Build or edit a document with commands, then save. Each `--cmd` is `id` or `id={json}`; they run in
order like keystrokes at the caret:
```bash
WORDCRAFT_REGION=en-US wordcraft-cli run --author "Ana Ruiz" \
  --cmd para.heading1 --cmd 'text.insert={"text":"Project Brief"}' --cmd text.newParagraph \
  --cmd para.normal   --cmd 'text.insert={"text":"This brief explains the scope."}' --cmd text.newParagraph \
  --cmd 'insert.table={"rows":3,"cols":2,"style":"Grid Table 4 – Blue"}' \
  --cmd 'text.insert={"text":"Item"}' --cmd caret.right --cmd 'text.insert={"text":"Cost"}' \
  --cmd caret.docEnd --cmd 'insert.picture={"path":"logo.png","width":144,"alt":"Logo"}' \
  --save brief.docx
```
Edit an existing file with `--file in.docx … --save out.docx`.

Review: comment on text, then make tracked edits; clean up later:
```bash
wordcraft-cli run --file brief.docx --author "Reviewer" \
  --cmd 'select.text={"text":"scope"}' --cmd 'review.newComment={"text":"Define scope precisely"}' \
  --cmd 'review.trackChanges={"value":true}' \
  --cmd 'edit.replaceAll={"text":"brief explains","with":"document describes"}' --save brief-reviewed.docx
wordcraft-cli run --file brief-reviewed.docx --cmd review.acceptAll \
  --cmd 'review.deleteComment={"all":true}' --save brief-final.docx
```

Templates and mail merge:
```bash
wordcraft-cli run --template letter --save letter.docx          # built-ins: blank sample letter resume report
wordcraft-cli run --cmd 'file.newFromTemplate={"path":"house.dotx"}' --save new.docx   # your own .dotx
wordcraft-cli run --cmd 'mailings.start={"kind":"letters"}' --cmd 'mailings.recipients={"path":"people.csv"}' \
  --cmd 'text.insert={"text":"Dear "}' --cmd 'mailings.insertField={"field":"Name"}' \
  --cmd 'mailings.finish={"path":"merged.docx"}'
```

More (TOC, header/footer, page size, watermark, encryption, exports): references/recipes.md.

## Finding the right command
- `wordcraft-cli commands | grep -i <word>` lists id, label, shortcut and menu location (there is no
  `--filter` option).
- `wordcraft-cli commands --json` gives each command's `params` spec, e.g.
  `{"rows": n, "cols": n, "style"?: string}`; `?` marks optional keys, `pt` means points.
  Pipe it through a JSON tool and select by `id` to read one full spec.
- Discovery commands return data with `--print` (prints `id: {json}` per command):
  `styles.manage` (all style names incl. table styles), `layout.section`, `document.text`,
  `file.inspect` (counts comments, revisions, hidden text), `mailings.editRecipients`.
- Offline: grep references/commands.md (generated; long specs are clipped there).

## Safe defaults
- Always `--save` to a new path; `convert` and `--save` overwrite an existing output without asking.
- Paths inside `--cmd` JSON (pictures, CSVs, templates) resolve against the current directory.
- For an MCP server, start it confined: `wordcraft-cli mcp --automation-read-root DIR
  --automation-write-root DIR`; a root left out grants no access of that kind.
- `--author NAME` labels comments and tracked changes; without it they say "WordCraft User".
- Use `file.privacyOptions={"removePersonalInfo":true}` before sharing a reviewed file externally.

## Gotchas
- `run` without `--save` exits 0 and discards every edit (side-effect commands like `file.exportPdf`
  or `mailings.finish={"path":…}` still write their files).
- One failing `--cmd` aborts the whole run with exit 1 and nothing is saved. Errors: `bad JSON params`
  (keys must be quoted), `` `text` (string) is required ``, `unknown command`.
- `--template` accepts only the built-in names. Any other value, even a real .docx/.dotx path, silently
  gives an empty document with exit 0. Use `file.newFromTemplate={"path":…}` for your own template;
  `file.saveTemplate={"path":"x.dotx"}` makes one.
- Table style names use an en dash: `Grid Table 4 – Blue`, `List Table 3 – Green`. `Table Grid` and
  `Plain Table 1` are plain ASCII. Word names like `Grid Table 4 Accent 1` fail.
- `"\n"` inside `text.insert` is a line break in the same paragraph. Use `text.newParagraph` between
  paragraphs, or `document.setText` (each `\n` there becomes a paragraph).
- Formatting commands (`para.heading1`, `format.bold`…) apply at the caret/selection; set the style
  before typing, and `select.text={"text":…}` to target existing words.
- `render --page` is 1-based; `--page 0` and pages past the end exit 1. Options take a space, not
  `=` (`--scale 1`, not `--scale=1`).
- `convert x.docx x.png` renders only page 1; use `render --page N` for others.
- `.md` export writes `![alt](image.png)` but not the image file itself; `.html` embeds images as
  base64, so prefer html (or keep the docx) when pictures matter.
- PDF is output-only: `convert x.pdf y.docx` fails with exit 1.
- Encrypted files make `info`/`text` exit 1; open them with `file.open={"path":…,"password":…}`.
- After `review.acceptAll`, `info` still reports `"trackChanges": true` (the mode stays on); check
  `file.inspect` `revisions` to confirm none are left.
- `text` shows the document as if changes were accepted; render or `convert --markup` to see redlines.

## References
- references/recipes.md: tested end-to-end recipes with expected output (convert, build, review,
  templates, merge, TOC/headers, page setup, encryption, exports). Read it before a multi-step job.
- references/commands.md: full command catalog (629 commands by group). Grep it for an id or param
  name when offline; ask `commands --json` for the unclipped spec.
