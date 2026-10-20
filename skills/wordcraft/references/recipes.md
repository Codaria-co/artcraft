# WordCraft recipes

Every recipe below was run against `wordcraft-cli 0.8.0`. Commands assume the working directory holds
the inputs; paths inside `--cmd` JSON resolve against it. Set `WORDCRAFT_REGION` whenever a new
document is created or md/html/txt is converted, so the paper size is reproducible.

## 1. Markdown to Word, then to everything else

```bash
export WORDCRAFT_REGION=en-US
wordcraft-cli convert in.md out.docx      # -> "wrote out.docx", exit 0
wordcraft-cli convert out.docx out.pdf
wordcraft-cli convert out.docx out.html   # images embedded as base64 data URIs
wordcraft-cli convert out.docx out.odt
wordcraft-cli convert out.docx out.rtf
wordcraft-cli convert out.docx out.tex    # \section*, tabular, itemize/enumerate
wordcraft-cli convert out.docx out.md
wordcraft-cli convert out.docx out.txt
wordcraft-cli convert out.docx out.json   # WordCraft's document model
wordcraft-cli convert out.docx flat.xml   # Word XML Document (Flat OPC)
wordcraft-cli convert out.docx w2003.xml --format wordml2003
```
Expected: Markdown `#`/`##` become Heading 1/Heading 2, `**bold**`/`*italic*` become runs, pipe tables
become Word tables, `-`/`1.` become bullet/numbered lists. Unsupported extension (e.g. `.xyz`) exits 1
with `can't save as '.xyz'`.

Reading back: html, odt, rtf, tex, Flat OPC and Word 2003 XML all convert to docx with exit 0.
`convert out.pdf x.docx` exits 1: `unsupported format '.pdf'`.

## 2. Read a document (no changes)

```bash
wordcraft-cli info out.docx
```
Expected JSON keys: `pages`, `words`, `paragraphs`, `sections`, `comments`, `trackChanges`,
`encrypted`, `properties{title,creator,created,modified,…}`.

```bash
wordcraft-cli text out.docx      # one line per paragraph; table cells tab-separated; bullets "•\t"
wordcraft-cli inspect out.docx   # {"blocks":[{"index","style":"Heading1","text","runs":[{start,end,props}]}, {"cells":[[…]]}…]}
```
Missing file: exit 1, `No such file or directory`.

## 3. Render pages to PNG

```bash
wordcraft-cli render out.docx p1.png                     # page 1, scale 2 -> 1224x1584 for Letter
wordcraft-cli render out.docx p1.png --page 1 --scale 1  # 612x792
```
Prints `{"bytes":…,"height":…,"path":"p1.png","width":…}`. `--page 0` exits 1 (pages start at 1);
`--page 9` on a 1-page doc exits 1 (`no page 9`); `--scale=1` exits 1 (use a space).
`convert out.docx page.png` also works but only renders page 1.

## 4. Paper size by region

```bash
WORDCRAFT_REGION=en-GB wordcraft-cli convert in.md a4.docx
WORDCRAFT_REGION=en-US wordcraft-cli convert in.md us.docx
wordcraft-cli render a4.docx a4.png --scale 1   # 596x842 (A4)
wordcraft-cli render us.docx us.png --scale 1   # 612x792 (Letter)
wordcraft-cli run --file a4.docx --cmd layout.section --print   # pageW 595.3, pageH 841.9, margins 72
```
An existing docx keeps its own page size: `a4.docx` converted to PDF under `en-US` still has
`MediaBox[0 0 595.3 841.9]`. Without the variable the locale decides (es_MX gave Letter).

## 5. Build a document from commands (headings, styles, table, image, comment, tracked change)

```bash
export WORDCRAFT_REGION=en-US
wordcraft-cli run --author "Ana Ruiz" \
 --cmd 'file.properties={"title":"Project Brief","author":"Ana Ruiz"}' \
 --cmd para.heading1 --cmd 'text.insert={"text":"Project Brief"}' --cmd text.newParagraph \
 --cmd para.normal --cmd 'text.insert={"text":"This brief explains the scope."}' --cmd text.newParagraph \
 --cmd 'para.style={"style":"Heading 2"}' --cmd 'text.insert={"text":"Budget"}' --cmd text.newParagraph \
 --cmd para.normal --cmd 'insert.table={"rows":3,"cols":2,"style":"Grid Table 4 – Blue"}' \
 --cmd 'text.insert={"text":"Item"}' --cmd caret.right --cmd 'text.insert={"text":"Cost"}' \
 --cmd caret.docEnd --cmd 'insert.picture={"path":"logo.png","width":144,"alt":"Logo"}' \
 --cmd 'select.text={"text":"scope"}' --cmd 'review.newComment={"text":"Define scope precisely"}' \
 --cmd 'review.trackChanges={"value":true}' \
 --cmd 'edit.replaceAll={"text":"brief explains","with":"document describes"}' \
 --save built.docx
```
Expected: `wrote built.docx`; `info` shows `"comments": 1`, `"trackChanges": true`,
`"title": "Project Brief"`. The render shows a blue header-row table, the picture, the comment anchor
highlighted and the replacement as a coloured insertion/strikethrough.
After `insert.table` the caret is in cell 1; `caret.right` moves to the next cell.

If any step fails (e.g. style `Grid Table 4 Accent 1`) the run exits 1 with
`insert.table: bad parameters: no table style …` and no file is written.
List valid names first:
```bash
wordcraft-cli run --cmd styles.manage --print   # `styles.manage: [{id,name,type:"paragraph|character|linked|table",…}]`
```
Table styles shipped: Table Grid, Grid Table 1 Light, Grid Table 4 – Blue/Green/Orange/Purple,
List Table 3 – Blue/Green/Orange/Purple, Plain Table 1.

