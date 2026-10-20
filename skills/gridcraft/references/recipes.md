# gridcraft-cli recipes

Every recipe here was run against `gridcraft-cli 0.9.0`. The sample input used throughout:

```bash
printf 'Region,Q1,Q2\nEast,100,150\nWest,200,250\nNorth,50,75\n' > sales.csv
```

## 1. Inspect an unknown workbook

```bash
gridcraft-cli info sample_sales.xlsx
gridcraft-cli info sample_sales.xlsx --json   # sheets[].usedRange, tables, charts, freeze, names
```
Result:
```text
sample_sales.xlsx
* Sales: used B2:I17, 67 cells
    table Sales B4:I11 (TableStyleMedium2)
    chart ColumnClustered "Revenue by Region" at K3, 4 series
    chart Pie "Share of Annual Total" at K19, 1 series
```
`*` marks the active sheet. Then `cat --range` on the used range.

## 2. Print a range as text, CSV, or formulas

```bash
gridcraft-cli cat sales.csv
gridcraft-cli cat sales.csv --range A1:B3 --csv
gridcraft-cli cat orders.xlsx --formulas
```
Result (`--csv`):
```text
Region,Q1
East,100
West,200
```
`--formulas` shows `=B2*C2` and `=SUBTOTAL(109,Orders[Amount])` where the plain view shows values.
An unknown `--sheet` exits 1: `no sheet named 'Nope'`.

## 3. Evaluate formulas

```bash
gridcraft-cli eval '=SUM(B2:C4)' --in sales.csv                  # 825
gridcraft-cli eval '=VLOOKUP("West",A2:C4,3,FALSE)' --in sales.csv # 250
gridcraft-cli eval '=ROUND(SUM(Orders[Amount]),2)' --in orders.xlsx # 67.73
gridcraft-cli eval '=TEXT(TODAY(),"yyyy-mm-dd")'                   # 2026-10-20
gridcraft-cli eval '=SEQUENCE(2,2)' --json                         # [[1.0,2.0],[3.0,4.0]]
gridcraft-cli eval '=ROW()' --cell C7                              # 7
```
Errors (`#DIV/0!`, `#NAME?`) print as values with exit 0.

## 4. Convert between formats

```bash
gridcraft-cli convert sales.csv sales.xlsx     # wrote sales.xlsx (4138 bytes)
gridcraft-cli convert sales.xlsx sales.tsv
gridcraft-cli convert sales.xlsx sales.html    # standalone <table> page
gridcraft-cli convert sales.xlsx sales.json    # GridCraft workbook model (sheets, styles, theme)
gridcraft-cli convert sales.json back.csv      # round-trips; output uses CRLF
gridcraft-cli convert multi.xlsx notes.csv --sheet Notes
```
`convert x.xlsx x.pdf` fails (exit 1, `unknown output format`). See recipe 9.

## 5. Add a computed column, format it, add a chart

```bash
gridcraft-cli run --in sales.csv --quiet \
  --cmd 'range.setValues={"range":"D1","values":[["Total"],["=B2+C2"],["=B3+C3"],["=B4+C4"]]}' \
  --cmd 'home.bold={"range":"A1:D1"}' \
  --cmd 'home.fillColor={"range":"A1:D1","color":"#DDEBF7"}' \
  --cmd 'home.numberFormat={"range":"B2:D4","format":"#,##0.00"}' \
  --cmd 'insert.chart={"range":"A1:C4","type":"column","title":"Sales by region","at":"F2"}' \
  --out report.xlsx
gridcraft-cli cat report.xlsx
```
Result: D2:D4 = 250, 450, 125, and `info` lists `chart ColumnClustered "Sales by region" at F2, 2 series`.

Same column with a fill instead of explicit rows. Select first, because `range.fill` anchors relative
references to the active cell:
```bash
gridcraft-cli run --in sales.csv --quiet \
  --cmd 'selection.set={"range":"D2:D4"}' \
  --cmd 'range.fill={"range":"D2:D4","input":"=B2+C2"}' --print D1:D4
# or: --cmd 'cell.set={"cell":"D2","input":"=B2+C2"}' --cmd 'edit.fillDown={"range":"D2:D4"}'
```
Without the `selection.set`, D2 gets `=E3+F3` (all zeros).

