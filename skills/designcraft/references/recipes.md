# DesignCraft recipes (tested with designcraft-cli 0.10.0)

Every recipe below was run headless. Paths are relative to the working directory. All numbers are
points (72 pt = 1 in; 1 mm = 2.8346 pt).

## 1. Render the sample magazine (smoke test)

```bash
designcraft-cli run --sample --export sample.pdf --page 1 --export sample-p2.png --all-pages samplepng
```
Expected:
```
wrote sample.pdf (4 pages, 552552 bytes)
wrote sample-p2.png (630×810, …)          # --page is 0-based: this is page 2
wrote samplepng/page-001.png (630×810, …)
… page-004.png
```
630×810 = Letter (612×792) plus 9 pt bleed on each side at 1 px/pt. `--scale 2` doubles it.

## 2. New document from a preset, then inspect it

```bash
designcraft-cli run --cmd 'file.new={"preset":"Letter","pages":4,"facingPages":true}' --cmd document.inspect
```
Expected: `{"index":1}` then one JSON object with `pageCount: 4`, `parents: [{id, label:"A-Parent"}]`
and spreads `0: [page 1 (right)]`, `1: [page 2 (left, x 0–612), page 3 (right, x 612–1224)]`,
`2: [page 4 (left)]`. Margins default to 36 pt.

List presets: `designcraft-cli run --cmd file.presets` (Letter, Legal, Tabloid, Letter - Half, A0–A5, …;
sizes reported in points). Custom size: `file.new {"width":252,"height":144,"pages":1,"facingPages":false}`.

## 3. Styled brochure in one script (styles, parent folio with page number, image, body)

`brochure.dcs`:
```text
# 0: Letter, 4 facing pages
file.new {"preset":"Letter","pages":4,"facingPages":true,"title":"Brochure","margins":{"top":54,"bottom":54,"inside":54,"outside":36}}
# 1-2: styles
style.paragraph.create {"name":"Title","para":{"align":"center","spaceAfter":12},"chars":{"size":36,"fontStyle":"Bold"}}
style.paragraph.create {"name":"Body","para":{"firstLineIndent":12,"spaceAfter":6},"chars":{"size":11,"leading":{"kind":"points","value":15}}}
# 3: folio on A-Parent's left page;  is the current page number
frame.create {"spread":{"kind":"parent","index":0},"rect":[36,750,300,770],"content":"text","text":" · Spring Catalogue"}
# 4: headline on page 1, styled through a text selection
frame.create {"spread":0,"rect":[54,54,576,130],"content":"text","text":"Spring Catalogue"}
text.select {"story":"$4.story","anchor":0,"focus":16}
style.paragraph.apply {"name":"Title"}
# 7: body, styled by selecting the frame
frame.create {"spread":0,"rect":[54,400,576,738],"content":"text","text":"First paragraph of body copy.\nSecond paragraph."}
selection.set {"ids":["$7.id"]}
style.paragraph.apply {"name":"Body"}
# 10-12: image into a graphic frame, cropped to fill
frame.create {"spread":0,"rect":[54,140,576,390],"content":"graphic"}
file.place {"path":"photo.png","frame":"$last.id"}
object.fit {"mode":"fillProportionally","ids":["$10.id"]}
```
```bash
designcraft-cli script brochure.dcs --save brochure.designcraft --export brochure.pdf --export brochure.png
```
Expected: exit 0; JSON `{"completed": 13, "results": [{index}, {name:"Title"}, …, {id, story}, null, …,
{asset, id}, null]}` on stdout; the three files written silently (script prints no `wrote` lines).
The PNG is page 1 at 2× (1224×1584). Pages 2 and 4 show "2 · Spring Catalogue" / "4 · …" at the
bottom left; page 1 and 3 (right pages) do not, because the folio sits on the parent's left page.
For a folio on right pages add a second frame at x 612+.

## 4. Export matrix from a saved document

```bash
designcraft-cli run --in brochure.designcraft \
  --export plain.pdf \
  --pdf-options '{"pages":"2-3"}' --export p23.pdf \
  --export brochure.idml \
  --page 1 --scale 0.5 --export thumb.jpg
designcraft-cli run --in brochure.designcraft --all-pages pages \
  --pdf-options '{"marks":true,"bleed":true}' --export press.pdf
```
Expected:
```
wrote plain.pdf (4 pages, …)          MediaBox 612×792
wrote p23.pdf (2 pages, …)
wrote brochure.idml (… bytes)         # pages option still applies but IDML ignores it
wrote thumb.jpg (306×396, …)          # page 2 at half size
wrote pages/page-001.png … page-004.png (612×792 each)
wrote press.pdf (4 pages, …)          MediaBox 672×852 (crop marks area added)
```
Other `--export` extensions that work: `.epub`, `.pptx`, `.html`, `.jpg`, `.idml`, `.pdf`, `.png`.
All PDF options: `designcraft-cli describe file.exportPdf` (`standard: x4|a2b`, `tagged`, `spreads`,
`flatten`, `title`, `author`, …).

## 5. Long text autoflow and a second parent page

`flow.dcs`:
```text
file.new {"preset":"Letter","pages":1,"facingPages":false,"columns":2,"gutter":18}
file.place {"path":"story.txt","page":1,"rect":[36,36,576,756],"autoflow":true}
layout.parents.new {"prefix":"B","name":"Chapter"}
frame.create {"spread":{"kind":"parent","index":1},"rect":[36,760,576,780],"content":"text","text":"Chapter "}
layout.pages.applyParent {"pages":[1,2],"parent":"B"}
document.inspect {}
```
```bash
designcraft-cli script flow.dcs --save flow.designcraft
designcraft-cli run --in flow.designcraft --all-pages flowpng
```
Expected: step 1 returns `{"overset": false, "pagesAdded": 4, "story": 8, "warnings": []}`; one story
threaded through 8 frames. Page 1 keeps the single full-width `rect` frame; added pages get one frame
per column (2 columns). Parent B shows on pages 2–3 ("Chapter 2", "Chapter 3"); `pages` are 0-based.
`.md` input is placed as literal text (headings keep their `#`).

