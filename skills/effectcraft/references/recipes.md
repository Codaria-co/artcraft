# EffectCraft recipes

Every recipe below was run against `effectcraft-cli 0.11.1` (headless, macOS). Commands assume
`effectcraft-cli` is on `PATH` and you are in a scratch directory. Expected output is abbreviated.

## 1. Build a 9:16 reel project in one call

```bash
effectcraft-cli --empty --save-as reel.ecproj run \
  comp.new '{"name":"Reel","width":1080,"height":1920,"frameRate":30,"duration":5,"background":"#101820"}' \
  layer.newSolid '{"name":"BG","color":"#1e3a5f"}' \
  layer.newText '{"text":"HELLO","size":160,"fill":"#ffffff"}' \
  layer.newShape '{"kind":"ellipse","name":"Dot","size":[300,300],"fill":"#ff5a36","position":[540,1400]}'
effectcraft-cli --project reel.ecproj info
```

Expected: one JSON object per command (`{"comp": 1}`, `{"layer": 4}`, ...), then `info` shows
`active comp 1 "Reel" 1080x1920 @ 30.0 fps, 5.0 s` with layers `#1 Dot`, `#2 HELLO`, `#3 BG`
(new layers stack on top). Text is centered in the comp by default. Shape `kind`: rect, rounded, ellipse,
star, polygon.

## 2. Keyframe a fade-in and a slide-up

```bash
effectcraft-cli --project reel.ecproj --save set Reel HELLO transform/opacity 0   --time 0
effectcraft-cli --project reel.ecproj --save set Reel HELLO transform/opacity 100 --time 1
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/position '[540,2200,0]' --time 0
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/position '[540,1400,0]' --time 1.5
effectcraft-cli --project reel.ecproj get Reel HELLO transform/opacity --time 0.5 --json
```

Expected: each `set` prints `{"result": {..."keys": [...]}, "saved": "reel.ecproj"}`. The `get` at 0.5 s
returns `"value": 50.0` (keys default to Linear). Property paths come from
`effectcraft-cli --project reel.ecproj props Reel HELLO --flat` (`transform/anchor|position|scale|rotation|opacity`,
`text/sourceText`, `effects/#n/<paramId>`, `contents/group/contents/fill/color` on shapes).

## 3. Easy ease the keys

```bash
effectcraft-cli --project reel.ecproj --save run \
  keys.select '{"keys":[{"layer":"Dot","path":"transform/position","time":0},{"layer":"Dot","path":"transform/position","time":1.5}]}' \
  keys.easyEase '{}'
effectcraft-cli --project reel.ecproj get Reel Dot transform/position --time 0.3 --json
```

Expected: keys become `Bezier`/`Bezier`; at 0.3 s the y value is 2116.8 instead of the linear 2040.
`keys.easyEase` acts on the selection, so both commands must run in the same `run` call.

## 4. Apply an effect and set a parameter

```bash
effectcraft-cli --project reel.ecproj exec effect.list --params '{"filter":"blur"}' --json   # names + param ids
effectcraft-cli --project reel.ecproj --save run effect.apply '{"effect":"Gaussian Blur","layers":["Dot"]}'
effectcraft-cli --project reel.ecproj --save set Reel Dot 'effects/#1/blurriness' 20
effectcraft-cli --project reel.ecproj --save run effect.apply '{"effect":"Glow","layers":["HELLO"]}'
```

Expected: `{"effect": "ec.blur.gaussian", "effects": [111], "paths": ["effects/#1"]}`. Use the returned
`paths` entry as the prefix for parameters. Effects can also be addressed by name in paths,
e.g. `effects/Glow/radius`.

## 5. Expression

```bash
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/rotation 0 --expression 'time*90'
effectcraft-cli --project reel.ecproj get Reel Dot transform/rotation --time 2 --json
```

Expected: `"expression": "time*90"`, `"value": 0.0` (the pre-expression value) and `"evaluated": 180.0`.

## 6. Preview frames