## 6. Build a workbook from a JSONL script (table, total row, currency, pie chart)

`build.jsonl`:
```json
{"command":"range.setValues","params":{"range":"A1","values":[["Item","Qty","Price","Amount"],["Pens",10,1.5,"=B2*C2"],["Paper",3,4.25,"=B3*C3"],["Ink",2,19.99,"=B4*C4"]]}}
{"command":"insert.table","params":{"range":"A1:D4","name":"Orders","style":"TableStyleMedium2"}}
{"command":"table.totalRow","params":{"table":"Orders","on":true}}
{"command":"home.numberFormat","params":{"range":"C2:D5","format":"Currency"}}
{"command":"insert.chart","params":{"range":"A1:A4,D1:D4","type":"pie","title":"Spend","at":"F2"}}
```
```bash
gridcraft-cli run --script build.jsonl --out orders.xlsx
gridcraft-cli cat orders.xlsx
```
Result:
```text
Item   Qty  Price   Amount
Pens    10   $1.50  $15.00
Paper    3   $4.25  $12.75
Ink      2  $19.99  $39.98
Total               $67.73
```
The total row formula is `=SUBTOTAL(109,Orders[Amount])`. Without `--quiet`, each command that returns
something prints one JSON line (`{"command":"insert.chart","result":{"chart":2}}`).

## 7. Chart with options (line with markers, legend, axis title, labels)

```bash
gridcraft-cli run --in sales.csv \
  --cmd 'insert.chart={"range":"A1:C4","type":"line","subtype":"markers","title":"Trend","at":"E2"}' \
  --cmd 'chart.set={"legend":"bottom","yTitle":"Units","dataLabels":true}' \
  --out line.xlsx
```
Result: `chart LineMarkers "Trend" at E2, 2 series`. `chart.set` without `chart` targets the chart just inserted.

## 8. Keep IDs, ZIP codes and dates as text when reading CSV

```bash
printf 'id,zip,date,pct,amt\n007,02134,2024-03-05,12%%,"1,234.50"\n' > quirks.csv
gridcraft-cli cat quirks.csv            # id 7, zip 2134: leading zeros lost
gridcraft-cli run --quiet --cmd 'file.open={"path":"quirks.csv","csvAsText":true}' --out quirks_text.xlsx
gridcraft-cli cat quirks_text.xlsx      # 007  02134  2024-03-05  12%  1,234.50
```
Do not combine with `--in`; `file.open` is the load step.

## 9. Export a sheet to PDF

```bash
gridcraft-cli run --in orders.xlsx --quiet --cmd 'file.exportPdf={"path":"orders.pdf","fitToPage":true}'
gridcraft-cli run --in orders.xlsx --quiet --out orders_out.pdf
```
Both write a `%PDF-1.7` file of the active sheet (`"sheets":"all"` for every sheet).

## 10. Import a JSON array of records

```bash
echo '[{"name":"a","n":1},{"name":"b","n":2}]' > recs.json
gridcraft-cli run --cmd 'data.getData={"path":"recs.json"}' --out recs.xlsx
gridcraft-cli cat recs.xlsx
```
Result: new sheet `recs` with table `Table1`, columns `n  name` (alphabetical, not source order), plus
an empty `Sheet1`. `convert recs.json ...` fails because `.json` means the workbook model.

## 11. Read values back as JSON

```bash
gridcraft-cli run --in orders.xlsx --cmd 'sheet.read={"range":"A1:D3","formatted":true}'
gridcraft-cli run --in orders.xlsx --cmd 'selection.set={"range":"D2:D4"}' --cmd 'selection.stats'
gridcraft-cli run --in quirks.csv --cmd 'cell.get={"cell":"C2"}'
```
Result: `{"values":[["Item","Qty","Price","Amount"],["Pens","10","$1.50","$15.00"],...]}`;
stats `{"count":3,"sum":67.72999999999999,...}`; `cell.get` returns value, type, text, num_fmt and style.
Do not pass `--quiet` here; it suppresses these lines.

