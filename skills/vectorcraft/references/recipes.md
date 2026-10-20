# VectorCraft recipes

Every recipe below was run against `vectorcraft-cli 0.13.1` on macOS. Commands are relative to the
working folder; quote paths with spaces. "→" shows the observed result.

Conventions that apply to all recipes:

- Coordinates and sizes in command params are **points, y down**, origin at the first artboard's top-left,
  whatever the document's units.
- `run` prints one JSON line per step; `convert` prints one JSON object
  `{"bytes","format","path","warnings"}`. Exit 0 = success, 1 = any error (nothing exported).

---

## 1. Inspect a file

```bash
vectorcraft-cli info logo.svg
```

→ JSON with `artboards` (`[{name, rect:[x,y,w,h]}]` in pt), `info.units`, `info.colorMode`, `kinds`
(`{"Layer":1,"Path":2,"Type":1}`), `fonts` (`status: exact|substitute|missing`, `resolved` = the
font actually drawn), `warnings` (what the import left out). Use it before and after every conversion.

## 2. Format conversion matrix

```bash
vectorcraft-cli convert logo.svg logo.pdf
vectorcraft-cli convert logo.svg logo.ai      # PDF-compatible .ai (default)
vectorcraft-cli convert logo.svg logo.eps
vectorcraft-cli convert logo.svg logo.dxf
vectorcraft-cli convert logo.svg logo.emf
vectorcraft-cli convert logo.svg logo.psd     # layered raster
vectorcraft-cli convert logo.svg logo.svgz
vectorcraft-cli convert logo.svg logo.jpg     # flattened on white
vectorcraft-cli convert logo.svg logo.webp    # lossless only
vectorcraft-cli convert logo.svg logo.tif
```

→ each exits 0 and prints e.g. `{"bytes":10372,"format":"pdf","path":"logo.pdf","warnings":[]}`.

Reverse direction (AI/EPS/PDF/DXF/EMF/PSD → SVG) also exits 0:

```bash
vectorcraft-cli convert logo.ai logo.svg
vectorcraft-cli convert logo.eps logo.svg
vectorcraft-cli convert logo.pdf logo.svg
```

→ AI, EPS and PDF round-trip with live `<text>` kept; DXF/EMF/PSD come back as paths/images.
Unknown output extension → exit 1, `unknown extension '.xyz': pass 'format'`.

## 3. Raster export at a given size

```bash
vectorcraft-cli convert logo.svg logo@2x.png --scale 2
```

→ a 400×300 pt document gives an 800×600 PNG with a transparent background. `--scale` is pixels
per point. For a coloured background or a ppi value, use `document.export`:

```bash
vectorcraft-cli run --in logo.svg --cmd document.export --params '{"path":"logo-white.png","background":"white"}'
```

→ opaque PNG on white. Other keys: `ppi` (wins over `scale`), `quality` (jpg), `antiAlias`.

## 4. One artboard, or a page range

```bash
vectorcraft-cli convert sheet.vectorcraft hex.png --artboard 1      # 0-based: second artboard
vectorcraft-cli convert sheet.vectorcraft pages.pdf --range 2-3     # 1-based: 2-page PDF
vectorcraft-cli convert sheet.vectorcraft all.pdf                   # every artboard, one page each
```

→ `hex.png` is the 200×200 second artboard only. `pages.pdf` has 2 pages and warns
`Preserve editing was left out: it needs a PDF of every artboard`. Without `--artboard`, SVG/PNG/JPG get
only the first artboard. `--artboard 5` on a 3-artboard file → exit 1 `no artboard 5 (0-based; the document has 3)`.

## 5. Every artboard to its own file

```bash
vectorcraft-cli run --in sheet.vectorcraft \
  --cmd document.export --params '{"path":"ab.png","useArtboards":true,"scale":2}'
```

→ `ab-star.png ab-hex.png ab-dot.png` (suffix = artboard name).

## 6. Icon/asset set (Export for Screens)