```bash
effectcraft-cli --project reel.ecproj render-frame --comp Reel --time 1.5 --max-side 960 --out f15.png
effectcraft-cli --project reel.ecproj render-frame --frame 10 --scale 0.25 --out f10.png
```

Expected: `rendered 540x960 at 1.500s in 33.3 ms -> f15.png` and a 270x480 PNG. Open the PNG to check
layout before rendering a movie; it costs milliseconds.

## 7. Render movies, GIFs and image sequences

```bash
effectcraft-cli --project reel.ecproj render --comp Reel --out reel-9x16.mp4 --start 0 --end 2
effectcraft-cli --project reel.ecproj render --comp Reel --out reel.webm --end 0.5 --resolution half
effectcraft-cli --project reel.ecproj render --comp Reel --out dot.gif --end 1 --resolution quarter --fps 15
effectcraft-cli --project reel.ecproj render --comp Reel --out seq/frame.png --format png --end 0.2
effectcraft-cli --project reel.ecproj render --comp Reel --out 'seq2/f_[####].png' --end 0.1
```

Expected, in order: `(1080×1920, 60 frames, H.264 ...)` in about 1.6 s; a 540x960 VP9 WebM;
`(270×480, 15 frames, Animated GIF)`; `seq/frame_00000.png` .. `frame_00005.png`; `seq2/f_0000.png` ..
`f_0002.png`. `--end` is exclusive. Missing output folders are created; existing files are overwritten.
Formats: h264, hevc, av1, prores, webm, png, jpeg, tiff, exr, gif, wav, aiff.

## 8. Transparent output

```bash
effectcraft-cli --empty --save-as alpha.ecproj run \
  comp.new '{"name":"A","width":400,"height":400,"duration":1}' \
  layer.newShape '{"kind":"star","fill":"#ffcc00"}'
effectcraft-cli --project alpha.ecproj render-frame --transparent --out a.png
effectcraft-cli --project alpha.ecproj render --out a.mov --format prores --channels rgba --end 0.2
```

Expected: `a.png` is RGBA; `a.mov` is ProRes with alpha. A comp with a full-frame solid still gives an
opaque RGB PNG even with `--transparent`. Note this comp got the default 29.97 fps (duration shows 1.001 s).

## 9. Build a comp with a JSX script (After Effects object model)

`build.jsx`:

```javascript
var comp = app.project.items.addComp("Promo", 1080, 1920, 1, 4, 30);
var bg = comp.layers.addSolid([0.06, 0.09, 0.13], "BG", 1080, 1920, 1);
var t = comp.layers.addText("SALE 50%");
var td = t.property("Source Text").value;
td.fontSize = 180; td.fillColor = [1, 0.8, 0.1];
t.property("Source Text").setValue(td);
var s = t.property("Transform").property("Scale");
s.setValueAtTime(0, [0, 0]);
s.setValueAtTime(0.6, [100, 100]);
t.property("Transform").property("Position").expression = "wiggle(2, 15)";
var fx = t.property("Effects").addProperty("Drop Shadow");
writeLn("layers: " + comp.numLayers + ", fx: " + fx.name);
comp.name;
```

```bash
effectcraft-cli --empty --save-as promo.ecproj script build.jsx
effectcraft-cli --project promo.ecproj render-frame --time 1 --max-side 640 --out promo1.png
```

Expected: prints `layers: 2, fx: Drop Shadow`, then the last expression's value `"Promo"`, then
`saved promo.ecproj`. `app.project.save(new File("promo.ecproj"))` inside the script also works.
Errors exit 1, e.g. `eval:1:1: ReferenceError: foo is not defined`.

## 10. JSX idioms: match names, shape groups, parenting, ease, slider-driven expression

`ae.jsx`:

