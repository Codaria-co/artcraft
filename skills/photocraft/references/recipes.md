# PhotoCraft recipes

Every recipe below was run against `photocraft-cli 0.10.0` (headless). `X=photocraft-cli`.
Results show the JSON lines `run` prints on stdout; warnings go to stderr.

## 1. Make a test image from scratch

```bash
$X run --new '{"width":800,"height":600,"background":"#3366cc"}' \
  --cmd select.rect --params '{"x":100,"y":100,"width":300,"height":200}' \
  --cmd edit.fill --params '{"contents":"color","color":"#ffcc00"}' \
  --cmd select.deselect --out sample.png
```
Result: 800x600 RGB PNG, blue with a yellow rectangle. `--new` keys: `width`, `height`, `mode`
(rgb|gray|cmyk|lab), `depth` (8|16|32), `background` (white|black|transparent|#rrggbb).

## 2. Inspect a document

```bash
$X info layered.psd --compact | python3 -c 'import json,sys; d=json.load(sys.stdin)
for l in d["layers"]: print(l["id"], l["kind"], l["name"], l["bounds"])'
```
Result (top layer first): `4 Pixel Overlay [450, 80, 250, 250]`, `3 Type Title [...]`,
`2 Pixel Background [0, 0, 800, 600]`. Also `width`, `height`, `mode`, `depth`, `resolution`,
`activeLayer`, `warnings`.

## 3. Convert formats

```bash
$X convert sample.png sample.jpg --quality 85        # warning: lossy compression
$X convert sample.png sample.psd
$X convert sample.png sample.webp                    # lossless WebP
$X convert sample.png out.bin --format webp --quality 70   # lossy WebP, format forced
$X convert layered.psd layered.tif --tiff-layers     # TIFF keeping 3 layers
$X convert layered.psd layered.pcraft                # native, keeps layers
$X convert layered.psd flat.png                      # warning: 3 layer(s) flattened
```
Also written OK: `.exr`, `.gif` (quantized to 256 colors), `.bmp`, `.tif`. Unknown extension:
`error: unknown file format: xyz`, exit 1.

## 4. Resize, fit, crop, canvas, rotate

```bash
$X run in.png --cmd image.imageSize --params '{"width":400}' --out w400.png          # 400x300, aspect kept
$X run in.png --cmd image.imageSize --params '{"percent":25}' --out q.png            # 200x150
$X run in.png --cmd file.automate.fitImage --params '{"width":300,"height":300}' --out fit.png   # 300x225
$X run in.png --cmd image.crop --params '{"x":400,"y":50,"width":350,"height":300}' --out crop.png   # 350x300
$X run in.png --cmd image.canvasSize --params '{"width":40,"height":40,"relative":true,"extensionColor":"#000000"}' --out border.png  # 840x640, 20 px black border
$X run in.png --cmd image.imageRotation.90cw --out rot.png                           # 600x800
$X run in.png --cmd image.imageRotation.flipCanvasHorizontal --out flip.png
```
Arbitrary angle: `image.rotation.arbitrary {"angle":12.5,"direction":"cw"}`. Change ppi only:
`image.imageSize {"resolution":300}` (pixels stay 800x600, `info` shows 300.0).

## 5. Adjustments and filters (destructive)

```bash
$X run in.png \
  --cmd image.adjustments.brightnessContrast --params '{"brightness":30,"contrast":20}' \
  --cmd image.adjustments.hueSaturation --params '{"saturation":-40}' \
  --cmd filter.blur.gaussianBlur --params '{"radius":3}' \
  --cmd filter.sharpen.unsharpMask --params '{"amount":80,"radius":1.5}' \
  --out adjusted.jpg --quality 90
$X run in.png --cmd image.adjustments.desaturate --out bw.png      # still RGB
$X run in.png --cmd image.mode.grayscale --out gray.png            # 8-bit grayscale PNG
$X run in.png --cmd image.autoTone --out autotone.png
```
On a layered file these hit the active (top) layer only; see recipe 7.

## 6. Non-destructive grading with adjustment layers

```bash
$X run layered.psd \
  --cmd layer.newAdjustmentLayer.curves --params '{"points":[[0,0],[64,40],[192,220],[255,255]]}' \
  --cmd layer.newAdjustmentLayer.hueSaturation --params '{"saturation":-30}' \
  --out graded.psd
```
Result: two `Adjustment` layers (Curves, Hue/Saturation) on top of the stack; the PSD keeps them editable.

## 7. Target the right layer

```bash
# Only the top layer gets blurred (the PSD opens with it active):
$X run layered.psd --cmd filter.blur.gaussianBlur --params '{"radius":10}' --out top-only.png
# Whole image:
$X run layered.psd --cmd layer.flattenImage --cmd filter.blur.gaussianBlur --params '{"radius":10}' --out all.png
```
Each filter result names the `layer` id it touched. Select by name with
`layer.select {"name":"Title"}` (error and exit 1 if the name doesn't exist).

## 8. Layered composition: text, new layer, shape

```bash
$X run sample.png \
  --cmd type.create --params '{"x":420,"y":450,"text":"Hello PhotoCraft","size":48,"color":"#ffffff","font":"Helvetica","name":"Title"}' \
  --cmd layer.new.layer --params '{"name":"Overlay"}' \
  --cmd select.rect --params '{"x":450,"y":80,"width":250,"height":250,"ellipse":true}' \
  --cmd edit.fill --params '{"color":"#ff3366"}' \
  --cmd select.deselect --out layered.psd
```
Result: PSD with Background, Type layer "Title" (x,y = baseline start), pixel layer "Overlay" with a pink
circle. `type.create` returns `{"bounds":[x0,y0,x1,y1],"layer":3}`.

## 9. Fill a PSD template: replace text, add shadow, set opacity/blend

```bash
$X run layered.psd \
  --cmd layer.select --params '{"name":"Title"}' \
  --cmd type.edit --params '{"text":"Sale 50% off"}' \
  --cmd layer.layerStyle.dropShadow --params '{"color":"#000000","distance":4,"size":6,"opacity":60}' \
  --cmd layer.setProps --params '{"layer":4,"opacity":0.5,"blend":"Multiply"}' \
  --out edited.psd
```
Result: text replaced (font, size, color kept), drop shadow on the Title layer, Overlay at 50% Multiply.
`type.setStyle` changes font/size/color/tracking of type layers.

## 10. Social card from scratch

```bash
$X run --new '{"width":1080,"height":1080}' \
  --cmd layer.newFillLayer.gradient --params '{"from":"#1e3c72","to":"#2a5298","angle":90,"style":"linear"}' \
  --cmd type.create --params '{"box":[90,400,900,300],"text":"Summer Launch\nJune 21","align":"center","size":96,"color":"#ffffff","font":"Helvetica","fontStyle":"Bold"}' \
  --out card.png
```
Result: 1080x1080 gradient (`from` at bottom, `to` at top) with two bold centered lines. `box` makes
paragraph text that wraps and aligns inside `[x,y,w,h]`.

## 11. Watermark with a logo

```bash
$X run --new '{"width":200,"height":80,"background":"transparent"}' \
  --cmd type.create --params '{"x":10,"y":55,"text":"(c) ACME","size":36,"color":"#ffffff"}' --out logo.png
$X run photo.png \
  --cmd file.placeEmbedded --params '{"path":"logo.png","center":[680,550],"smartObject":false}' \
  --cmd layer.setProps --params '{"opacity":0.7}' \
  --out watermarked.jpg --quality 90
```
Result: logo placed as a new layer centred at (680,550), 70% opacity, flattened into the JPEG.
`placeEmbedded` returns `bounds` as `[x0,y0,x1,y1]`.

## 12. Remove background and trim

```bash
$X run photo.png --cmd layer.removeBackground --out cutout.png    # RGBA, background transparent
$X run cutout.png --cmd image.trim --out trimmed.png               # crops to opaque pixels (600x250 here)
```
`removeBackground` adds a mask from Select Subject. `select.subject` alone gives a
selection to copy, fill or mask.

## 13. Export each layer to its own file

```bash
mkdir -p layers
$X run edited.psd --cmd file.export.layersToFiles --params '{"dir":"layers","format":"png"}'
```
Result: `layers/edited_0000_Overlay.png`, `edited_0001_Title.png`, `edited_0002_Background.png`, each
full-canvas (RGBA for non-background layers). No `--out` needed: the command writes the files. For JPEG
use `"format":"jpg","quality":10` (0..12 scale).

## 14. Batch a folder

```bash
echo '[["file.automate.fitImage",{"width":400,"height":400}],["image.adjustments.hueSaturation",{"saturation":-100}],"layer.flattenImage"]' > actions.json
$X batch --actions actions.json --in in --out out --format jpg --quality 80
```
Output:
```
ok    in/a.png -> out/a.jpg
ok    in/b.jpg -> out/b.jpg
ok    in/c.psd -> out/c.jpg
3 succeeded, 0 failed
```
Without `--format` each file keeps its format. Non-images (e.g. `notes.txt`) are skipped silently.
A bad file prints `FAIL  in2/bad.png: codec: unrecognized image format`, the others still finish, exit 1.
`--out` equal to `--in` is refused unless `--in-place`. Subfolders are not visited.

## 15. Recursive batch and web export (Image Processor)

```bash
$X run --new '{"width":1,"height":1}' --cmd file.scripts.imageProcessor --params \
  '{"input":"photos","includeSubfolders":true,"output":"web","format":"jpg","quality":9,"width":256,"height":256,"convertToSrgb":true}'
# → {"files":["web/y.jpg","web/sub/x.jpg"],"errors":[]}   (fit inside 256x256, never enlarged)

$X run --new '{"width":1,"height":1}' --cmd file.automate.batch --params \
  '{"steps":[["image.adjustments.invert",{}]],"input":"photos","includeSubfolders":true,"output":"inv","format":"png","naming":"inv-{serial}"}'
# → {"files":["inv/inv-001.png","inv/sub/inv-002.png"],"errors":[]}
```
These commands don't need a document, but `run` needs one open, hence the 1x1 `--new` (no `--out`, so
it's discarded). Subfolder structure is kept under the output.

## 16. CMYK / print

```bash
$X run in.png --cmd image.mode.cmyk --out print.tif     # info: mode Cmyk, depth 8
$X run in.png --cmd image.imageSize --params '{"resolution":300}' --out print300.tif
```
Default profile is "PhotoCraft Coated CMYK (synthetic …)"; pass `"profile":"/path/to/press.icc"` for a
real press profile. JPEG also accepts CMYK (4 components).

## 17. Headless session over stdio (JSON lines)

```bash
printf '%s\n' \
  '{"id":1,"method":"doc.open","params":{"path":"sample.png"}}' \
  '{"id":2,"method":"engine.execute","params":{"command":"image.imageSize","params":{"width":100}}}' \
  '{"id":3,"method":"doc.save","params":{"path":"small.png"}}' \
| $X serve --automation-read-root . --automation-write-root .
```
Replies: `{"id":1,"ok":true,"result":{"width":800,...}}`, `{"id":2,...{"width":100,"height":75}}`,
`{"id":3,"ok":true,"result":{"path":"small.png",...}}`. A path like `../escape.png` is refused:
`automation path rejected: parent traversal is not allowed`. `{"method":"methods"}` lists all methods.
Use this (or `mcp` with the same root flags) when many edits on one document would otherwise reopen the
file on every `run`.
