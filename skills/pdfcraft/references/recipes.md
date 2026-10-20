# PdfCraft recipes

Every recipe below was run with `pdfcraft-cli 0.9.0` on a 5-page test file (`in.pdf`, US Letter,
one heading and an SSN line per page). Results are what the CLI printed. Exit code is 0 unless noted.

## 1. Make a test PDF from text files
```bash
for i in 1 2 3 4 5; do printf "Page $i heading\nSecret SSN 123-45-678$i\n" > p$i.txt; done
pdfcraft-cli run doc_combine 'paths=["p1.txt","p2.txt","p3.txt","p4.txt","p5.txt"]' out=in.pdf
```
Result: `{"bytes": …, "path": "in.pdf"}`, 5 pages, one bookmark per source file.
(`pdfcraft-cli combine p1.txt …` fails: "not a PDF file". Only `doc_combine` converts.)

## 2. Inspect
```bash
pdfcraft-cli info in.pdf
```
Result: JSON with `pages: 5`, `first_page_pt: [612.0, 792.0]`, `page_labels`, `title`, `author`,
`encrypted`, `bookmarks`, `fields`, `annotations`, `pdf_version`, `warnings`.
Missing file → `No such file or directory`, exit 1.

## 3. Extract text
```bash
pdfcraft-cli text in.pdf              # pages separated by \f
pdfcraft-cli text in.pdf --page 3     # one page
pdfcraft-cli text in.pdf --page 9     # exit 1: "page 9 does not exist"
```

## 4. Render a page
```bash
pdfcraft-cli render in.pdf --page 2 --dpi 72 --out p2.png
```
Result: `rendered page 2 at 72 dpi: 612×792 px in 1 ms`. `.jpg`, `.tif`, `.pam` also work; `.webp`
is refused (exit 1). Without `--page` it renders page 1.

## 5. Reorganize pages in one pass
```bash
pdfcraft-cli edit in.pdf --out out.pdf --delete 2 --move 4:1 --rotate 1:90 --insert-blank 1 \
  --title "Sample Doc" --author "QA"
```
Result: silent, exit 0. Page order is `blank, 5 (rotated 90° clockwise), 1, 3, 4`: each option acts
on the result of the previous one. `info` shows the new title and author.
Variants checked: `--move 4,5:1` → `4 5 1 2 3`; `--move 1:5` → `2 3 4 5 1`; `--rotate 2-3:-90` ok;
`--rotate 1:45` → "rotation must be a multiple of 90 degrees"; `--delete 1-5` → "a document must
keep at least one page"; no `--out` → "missing --out" (all exit 1).

## 6. Combine, extract, split
```bash
pdfcraft-cli combine in.pdf out.pdf --out merged.pdf          # 10 pages, 2 bookmarks
pdfcraft-cli extract in.pdf --pages 5,1-2 --out picked.pdf    # pages 5,1,2 in that order
pdfcraft-cli split in.pdf --every 2 --out-dir parts           # prints parts/in-p1-2.pdf, in-p3-4.pdf, in-p5.pdf
pdfcraft-cli split in.pdf --before 3,5 --out-dir parts2       # same three files for this input
```
`split` without `--out-dir` writes to the current directory. Re-running it overwrites the parts.
`extract --pages 3-9` fails "page 6 does not exist"; `--pages 2-` fails "bad page number".

## 7. Batch convert + optimize a folder
```bash
pdfcraft-cli batch scans/ --steps convert,optimize --out-dir out --ppi 100 --quality 50
```
Result: JSON report `{"completed": 2, "failed": 0, "files": [{"output": ".../out/p1.pdf", "steps":
[{"step":"convert","bytes_before":75,"bytes_after":854}, …]}, …]}` for `scans/p1.txt` and
`scans/scan3.png`. Running it again writes `out/p1 (2).pdf` instead of replacing. Optimize keeps the
original bytes when the "optimized" copy would be larger. Steps must be unique with `convert` first;
`--out-dir` is required.