```javascript
var c = app.project.items.addComp("Idioms", 1920, 1080, 1, 3, 30);
var n = c.layers.addNull(); n.name = "CTRL";
var sh = c.layers.addShape(); sh.name = "Box";
var g = sh.property("ADBE Root Vectors Group").addProperty("ADBE Vector Group");
g.property("ADBE Vectors Group").addProperty("ADBE Vector Shape - Rect").property("ADBE Vector Rect Size").setValue([400,200]);
g.property("ADBE Vectors Group").addProperty("ADBE Vector Graphic - Fill").property("ADBE Vector Fill Color").setValue([0.2,0.6,1]);
sh.parent = n;
var op = sh.property("ADBE Transform Group").property("ADBE Opacity");
op.setValueAtTime(0, 0); op.setValueAtTime(1, 100);
var e = new KeyframeEase(0, 75);
op.setTemporalEaseAtKey(1, [e], [e]); op.setTemporalEaseAtKey(2, [e], [e]);
var sl = n.Effects.addProperty("ADBE Slider Control"); sl.name = "Amount";
sl.property(1).setValue(45);
sh.transform.rotation.expression = 'thisComp.layer("CTRL").effect("Amount")("Slider")';
writeLn(op.numKeys + " keys; rot@1=" + sh.transform.rotation.valueAtTime(1, false));
```

```bash
effectcraft-cli --empty --save-as idioms.ecproj script ae.jsx
effectcraft-cli --project idioms.ecproj render-frame --time 2 --max-side 640 --out idioms.png
```

Expected: `2 keys; rot@1=45`, `saved idioms.ecproj`; the frame shows a blue rectangle rotated 45°.

## 11. Edit an existing project with a one-liner

```bash
effectcraft-cli --project promo.ecproj --save script --eval 'app.project.activeItem.layer(1).name = "Headline"'
```

Expected: prints `"Headline"` and `saved promo.ecproj`. Equivalent positional form:
`effectcraft-cli script --eval '...' promo.ecproj --save`.

## 12. Export and import Lottie

```bash
effectcraft-cli --project reel.ecproj exec file.exportLottie --params '{"comp":"Reel","path":"reel.json"}'
effectcraft-cli --project reel.ecproj exec file.exportLottie \
  --params '{"comp":"Reel","path":"reel.lottie","textAsShapes":true,"includeExpressions":true}'
effectcraft-cli --empty --save-as lot.ecproj exec file.importLottie --params '{"path":"reel.json"}'
```

Expected: `{"bytes": 2196, "path": "reel.json", "warnings": ["Dot ▸ Transform ▸ Rotation: expression not
exported ...", "HELLO ▸ Glow: effect not supported by Lottie (skipped)"]}`. The JSON is Lottie `v 5.12.0`,
`w 1080`, `h 1920`, `fr 30`. `.lottie` is a zip (dotLottie). Import returns the new comp id.

## 13. Template variants from a built-in template

```bash
effectcraft-cli --empty exec templates.list --json                      # ids + control names
effectcraft-cli --empty exec templates.create --params '{"id":"vertical-story","projectPath":"story.ecproj"}'
effectcraft-cli --project story.ecproj exec essential.exportTemplate --params '{"path":"story.ectemplate"}'
effectcraft-cli --empty exec essential.templateInfo --params '{"path":"story.ectemplate"}'
printf '%s' '{"Headline":"BIG\nNEWS","Call to Action":"Shop now"}' > v.json
effectcraft-cli render-frame --template story.ectemplate --values v.json --time 3 --max-side 640 --out story.png
effectcraft-cli render --template story.ectemplate --values v.json --out story-9x16.mp4 --end 3
```

Expected: `templateInfo` lists controls `Headline` (text) and `Call to Action` (text); the frame shows
"BIG / NEWS" in the card and "Shop now" below; the movie is `1080×1920, 90 frames`. Color controls take
`"#00c2a8"` or `[0,0.76,0.66]` (tested on `logo-reveal`'s `Logo Color`). A wrong key fails with exit 1:
`no control named `Nope` (controls: Headline, Call to Action)`. Loop over several values files to batch
variants.

## 14. Import footage into a comp

```bash
effectcraft-cli --project idioms.ecproj --save-as imp.ecproj run \
  file.import '{"paths":["f15.png"]}' \
  layer.addItem '{"item":"f15.png","index":1,"position":[300,300]}'
```

Expected: `{"items": [62], "errors": [], ...}` then `{"layer": 63}`; `info` lists `#1 Footage f15.png`.