## 6. Review output: markup PDF, comment list, inspection

```bash
wordcraft-cli convert built.docx review.pdf --markup   # balloons beside pages, redlines visible
wordcraft-cli convert built.docx review.md --markup    # ends with "## Comments" / "1. **Ana Ruiz** on “scope”: …"
wordcraft-cli run --file built.docx --cmd file.inspect --print
# file.inspect: {"found":{"comments":1,"revisions":1,"hiddenText":false,…},…}
wordcraft-cli run --file built.docx \
  --cmd 'file.exportPng={"path":"mk.png","markup":true,"scale":1}' \
  --cmd 'file.exportPdf={"path":"mk.pdf","markup":true}'   # no --save needed; mk.png is 828x792 (page + balloon column)
```

## 7. Accept everything and strip comments

```bash
wordcraft-cli run --file built.docx --cmd review.acceptAll \
  --cmd 'review.deleteComment={"all":true}' --save clean.docx
wordcraft-cli run --file clean.docx --cmd file.inspect --print   # comments 0, revisions 0
```
`info clean.docx` still says `"trackChanges": true` (the mode, not pending revisions).

## 8. Anonymise reviewers before sharing

```bash
wordcraft-cli run --file built.docx --cmd 'file.privacyOptions={"removePersonalInfo":true}' --save anon.docx
wordcraft-cli convert anon.docx anon.md --markup   # comment now by "Author"
```

## 9. Find and replace in an existing file

```bash
wordcraft-cli run --file out.docx --cmd 'edit.replaceAll={"text":"Revenue","with":"Income"}' --print --save replaced.docx
# edit.replaceAll: {"replaced":1}
```

## 10. Replace the whole body with plain paragraphs

```bash
wordcraft-cli run --cmd 'document.setText={"text":"A\nB\nC"}' --save set.docx   # info: "paragraphs": 3
```
By contrast `text.insert={"text":"line1\nline2"}` gives one paragraph with a line break.

## 11. Templates

```bash
wordcraft-cli run --template letter --save letter.docx   # also blank, sample, resume, report
wordcraft-cli text letter.docx                           # "Your Name / 123 Your Street … / Dear Recipient,"
wordcraft-cli run --cmd 'file.new={"template":"resume"}' --save resume.docx   # same thing via a command
wordcraft-cli run --file built.docx --cmd 'file.saveTemplate={"path":"brief.dotx"}'   # make a template
wordcraft-cli run --cmd 'file.newFromTemplate={"path":"brief.dotx"}' --save from-template.docx
```
Pitfall: `--template brief.dotx`, `--template built.docx` or `--template nope` all exit 0 and write an
empty document. `--template` only knows the built-in names.

## 12. Mail merge from CSV

```bash
printf 'Name,City\nAna,Bogota\nLuis,Cali\n' > people.csv
wordcraft-cli run --cmd 'mailings.start={"kind":"letters"}' \
 --cmd 'mailings.recipients={"path":"people.csv"}' \
 --cmd 'text.insert={"text":"Dear "}' --cmd 'mailings.insertField={"field":"Name"}' \
 --cmd 'text.insert={"text":", welcome to "}' --cmd 'mailings.insertField={"field":"City"}' \
 --cmd 'text.insert={"text":"."}' \
 --cmd 'mailings.finish={"path":"merged.docx"}' --save merge-main.docx --print
```
Expected: `mailings.recipients: {"fields":["Name","City"],"records":2}`,
`mailings.finish: {"path":"merged.docx","records":2}`. `merged.docx` has 2 pages:
"Dear Ana, welcome to Bogota." / "Dear Luis, welcome to Cali.". `merge-main.docx` keeps the fields
for reuse. Recipients can also be `.tsv`, `.xlsx`, `.xls`, `.ods`.

## 13. TOC, header, page-number footer, page size, margins, watermark

```bash
wordcraft-cli run --file out.docx --cmd caret.docStart \
 --cmd 'references.toc={"levels":2,"title":"Contents"}' \
 --cmd 'insert.footer={"preset":"pageNumber"}' --cmd 'insert.header={"text":"ACME Confidential"}' \
 --cmd 'layout.size={"name":"A4"}' --cmd 'layout.margins={"preset":"narrow"}' \
 --cmd 'design.watermark={"text":"DRAFT"}' --save toc.docx
wordcraft-cli render toc.docx toc.png --scale 1   # 596x842; header text, dotted TOC with page numbers, diagonal DRAFT, "1" in footer
```

## 14. Password protection

```bash
wordcraft-cli run --file out.docx --cmd 'file.encrypt={"password":"s3cret"}' --save enc.docx
wordcraft-cli info enc.docx      # exit 1: "this document is protected with a password"
wordcraft-cli run --cmd 'file.open={"path":"enc.docx","password":"s3cret"}' --cmd document.text --print
# file.open: {"encrypted":true,…}  document.text: {"text":"Quarterly Report\n…"}
```

## 15. Look up a command's parameters

```bash
wordcraft-cli commands | grep -i table           # id, label, shortcut, menu path
wordcraft-cli commands --json | python3 -c 'import sys,json;print([c for c in json.load(sys.stdin) if c["id"]=="insert.table"])'
# [{'id': 'insert.table', 'label': 'Table', 'location': 'Insert › Tables', 'mutates': True, 'params': '{"rows": n, "cols": n, "style"?: string}', …}]
```
Error shapes from `run`: unquoted keys -> `bad JSON params: key must be a string`; missing required ->
`` bad parameters: `text` (string) is required ``; wrong id -> `unknown command`. All exit 1.