```bash
mkdir -p screens
vectorcraft-cli run --in sheet.vectorcraft --cmd document.exportForScreens --params \
  '{"folder":"screens","formats":[{"format":"png","scale":1},{"format":"png","scale":"2x"},{"format":"svg"}]}'
```

→ `screens/star.png star@2x.png star.svg hex.png hex@2x.png hex.svg dot.png ...`, one set per artboard,
named after the artboard. `"preset":"mobile"` instead of `formats` gives
`1x/star.png 2x/star@2x.png 3x/star@3x.png ...` in sub-folders. Create the folder first.

## 7. Outline text

SVG only (convert flag):

```bash
vectorcraft-cli convert logo.svg logo-outlined.svg --outline-text
```

→ no `<text>` elements left; glyphs are paths.

PDF/AI or any format (outline in the document, then export):

```bash
vectorcraft-cli run --in logo.svg --cmd select.object.textObjects --cmd type.createOutlines \
  --export logo-outlined.pdf --export logo-outlined.ai
```

→ `type.createOutlines` returns `{"ids":[...]}`; `info logo-outlined.pdf` shows no `Type` and empty `fonts`.

Alternative for PDF only: `--cmd document.exportPdf --params '{"path":"x.pdf","advanced":{"outlineText":true},"preserveEditing":false}'`.

## 8. Print PDF (PDF/X-4, lean deliverable)

```bash
vectorcraft-cli run --in logo.svg --cmd document.exportPdf --params '{"path":"logo-x4.pdf","standard":"pdfX4"}'
vectorcraft-cli run --in logo.svg --cmd document.exportPdf --params '{"path":"logo-lean.pdf","preserveEditing":false}'
```

→ both exit 0. The PDF/X-4 embeds the CMYK output intent (~130 KB for a tiny logo). The lean PDF is
~4.8 KB vs ~10.5 KB with the default preset, which embeds the native document for re-editing.
Other keys: `bleed`, `marks`, `compatibility`, `security`, `createLayers` (see `commands.md`).

## 9. Build artwork from commands (shapes + text)

```bash
vectorcraft-cli run --cmd file.new --params '{"width":400,"height":300,"units":"Pixels"}' \
  --cmd shape.rectangle --params '{"x":20,"y":20,"width":160,"height":100,"radius":12}' \
  --cmd paint.setFill --params '{"color":"#e63946"}' \
  --cmd shape.ellipse --params '{"x":220,"y":40,"width":120,"height":120}' \
  --cmd paint.setFill --params '{"color":"#457b9d"}' \
  --cmd text.create --params '{"x":30,"y":220,"text":"Hello Vector","size":36,"color":"#1d3557"}' \
  --export logo.svg --export logo.pdf --export logo.png --export logo.vectorcraft
```

→ ids 2, 3, 4; `text.create` also returns its `bounds` (top at y=184: `y` is the baseline). Shapes keep
the default 1 pt black stroke unless you add `--cmd paint.setStroke --params '{"none":true}'`.
Other shapes: `shape.polygon {cx,cy,radius,sides}`, `shape.star {cx,cy,radius1,radius2,points}`,
`shape.line {x1,y1,x2,y2}`, `shape.arc`, `shape.spiral`.

Print sizes: `file.new` accepts unit strings, shapes do not:

```bash
vectorcraft-cli run --cmd file.new --params '{"width":"85 mm","height":"55 mm","units":"Millimeters"}' \
  --cmd shape.rectangle --params '{"x":28.35,"y":28.35,"width":141.73,"height":56.69}' --export card.pdf
```

→ 240.945×155.906 pt artboard; the rectangle is 10 mm in, 50×20 mm (mm × 2.8346 = pt).
`{"x":"10 mm"}` on a shape → exit 1 `missing number 'x'`.

## 10. Multi-artboard document

```bash
vectorcraft-cli run --cmd file.new --params '{"width":200,"height":200,"artboards":3,"units":"Points"}' \
  --cmd shape.star --params '{"cx":100,"cy":100,"radius1":80,"radius2":35}' \
  --cmd shape.polygon --params '{"cx":320,"cy":100,"radius":80,"sides":6}' \
  --cmd shape.ellipse --params '{"x":470,"y":30,"width":140,"height":140}' \
  --cmd artboard.setProps --params '{"index":0,"name":"star"}' \
  --cmd artboard.setProps --params '{"index":1,"name":"hex"}' \
  --cmd artboard.setProps --params '{"index":2,"name":"dot"}' \
  --export sheet.vectorcraft
```