## 8. OCR (needs models)
```bash
pdfcraft-cli batch scans/ --steps convert,ocr --out-dir ocr_out
```
Result on a CLI-only install: every file `"status": "error"`, "the text recognition models are not
installed (reinstall PdfCraft, or set PDFCRAFT_MODELS to the folder that holds them)", exit 1,
no output folder. With the models present, add `--language en`, `--dpi 300`, `--ocr-all-pages`.

The desktop app bundles the models; borrowing them works (verified on macOS, exit 0):
```bash
PDFCRAFT_MODELS=/Applications/PdfCraft.app/Contents/Resources/models \
  pdfcraft-cli batch scans/ --steps convert,ocr --out-dir ocr_out
```

## 9. Set metadata, password-protect
```bash
cat > protect.json <<'EOF'
[
 {"tool":"doc_open","args":{"path":"in.pdf"}},
 {"tool":"doc_set_info","args":{"doc":1,"key":"Subject","value":"Quarterly sample"}},
 {"tool":"doc_protect","args":{"doc":1,"open_password":"s3cret","permissions_password":"owner1","printing":"high","copy":false}},
 {"tool":"doc_save","args":{"doc":1,"path":"locked.pdf"}}
]
EOF
pdfcraft-cli run --script protect.json
```
Result: one JSON object per step; `doc_protect` shows `"method": "AES, 256-bit"`, `copy: false`,
`modify: false`; `doc_save` shows `"incremental": false`. Then:
- `pdfcraft-cli info locked.pdf` → "the document is protected by a password", exit 1
- `info locked.pdf --password s3cret` → `"encrypted": true`, exit 0; wrong password → exit 1
- `text locked.pdf --password s3cret` → refused: permissions don't allow copying; pass the owner password
- `text locked.pdf --password owner1` → the text
- `render locked.pdf --password s3cret --out l.png` → works
- `edit locked.pdf --password owner1 --out l3.pdf --delete 1` → 4 pages, **still encrypted**
- `extract locked.pdf --password owner1 --pages 1 --out l4.pdf` → **not** encrypted

## 10. Remove a password
```bash
cat > unlock.json <<'EOF'
[
 {"tool":"doc_open","args":{"path":"locked.pdf","password":"owner1"}},
 {"tool":"doc_unprotect","args":{"doc":1}},
 {"tool":"doc_save","args":{"doc":1,"path":"unlocked.pdf"}}
]
EOF
pdfcraft-cli run --script unlock.json --report
```
Result: `{"ok": true, "steps": [… {"status": "ok", "tool": "doc_save", …}]}`;
`info unlocked.pdf` → `"encrypted": false`.

## 11. Redact for real, then verify
```bash
cat > redact.json <<'EOF'
[
 {"tool":"doc_open","args":{"path":"in.pdf"}},
 {"tool":"redact_mark","args":{"doc":1,"pattern":"ssn"}},
 {"tool":"redact_mark","args":{"doc":1,"find":"heading","overlay":"X"}},
 {"tool":"redact_apply","args":{"doc":1}},
 {"tool":"doc_save","args":{"doc":1,"path":"redacted.pdf"}}
]
EOF
pdfcraft-cli run --script redact.json --report
pdfcraft-cli audit redacted.pdf
```
Result: marks `5` + `5`, `redact_apply` → `"applied": 10`. `text redacted.pdf --page 1` shows
`Secret SSN ` with the number gone (the overlay text `X` is extractable text). Audit:
`{"count":0,"file":"redacted.pdf","findings":[]}`, exit 0.
Other `pattern` values: `phone`, `email`, `credit-card`, `date`; also `words: [...]`, `rect` + `page`,
`whole_pages: true`, `code_set: "foia"` with `codes`.

