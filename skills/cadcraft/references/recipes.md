# cadcraft-cli recipes

Every recipe below was run against `cadcraft-cli 0.8.0`. "Expect" is what the run printed or what
`info`/`entities` showed afterwards. Run them in an empty working directory.

## 1. Sample drawings to test with

```bash
cadcraft-cli sample bracket bracket.dxf
cadcraft-cli sample floorplan floor.dxf
cadcraft-cli sample bracket bracket.svg     # also .dwg .png; .pdf works too
```
Expect: `wrote bracket.dxf (41194 bytes)`, exit 0. The bracket is an imperial (inch) mechanical part
with 46 entities on layers Outline, Center, Hidden, Dimensions, Hatch, Notes, Title; the floorplan
has 16 entities. Existing output files are overwritten.

## 2. Inspect a drawing

```bash
cadcraft-cli info bracket.dxf
cadcraft-cli info bracket.dxf | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["counts"],d["extents"],[l["name"] for l in d["layers"]])'
```
Expect JSON with `counts` (`{"Circle": 7, "Dimension": 6, "Hatch": 4, "Line": 16, "MText": 1,
"Polyline": 6, "Text": 6}`), `entityCount` 46, `extents` `[[-0.5,-0.5],[18.0,7.5]]`, `layers`
(name, color, linetype, on/frozen/locked), `linetypes`, `textStyles`, `dimStyles`, `layouts`,
`view`. A DWG gives the same. An empty drawing gives `"counts": {}` and `"extents": null`.

## 3. Convert DXF <-> DWG and render SVG/PNG/PDF

```bash
cadcraft-cli convert bracket.dxf bracket.dwg     # DWG AutoCAD 2018
cadcraft-cli convert bracket.dwg back.dxf        # round trip, same counts
cadcraft-cli convert bracket.dxf bracket.svg
cadcraft-cli convert bracket.dxf bracket.png     # 2400x1600 RGBA, dark background
cadcraft-cli convert bracket.dxf bracket.pdf     # 1 page, model space
```
Expect `wrote <file> (<n> bytes)`, exit 0 each. `convert` fits the drawing extents.

## 4. Frame an export: window, extents, current view

```bash
cadcraft-cli convert bracket.dxf detail.png --window 0,0,6,4   # lower-left quarter, zoomed in
cadcraft-cli convert bracket.dxf view.png --view current       # extents + 10% margin on a fresh file
```
Expect: detail.png shows only the region 0..6 x 0..4 drawing units, scaled to fill 2400x1600.
Errors (exit 1, nothing written):
- `--window 5,5,1,1` gives `--window: need x0 < x1 and y0 < y1 (lower-left corner first), got 5,5,1,1`
- `convert bracket.dxf x.jpg` gives ``unsupported file type `jpg` ``
- missing input gives ``invalid parameters for `open`: nope.dxf: No such file or directory``

## 5. Script (.scr) drawing: layers, rectangle, circles, dimensions, text

```bash
cat > plate.scr <<'EOF'
-LAYER M Outline C 7 Outline 
RECTANG 0,0 120,80
-LAYER M Holes C 1 Holes 
CIRCLE 20,20 6
CIRCLE 100,20 6
CIRCLE 100,60 6
CIRCLE 20,60 6
-LAYER M Dims C 4 Dims 
DIMLINEAR 0,0 120,0 60,-15
DIMLINEAR 0,0 0,80 -15,40
-LAYER M Notes C 3 Notes 
TEXT 0,95 5 0 PLATE 120x80

ZOOM E
EOF
cadcraft-cli run --metric --script-file plate.scr --save plate.dxf --export plate.png
cadcraft-cli info plate.dxf
```
Notes on the syntax: each `-LAYER` line ends with a space (Enter that closes LAYER) and has NO blank
line after it; `TEXT` is followed by exactly one blank line to end text entry.
Expect stderr log `Command: LAYER ... Dimension text = 120 ... Command: ZOOM`, then
`wrote plate.dxf`, `wrote plate.png`, exit 0. `info`: counts `{"Circle": 4, "Dimension": 2,
"Polyline": 1, "Text": 1}`, layers Outline (White), Holes (Red), Dims (Cyan), Notes (Green), current
layer Notes. The PNG shows the plate with readable `120` and `80` dimensions.

Without `--metric` the same script gives dimension text 0.18 units high (unreadable on a 120-unit
part) and labels `120.0000`.

What goes wrong if you add a blank line after `-LAYER ...`: the blank line repeats LAYER, every
following line prints `Invalid option keyword.`, the drawing ends up empty, and it still exits 0.

## 6. Inline script with relative/polar coordinates and justified text

```bash
printf '; comment line\nLINE 0,0 @100,0 @50<90 \nPLINE 0,0 10,0 10,10 C\nTEXT J MC 50,50 10 0 Mid\n\n' > rel.scr
cadcraft-cli run --metric --script-file rel.scr --save rel.dxf
cadcraft-cli run rel.dxf --cmd 'entities {"type":"Line"}'
```
Expect: `;` comment lines are skipped; two lines (0,0)-(100,0) and (100,0)-(100,50); a closed
3-vertex polyline; text "Mid" with halign center, valign middle.
Inline equivalent: `cadcraft-cli run --script $'LINE 0,0 100,0 100,50 0,50 C\nCIRCLE 50,25 10\n' --save s1.dxf`
gives 4 lines + 1 circle.

## 7. JSON commands: layers, rectangle, text, dimension, hatch, DWG + SVG out

