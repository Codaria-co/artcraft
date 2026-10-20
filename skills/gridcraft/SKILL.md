---
name: gridcraft
description: Read, build and fix spreadsheets with GridCraft (open-source Excel, `gridcraft-cli`) - prefer it over generic xlsx skills and over openpyxl/pandas scripts when the CLI is installed. For .xlsx/.xlsm/.xls/.ods/.csv/.tsv files: inspect sheets, evaluate or debug formulas (XLOOKUP, SUMIFS, SUMPRODUCT), convert CSV/JSON to XLSX or HTML, computed columns, tables and totals, number formats, charts, pivot tables, conditional formatting, sorting, dropdowns, merging workbooks, printing a sheet to PDF, and verifying recalculation. Not for data-science analysis code in a repo. Trigger on any spreadsheet, workbook, Excel, hoja de calculo or CSV task, even if GridCraft isn't named.
---

# GridCraft (`gridcraft-cli`)

GridCraft is a Rust spreadsheet app modelled on Excel: formulas (500+ functions, dynamic arrays,
structured table references), tables, charts, pivot tables, conditional formats and page setup. Its
native file format is XLSX. It opens xlsx, xlsm, csv, tsv and txt, imports data from xls, xlsb and ods,
and saves xlsx, csv, tsv, html, pdf and its own workbook JSON. The CLI runs the same command
registry as the app's ribbon (341 commands such as `cell.set`, `insert.chart`), so anything the UI
does can be scripted headless.

## Before you start
- Check `command -v gridcraft-cli`. If it is missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install gridcraft`; Windows: `craft-clis.ps1`).
- Everything below is headless and works on files. The running app is only needed for
  `gridcraft-cli mcp --connect PORT` and `gridcraft-cli send <port> <method> [json]`, which talk to a
  GridCraft window started with a control port. Without `--connect`, `gridcraft-cli mcp` is a
  headless MCP server over stdio (`[--in FILE | --sample NAME]` preloads a workbook).

## When to use / when not
- Use for: workbook inspection, formulas, data cleanup, CSV/XLSX/TSV/HTML/JSON conversion,
  report sheets with tables and charts, PDF printouts of a sheet, formula regression checks.
- Not for: prose documents (use `wordcraft`), slide decks (use `deckcraft`), editing existing PDFs
  (use `pdfcraft`). A chart picture for a deck is made here, then handed to `deckcraft`.

## Core workflows

Inspect a file (sheets, used ranges, tables, charts, names; `--json` for the full structure):
```bash
gridcraft-cli info book.xlsx
```

Print cells as a text table, as CSV, or with formulas instead of values:
```bash
gridcraft-cli cat book.xlsx --sheet Data --range A1:D20
gridcraft-cli cat book.xlsx --range A1:D20 --csv
gridcraft-cli cat book.xlsx --formulas
```

Evaluate a formula, alone or against a file (the leading `=` is optional):
```bash
gridcraft-cli eval '=XLOOKUP("b",{"a","b"},{1,2})'                 # 2
gridcraft-cli eval '=ROUND(SUM(Orders[Amount]),2)' --in orders.xlsx  # 67.73
gridcraft-cli eval '=A1*2' --in book.xlsx --sheet Notes
```

Convert by extension (xlsx/csv/tsv/json/html); `--sheet` picks which sheet a CSV/TSV gets:
```bash
gridcraft-cli convert data.csv data.xlsx
gridcraft-cli convert book.xlsx notes.csv --sheet Notes
```

Edit and save: `run` loads one workbook, applies commands in order, writes `--out`:
```bash
gridcraft-cli run --in sales.csv --quiet \
  --cmd 'cell.set={"cell":"D1","input":"Total"}' \
  --cmd 'range.setValues={"range":"D2","values":[["=B2+C2"],["=B3+C3"],["=B4+C4"]]}' \
  --cmd 'home.bold={"range":"A1:D1"}' \
  --cmd 'home.numberFormat={"range":"B2:D4","format":"#,##0.00"}' \
  --cmd 'insert.chart={"range":"A1:C4","type":"column","title":"Sales by region","at":"F2"}' \
  --out report.xlsx