→ artboards at x = 0, 220, 440 (20 pt gap), so artboard N's art goes at x + 220·N.
`artboard.new {x,y,width,height,name}` adds more; `artboard.fitToArt` shrinks them to the art.

## 11. Pathfinder icon, centred on the artboard

```bash
vectorcraft-cli run --cmd file.new --params '{"width":256,"height":256,"units":"Pixels"}' \
  --cmd shape.ellipse --params '{"x":28,"y":28,"width":200,"height":200}' \
  --cmd shape.rectangle --params '{"x":98,"y":0,"width":60,"height":256}' \
  --cmd select.all --cmd object.pathfinder.minusFront \
  --cmd paint.setFill --params '{"color":"#2a9d8f"}' --cmd paint.setStroke --params '{"none":true}' \
  --cmd object.align --params '{"horizontal":"center","vertical":"center","to":"artboard"}' \
  --export icon.svg --export icon.png --scale 4
```

→ one compound path (circle split in two halves); `icon.png` is 1024×1024. `--scale` applies to every
raster `--export` of the run. Also `unite`, `intersect`, `exclude`, `divide`, `trim`, `merge`, `crop`.

## 12. Edit text in an existing file

Find the id first (ids are per session; there is no variable passing between `run` steps):

```bash
vectorcraft-cli run --in logo.vectorcraft --cmd document.find --params '{"kind":"Type"}'
```

→ `{"matches":[{"id":4,"kind":"Type","name":"Hello Vector","path":[1]}],"total":1}`. Then:

```bash
vectorcraft-cli run --in logo.vectorcraft \
  --cmd text.setText --params '{"id":4,"text":"Bonjour"}' \
  --cmd text.setStyle --params '{"id":4,"font":"Source Serif 4","size":40}' \
  --export logo-fr.svg
```

→ `<text ... font-family="'Source Serif 4'" font-size="40">Bonjour</text>`. `document.find` also takes
`text` (substring of content) and `name`. To act on all text without ids, use
`--cmd select.object.textObjects` and omit `id`. List font family names with `--cmd text.fontList`.

Check fonts afterwards: an unknown family is accepted silently and drawn in the fallback.

```bash
vectorcraft-cli info logo-fr.svg     # fonts[].status must be "exact"
```

## 13. Trace a raster image into vectors

```bash
vectorcraft-cli run --in logo.png --cmd select.all \
  --cmd imageTrace.makeAndExpand --params '{"preset":"6 Colors"}' --export traced.svg
```

→ `{"anchors":121,"colors":4,"id":28,"paths":17}`; `traced.svg` has 17 `<path>`s and no `<image>`.
Presets: Default, Auto Color, High Fidelity Photo, Low Fidelity Photo, 3 Colors, 6 Colors, 16 Colors,
Shades of Gray, Black and White Logo, Sketched Art, Silhouettes, Line Art, Technical Drawing, Outline,
Flat Logo (`--cmd imageTrace.presets` lists them with params).

## 14. DXF for cutters/CAD

```bash
vectorcraft-cli run --in card.svg --cmd document.exportDxf --params '{"path":"card.dxf","unit":"mm"}'
vectorcraft-cli run --cmd file.new --cmd document.dxfInfo --params '{"path":"card.dxf"}'
```

→ DXF 2018 in Millimeters, layers `["0","Layer 1"]`. `version` (R12…2018) and `scale` are also options.

## 15. Legacy Illustrator 7 .ai

```bash
vectorcraft-cli convert sheet.vectorcraft legacy.ai --ai-version 7
```

→ `legacy-star.ai legacy-hex.ai legacy-dot.ai` (one per artboard) plus warnings that v7 keeps only
layers, groups, compound paths, clipping, type, colours, gradients and images.