## 12. Sort, conditional format, freeze header, column widths

```bash
gridcraft-cli run --in sales.csv --quiet \
  --cmd 'data.sort={"range":"A1:C4","header":true,"keys":[{"column":"B","order":"desc"}]}' \
  --print A1:C4
gridcraft-cli run --in sales.csv --quiet \
  --cmd 'home.conditionalFormat={"range":"B2:C4","rule":{"type":"cellIs","operator":"greaterThan","value":"100","preset":"lightRedFillDarkRedText"}}' \
  --cmd 'view.freezeTopRow' \
  --cmd 'home.columnWidth={"cols":"A:A","chars":20}' \
  --out cf.xlsx
```
Result: sorted West, East, North; `info --json` shows `"conditionalFormats": 1` and `"freeze": [1, 0]`.
`{"type":"colorScale"}` alone also works. A hex string in a rule `style` fails
(`unknown variant '#FFC7CE', expected one of 'Auto', 'Rgb', 'Theme'`); use a preset or `{"Rgb": <int>}`.

## 13. Raw style JSON (font colour, solid fill, number format at once)

```bash
gridcraft-cli run --in sales.csv \
  --cmd 'home.formatCells={"range":"A1:C1","style":{"font":{"bold":true,"color":{"Rgb":16777215}},"fill":{"pattern":"Solid","fg":{"Rgb":2051704}}}}' \
  --out fmt.xlsx
```
`Rgb` is the integer of `0xRRGGBB` (`#1F4E78` = 2051704, white = 16777215).

## 14. Add a sheet that references another sheet and a table

```bash
gridcraft-cli run --in orders.xlsx --quiet \
  --cmd 'home.insertSheet={"name":"Notes"}' \
  --cmd 'cell.set={"sheet":"Notes","cell":"A1","input":"=SUM(Sheet1!B2:B4)"}' \
  --cmd 'cell.set={"sheet":"Notes","cell":"A2","input":"=SUM(Orders[Qty])"}' \
  --cmd 'sheet.activate={"sheet":"Sheet1"}' \
  --out multi.xlsx
gridcraft-cli cat multi.xlsx --sheet Notes   # 15 / 15
```
Without the `sheet.activate`, the new sheet stays active, and plain `cat`/`convert` use it.

## 15. Look up functions and commands

```bash
gridcraft-cli functions --search xlookup
gridcraft-cli functions --category Financial
gridcraft-cli commands --search chart
gridcraft-cli commands --json --search home.conditionalFormat   # full, unclipped params spec
```
Result: `XLOOKUP(lookup_value, lookup_array, return_array, [if_not_found], [match_mode], [search_mode])`;
514 functions in total.

## 16. Verify generated workbooks

```bash
gridcraft-cli check report.xlsx orders.xlsx
gridcraft-cli check . --json
```
Result: per file `formulas N: N checked, N matched, 0 mismatched` and `round trip: all equal`, then a
summary table. Exit 0 when clean; exit 1 on any formula mismatch or round-trip difference. A directory
argument checks the XLSX files in it. A file whose cached D2 was edited to 999 gives exit 1 and:
```text
  formulas 4: 4 checked, 3 matched, 1 mismatched, 0 no oracle, 0 volatile
  mismatch Sheet1!D2  =B2*C2  expected 999  got 15  [(no function)]
```
Use it on third-party XLSX files to see whether GridCraft computes them the way Excel cached them.

## 17. Start from a built-in sample

```bash
gridcraft-cli run --sample budget --quiet --out sample_budget.xlsx
```
Samples: `budget`, `sales`, `grades`. An unknown name exits 1 (`unknown sample`).

## Exit codes seen

| Situation | Exit |
|---|---|
| success (`info`, `cat`, `convert`, `run`, `check` clean) | 0 |
| `eval` returning `#DIV/0!` / `#NAME?` | 0 |
| missing input file, unknown output extension, unknown sheet | 1 |
| unknown command id, bad JSON, missing required param in `run` (nothing written) | 1 |
| `run --help` | 1 |