## 12. Catch a faux redaction
```bash
echo '[{"tool":"doc_open","args":{"path":"in.pdf"}},{"tool":"redact_mark","args":{"doc":1,"pattern":"ssn"}},{"tool":"doc_save","args":{"doc":1,"path":"marked.pdf"}}]' > mark.json
pdfcraft-cli run --script mark.json
pdfcraft-cli audit marked.pdf
```
Result: `{"count":5,…,"findings":[{"kind":"unapplied-mark","page":1,"covered_text":"Secret SSN
123-45-6781","rect":[132.5,101.7,194.9,112.7]}, …]}` and "audit: 5 faux redaction(s) found", **exit 1**.
Caveat: a black PNG placed over the text with `page_add_image` was *not* flagged (count 0).

## 13. Watermark, header/footer, find, export pages and text
```bash
cat > stamp.json <<'EOF'
[
 {"tool":"doc_open","args":{"path":"in.pdf"}},
 {"tool":"doc_set_info","args":{"doc":1,"key":"Title","value":"Stamped sample"}},
 {"tool":"doc_set_info","args":{"doc":1,"key":"Keywords","value":"draft, sample"}},
 {"tool":"doc_watermark","args":{"doc":1,"text":"DRAFT","opacity":0.3}},
 {"tool":"doc_header_footer","args":{"doc":1,"footer_center":"<<Page 1 of n>>","header_right":"ACME confidential"}},
 {"tool":"text_find","args":{"doc":1,"query":"page number 3"}},
 {"tool":"doc_export_images","args":{"doc":1,"folder":"pngs","pages":[1,3],"dpi":50}},
 {"tool":"doc_export_text","args":{"doc":1,"path":"all.txt"}},
 {"tool":"doc_save","args":{"doc":1,"path":"stamped.pdf"}},
 {"tool":"doc_info","args":{"doc":1}}
]
EOF
pdfcraft-cli run --script stamp.json --report
```
Result: pages show a grey diagonal DRAFT, "ACME confidential" top right, "Page 2 of 5" bottom
centre. `text_find` → `{"count":1,"matches":[{"page":3,"rects":[[106.8,87.9,180.8,98.9]]}]}`.
`doc_export_images` → `pngs/in_page_1.png`, `pngs/in_page_3.png` (also `format: "jpeg"|"tiff"`).
`doc_info` → `title: "Stamped sample"`, `keywords: "draft, sample"`. Other header/footer tokens:
`<<1>>`, `<<n>>`, `<<yyyy-mm-dd>>`, Bates `<<Bates Number#6#1#PREFIX#SUFFIX>>`.

## 14. Export to Word
```bash
echo '[{"tool":"doc_open","args":{"path":"in.pdf"}},{"tool":"doc_export_office","args":{"doc":1,"path":"in.docx"}}]' > office.json
pdfcraft-cli run --script office.json
```
Result: `{"bytes": 2327, "format": "docx", "path": "in.docx"}`; `.pptx`, `.html`, `.rtf` by extension.

## 15. Health-check a set of files
```bash
pdfcraft-cli check in.pdf locked.pdf --json check.json
```
Result: `checked 2 files: {"ok": 1, "open-error": 1}`; `check.json` lists per file `status`
(`ok`, `open-error:the-document-is-protected`), `pages`, `failed_pages`, `ms`. **Exit 0** even with
errors; non-PDF inputs are skipped without a message.

## 16. Confine paths with --root
```bash
pdfcraft-cli run doc_combine 'paths=["in.pdf","in.pdf"]' out=c.pdf --root jail
```
Result: reads `jail/in.pdf`, writes `jail/c.pdf`. `paths=["../in.pdf",…]` → "is outside the allowed
directory", exit 1. Array args must be JSON: `paths=a.pdf,b.pdf` → "paths must be an array of strings".

## 17. Failing script behaviour
```bash
echo '[{"tool":"doc_open","args":{"path":"in.pdf"}},{"tool":"page_delete","args":{"doc":1,"pages":[9]}},{"tool":"doc_save","args":{"doc":1,"path":"never.pdf"}}]' > bad.json
pdfcraft-cli run --script bad.json --report
```
Result: step 2 `"status": "error"` ("page 9 is out of range: the document has 5 pages"), step 3
`"skipped"`, no file written, exit 1.