```bash
cadcraft-cli run --metric \
  --cmd 'layer.new {"name":"Walls","color":"red","current":true}' \
  --cmd 'rectang {"p1":[0,0],"p2":[4000,3000]}' \
  --cmd 'text {"at":[0,3300],"text":"ROOM A","height":200}' \
  --cmd 'dimlinear {"p1":[0,0],"p2":[4000,0],"at":[2000,-500]}' \
  --cmd 'hatch {"points":[[2000,1500]],"pattern":"ANSI31","scale":20}' \
  --save room.dwg --export room.svg
```
Expect stdout `{"handle":"100"}` ... `{"handle":"103","handles":["103"]}`, then `wrote room.dwg`,
`wrote room.svg`, exit 0. `info room.dwg`: Polyline 1, Text 1, Dimension 1, Hatch 1; layer Walls Red.
`layer.new` itself prints nothing. Reading room.dwg back shows current layer `0` (DWG save drops
CLAYER; save DXF if that matters).

## 8. Edit an existing drawing and save a revision

```bash
cadcraft-cli run floor.dxf --script $'-LAYER M Furniture C 5 Furniture \nCIRCLE 100,100 15\n' \
  --cmd 'text {"at":[10,250],"text":"REV B","height":10}' \
  --save floor-revB.dxf --export floor-revB.pdf
```
Expect `wrote floor-revB.dxf`, `wrote floor-revB.pdf`, exit 0; counts go from Circle 1 / Text 2 to
Circle 2 / Text 3. floor.dxf is untouched.

## 9. Query, measure, move and erase by handle

```bash
cadcraft-cli run plate-m.dxf --cmd 'entities {"layer":"Holes"}'           # handles 101..104
cadcraft-cli run plate-m.dxf --cmd 'move {"handles":["101","102","103","104"],"delta":[5,0]}' \
  --cmd 'erase {"handles":["101"]}' --save plate-edit.dxf
cadcraft-cli run room.dwg --cmd 'area {"handle":"100"}'
cadcraft-cli run rel.dxf --cmd 'dist {"p1":[0,0],"p2":[3,4]}'
cadcraft-cli run plate.dxf --cmd 'getvar {"name":"DIMTXT"}'
```
(plate-m.dxf is recipe 5 saved as plate-m.dxf.) Expect `{"moved":4}`, `{"erased":1}` and 3 circles
left; area `{"area":12000000.0,"perimeter":14000.0,...}`; dist `{"distance":5.0,"angle":53.13...}`;
getvar `{"name":"DIMTXT","value":2.5}` for a metric drawing (0.18 imperial).
`entities` takes `type`, `layer`, `window`, `limit`, `offset` and returns
`{count, returned, entities:[{handle, type, layer, color, geometry}]}`. `list {}` returns
`{"message":""}` headless; use `entities` instead.

## 10. Export a zoomed view from `run`

```bash
cadcraft-cli run bracket.dxf --script $'ZOOM W 0,0 6,4\n' --export zs.png
cadcraft-cli run bracket.dxf --cmd 'view.set {"center":[3,2],"height":4}' --export vs.png
cadcraft-cli run bracket.dxf --cmd 'zoom {"mode":"window","p1":[0,0],"p2":[6,4]}' --cmd 'view.get {}'
```
Expect zs.png and vs.png to be byte-identical to recipe 4's detail.png; view.get returns
`{"center":[3.0,2.0],"height":4.0,...}`. Pass `--view extents` to ignore the zoom.
Broken: `--cmd 'zoom.window {"p1":[0,0],"p2":[6,4]}'` exits 0 but leaves the view at extents
(`view.get` shows center [8.75,3.5]), so the export is the full drawing.

## 11. Older DWG version

```bash
cadcraft-cli run --metric --cmd 'circle {"center":[0,0],"radius":5}' \
  --cmd 'saveas {"path":"v2000.dwg","version":2000}'
```
Expect `{"binary":false,"bytes":...,"path":"v2000.dwg","version":"2000"}`; `file v2000.dwg` reports
AutoCAD 2000. Versions: 2000, 2004, 2007, 2010, 2013, 2018.

## 12. Order of operations and error handling

```bash
cadcraft-cli run --metric --cmd 'entities {}' --script $'CIRCLE 50,0 5\n'     # count 0: cmd ran first
cadcraft-cli run --script $'CIRCLE 1,1 1\n' --script $'CIRCLE 2,2 1\n' --cmd 'entities {}'   # count 2
cadcraft-cli run --cmd 'circle {"center":[0,0]}' --save bad.dxf   # exit 1, bad.dxf not written
cadcraft-cli run --script 'FOOBAR 1,2' --save bs.dxf              # exit 1, unknown command `FOOBAR`
cadcraft-cli run --cmd 'line {points:1}'                          # exit 1, key must be a string
cadcraft-cli run --script $'CIRCLE 0,0 abc\n' --save inv.dxf      # exit 0! saved empty drawing
cadcraft-cli run part.dxf --metric --save out.dxf                 # exit 0! part.dxf dropped, empty out.dxf
```
Steps run in command-line order. A failing `--cmd` or unknown script command aborts with nothing
saved; a bad answer inside a script command only prints a message and carries on. FILE / `--sample`
/ `--metric`: the last one wins.

## 13. Find a command's parameters

```bash
cadcraft-cli commands dimlinear | python3 -c 'import json,sys;[print(c["id"],"|",c["params"]) for c in json.load(sys.stdin)]'
```
Expect `dimlinear | {p1, p2, at, rotation? (degrees; default: horizontal/vertical from `at`), text?} | {object: hex, at} (associative)`.
`cadcraft-cli commands` with no filter lists all 426. The filter also matches other fields, so
`commands erase` returns several commands; select by `id`.