## 6. Edit an existing document: swatch, fill, text, character style, preflight, fonts

`color.dcs` (story 16 is the headline story from recipe 3; get ids from `document.inspect`):
```text
swatch.create {"name":"Brand Red","color":{"c":0,"m":90,"y":85,"k":0}}
frame.create {"spread":0,"rect":[0,0,612,40]}
object.fill {"swatch":"Brand Red","ids":["$1.id"]}
story.setText {"story":16,"text":"Replaced deck text"}
style.character.create {"name":"Accent","chars":{"fill":"Brand Red","fontStyle":"Italic"}}
text.select {"story":16,"anchor":0,"focus":8}
style.character.apply {"name":"Accent"}
preflight.run {}
font.list {}
```
```bash
designcraft-cli script color.dcs --in brochure.designcraft --save brochure2.designcraft --export brochure2.png
```
Expected: exit 0; a red band across the top, "Replaced" in red italic, rest of the headline bold.
`preflight.run` → `{"errors":0,"warnings":1,"issues":[{"kind":"lowResolution","message":"photo.png: effective 87 ppi (< 150)",…}]}`.
`font.list` → Source Serif 4 Regular/Italic/Bold, `source: "bundled"`, `missing: false`.
Passing a frame id where a story id is expected fails: `step 3 (story.setText) failed: no such story s13`.

## 7. Data merge: CSV to one card per record

`people.csv`:
```text
name,title
Ana Ruiz,Designer
Luis Gómez,Editor
Mia Chen,Printer
```
`merge.dcs` (use an absolute CSV path):
```text
file.new {"width":252,"height":144,"pages":1,"facingPages":false,"margins":18}
frame.create {"spread":0,"rect":[18,18,234,126],"content":"text","text":"Name: \nRole: "}
data.source.select {"path":"/abs/path/people.csv","name":"people.csv"}
# insert the later offset first: each placeholder adds text and shifts what follows
data.placeholder.add {"field":"title","story":"$1.story","at":13}
data.placeholder.add {"field":"name","story":"$1.story","at":6}
data.merge {}
file.save {"path":"cards.designcraft"}
```
```bash
designcraft-cli script merge.dcs --export cards.pdf
```
Expected: `data.source.select` → `{fields:[name,title], records:3, warnings:[]}`;
`data.merge` → `{records:3, pages:3, oversetStories:0, warnings:[]}`; the merged document becomes
active, so `cards.designcraft` and `cards.pdf` hold 3 pages ("Name: Luis Gómez / Role: Editor", …).
With a relative CSV path the merge warns "The data file is not read (the path is not valid). This merge
used the cached rows." Inserting placeholders front-to-back corrupts the second one.

## 8. IDML round trip

```bash
designcraft-cli run --in brochure.designcraft --export brochure.idml
designcraft-cli run --in brochure.idml --cmd document.inspect --export fromidml.pdf
```
Expected: `wrote brochure.idml`, then the inspect JSON (4 pages, same styles) and
`wrote fromidml.pdf (4 pages, …)`. `--in` also accepts `.indd`/`.indt` (converted to IDML; conversion
warnings join `warnings` of `file.open`).

## 9. Preflight and package for print

```bash
designcraft-cli run --in brochure.designcraft --cmd 'file.package={"dir":"brochure-pkg","pdf":true}'
```
Expected: `{"dir":"brochure-pkg","files":["brochure-pkg/Brochure.designcraft","brochure-pkg/Links/photo.png",
"brochure-pkg/Brochure.idml","brochure-pkg/Brochure.pdf","brochure-pkg/Instructions.txt"],"report":"Package report: …
Fonts … Links … Preflight: 1 issue(s) …"}`. Files are named after the document title (`file.new {"title":…}`),
and an existing folder is overwritten without a prompt.

## 10. Script from stdin plus EPUB / PPTX / HTML

```bash
echo 'file.exportHtml {"path":"sample.html"}' | designcraft-cli script - --sample --export sample.epub --export sample.pptx
```
Expected: JSON with `{"bytes": …, "path": "sample.html"}`, plus `sample.epub` and `sample.pptx` on disk.
`designcraft-cli run --sample --export sample.html` does the same for HTML.

## 11. Errors and exit codes

| Command | Output | Exit |
|---|---|---|
| `run --cmd nope.cmd` | `unknown command 'nope.cmd'` | 1 |
| `run --cmd 'file.new={bad'` | `--cmd file.new: key must be a string at line 1 column 2` | 1 |
| `run --in missing.designcraft …` | `No such file or directory` | 1 |
| `run --cmd 'file.new={"preset":"Tabloidzz"}'` | `unknown preset 'Tabloidzz'` | 1 |
| `run --cmd 'file.new={"preset":"A4","bogus":1}'` | `unknown parameter 'bogus'; the command takes: …` | 1 |
| `script bad.dcs` (step 1 `frame.create {"rect":[0,0,10]}`) | JSON `{completed:1, failedIndex:1, error:"… missing rect"}` + stderr | 1 |
| same with `--keep-going` | step result `{"command":"frame.create","error":"…"}`, later steps run | **0** |
| `run --sample --page 4 --export p.png` (4-page doc) | `no such page` | 1 |