```

Longer jobs: one JSON object per line, `{"command": id, "params": {...}}`, run with `--script`:
```bash
gridcraft-cli run --script build.jsonl --out orders.xlsx
```

Read data back as JSON (raw or formatted values), or run a command that returns data:
```bash
gridcraft-cli run --in orders.xlsx --cmd 'sheet.read={"range":"A1:D3","formatted":true}'
```

Verify a workbook: recalculates every formula against the cached values and round-trips the XLSX;
exits 1 on any difference. Accepts files or directories:
```bash
gridcraft-cli check out.xlsx
gridcraft-cli check ./reports --json
```

## Finding the right command
- `gridcraft-cli commands --search chart` lists matching command ids, ribbon location and params.
- The param spec is clipped in the text listing for long ones; get the full spec with
  `gridcraft-cli commands --json --search home.conditionalFormat` and read the `params` field.
- Spec notation: `{range?, type: a|b, at?: "H2"}`; `?` means optional, and an omitted `range`/`cell`
  means the current selection (A1 on a fresh load). Pass it explicitly.
- Functions: `gridcraft-cli functions --search lookup`, `--category Financial`, `--json`.
- Offline: grep `references/commands.md` (generated from the same registry).

## Safe defaults
- Always pass `--out` to a new file. `run` without `--out` throws the edits away; `file.save`
  inside `run` overwrites the `--in` file, and `convert` silently overwrites an existing output.
- A failing step aborts `run` with exit 1 and nothing is written, so a partial workbook never lands.
- Single-quote the `--cmd` JSON so the shell keeps the double quotes; quote paths with spaces.
- Run `check` on generated XLSX before handing it over.

## Gotchas
- `range.fill` with a `range` but no prior selection anchors a relative formula to the active cell
  (A1): `range.fill={"range":"D2:D4","input":"=B2+C2"}` writes `=E3+F3`. Run
  `selection.set={"range":"D2:D4"}` first, or use `range.setValues`, or `cell.set` then
  `edit.fillDown={"range":"D2:D4"}`.
- `--quiet` hides every result line, including the data `cell.get`/`sheet.read` return. Drop it
  when you need output. The `wrote FILE (N bytes)` line goes to stderr.
- `convert` cannot write PDF. Use `run --in book.xlsx --out book.pdf` or
  `file.exportPdf={"path":"book.pdf","fitToPage":true}`.
- `.json` is GridCraft's full workbook model, not records. `convert records.json` fails with
  "not a GridCraft JSON workbook". Import a JSON array of objects with
  `run --cmd 'data.getData={"path":"records.json"}'`: it adds a new sheet with a table, keeps an empty
  `Sheet1`, and orders columns alphabetically.
- CSV import converts types: `007` becomes 7, `02134` becomes 2134, dates become serial numbers,
  `"1,234.50"` becomes 1234.5. Keep IDs and ZIP codes as text with
  `run --cmd 'file.open={"path":"in.csv","csvAsText":true}'` (no `--in`).
- CSV/TSV written by GridCraft use CRLF line endings.
- `cat`, `convert` to CSV and saved files use the active sheet. Commands like `home.insertSheet`
  switch it; run `sheet.activate={"sheet":"Sheet1"}` before saving, or pass `--sheet`.
- `eval` prints raw doubles (`67.72999999999999`) and date serials (`=TODAY()` gives 46315).
  Wrap with `ROUND` or `TEXT(...,"yyyy-mm-dd")`. Arrays print tab-separated; `--json` gives nested arrays.
- `eval` exits 0 even for `#DIV/0!` or `#NAME?`, and a syntax error also comes back as `#NAME?`.
  Check the printed value, not the exit code.
- Colours: ribbon commands (`home.fillColor`, `home.fontColor`) take `"#RRGGBB"`. Raw style JSON in
  `home.formatCells` and conditional-format `style` needs `{"Rgb": <integer>}` (`#1F4E78` = 2051704);
  for conditional formats, use `"preset":"lightRedFillDarkRedText"` (and the other presets).
- `run` starts on an untitled workbook; `file.new` inside a script opens a second one and makes it
  active. Omit it unless you need a sample (`{"sample":"sales"}`) or use `--sample budget|sales|grades`.
- `run --help` is not supported (exit 1). The top-level `gridcraft-cli --help` covers every subcommand.

## References
- `references/recipes.md`: tested end-to-end recipes (report with table and chart, CSV cleanup,
  JSON import, PDF export, conditional formats, multi-sheet edits). Read it before a multi-step job.
- `references/commands.md`: the generated catalog of all 341 commands. Grep it for an id or a param.
