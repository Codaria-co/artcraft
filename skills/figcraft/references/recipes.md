# figcraft-cli recipes

Every recipe below was run against `figcraft-cli 0.8.0` (headless, no app). Paths are relative to
the working directory. Result lines are abbreviated where marked `…`.

## 1. Build a mobile screen with auto layout and a component

`screen.json`:
```json
[
  {"command": "frame.create", "params": {"preset": "iPhone 16", "x": 0, "y": 0, "name": "Home"}},
  {"command": "node.set", "params": {"id": {"$step": 0}, "fill": "#F5F5F7", "layout": "vertical", "padding": 24, "gap": 16}},
  {"command": "text.create", "params": {"text": "Welcome back", "x": 0, "y": 0, "parent": {"$step": 0}, "props": {"fontSize": 32, "fontStyle": "Bold"}}},
  {"command": "node.create", "params": {"type": "frame", "name": "Card", "parent": {"$step": 0}, "width": 345, "height": 120,
    "props": {"fill": "#FFFFFF", "cornerRadius": 16, "layout": "vertical", "padding": 16, "gap": 8, "sizingH": "fill", "sizingV": "hug"}}},
  {"command": "text.create", "params": {"text": "Today", "x": 0, "y": 0, "parent": {"$step": 3}, "props": {"fontSize": 20}}},
  {"command": "shape.rectangle", "params": {"x": 0, "y": 0, "width": 313, "height": 8, "parent": {"$step": 3}, "props": {"fill": "#0A84FF", "cornerRadius": 4}}},
  {"command": "node.create", "params": {"type": "component", "name": "Button", "x": 500, "y": 0, "width": 200, "height": 48,
    "props": {"fill": "#0A84FF", "cornerRadius": 12, "layout": "horizontal", "padding": [12,24,12,24], "mainAlign": "center", "crossAlign": "center", "sizingH": "hug"}}},
  {"command": "text.create", "params": {"text": "Continue", "x": 0, "y": 0, "parent": {"$step": 6}, "props": {"fontSize": 17, "fills": ["#FFFFFF"]}}},
  {"command": "instance.create", "params": {"component": {"$step": 6}, "parent": {"$step": 0}}}
]
```
```sh
figcraft-cli run screen.json --out screen.figcraft
figcraft-cli info screen.figcraft
```
Expected (exit 0):
```text
{"command":"frame.create","ok":true,"result":{"id":2},"step":0}
…
{"command":"instance.create","ok":true,"result":{"id":9},"step":8}
wrote screen.figcraft
screen.figcraft — Untitled (10 nodes, 0 styles, 0 variables, 0 images)
page 1 "Page 1": 9 nodes, 2 top-level
  2 FRAME "Home" 393.0×852.0
  7 COMPONENT "Button" 121.0×48.0
```
The card fills the frame width (345 = 393 − 2×24), the button hugs its label (121 wide), and the
instance stacks under the card inside the auto layout.

## 2. Look at it: render the page, export one frame

```sh
figcraft-cli render screen.figcraft -o page.png
figcraft-cli export screen.figcraft -o home.png --node Home --scale 2
figcraft-cli export screen.figcraft -o btn.png --node 7 --scale 3     # by id; 0:7 also works
```
Expected: `page.png (621×852)` (cropped to the page's content, Home + Button), a 786×1704
`home.png`, a 363×144 `btn.png`. Use `--node` names or ids from `info`.

## 3. Export every frame, in every format

```sh
figcraft-cli export screen.figcraft -o out/ --scale 2            # out/Home.png, out/Button.png
figcraft-cli export screen.figcraft -o pdfs/ --format pdf         # pdfs/Home.pdf, pdfs/Button.pdf
figcraft-cli export screen.figcraft -o all.pdf                    # 2 pages: 393×852 pt, 121×48 pt
figcraft-cli export screen.figcraft -o home.svg --node Home
figcraft-cli export screen.figcraft -o home.jpg --node Home       # also .webp
```
Each prints the files it wrote, one per line, and exits 0.

## 4. Keep components off the screens page

```json
[
 {"command":"frame.create","params":{"preset":"iPhone 16","x":0,"y":0,"name":"Home"}},
 {"command":"node.set","params":{"id":{"$step":0},"layout":"vertical","padding":24}},
 {"command":"page.add","params":{"name":"Components"}},
 {"command":"node.create","params":{"type":"component","name":"Chip","width":80,"height":32,"props":{"fill":"#FFD60A","cornerRadius":16}}},
 {"command":"instance.create","params":{"component":{"$step":3},"parent":{"$step":0}}}
]
```
```sh
figcraft-cli run pages.json --out pages.figcraft
figcraft-cli export pages.figcraft -o screens/                       # screens/Home.png only
figcraft-cli export pages.figcraft -o comps/ --page Components       # comps/Chip.png
```
`page.add` makes the new page current, so the component (no `parent`) lands on it; the instance
goes into Home on page 1 because its `parent` is explicit.

## 5. Print-ready PDF with bleed, marks and CMYK

```sh
figcraft-cli export screen.figcraft -o print.pdf --node Home --bleed 3mm --crop-marks --bleed-marks --cmyk
```
Expected: one-page PDF, `MediaBox [0 0 458.0 917.0]` (393×852 frame + 3 mm bleed + mark margin),
with BleedBox and TrimBox set. Bleed also takes `0.125in`, `9pt` or a number of points.

## 6. Edit an existing file in place-safe fashion

`edit.jsonl` (JSON lines; `//` lines are comments):
```text
// rename + recolour the card
{"command":"node.set","params":{"id":4,"name":"Summary card","fill":"#E8F0FF"}}
{"command":"text.set","params":{"id":5,"characters":"This week"}}
```
```sh
figcraft-cli run edit.jsonl --in screen.figcraft --out screen-v2.figcraft
```
Expected: two `"ok":true` lines, `wrote screen-v2.figcraft`, exit 0. Find ids first with:
```sh
echo '[{"command":"node.get","params":{"id":2}},{"command":"select.byName","params":{"query":"Continue"}}]' > q.json
figcraft-cli run q.json --in screen.figcraft
```
`node.get` returns the layer with its direct `children` (id, type, name, props; deeper levels show
`childCount`), `select.byName` returns `{"selection":[10,8]}` (instance sublayers have ids too).

## 7. Component text property + instance override

```json
[
 {"command":"component.addProperty","params":{"id":7,"name":"Label","type":"text","default":"Continue","layer":8}},
 {"command":"instance.create","params":{"component":7,"parent":2}},
 {"command":"instance.setProperties","params":{"ids":[{"$step":1}],"properties":{"Label":"Skip for now"}}},
 {"command":"component.properties","params":{"id":7}}
]
```
```sh
figcraft-cli run props.json --in screen.figcraft --out screen-props.figcraft
figcraft-cli export screen-props.figcraft -o home-props.png --node Home
```
Expected: last result `{"component":7,…,"properties":[{"default":"Continue","name":"Label","type":"text"}]}`;
the render shows a "Continue" button and a "Skip for now" button under the card.

## 8. Design tokens: light/dark variables and CSS export

```json
[
 {"command":"variable.createCollection","params":{"name":"Theme","modes":["Light","Dark"]}},
 {"command":"variable.create","params":{"collection":"Theme","name":"bg","type":"color","values":{"Light":"#F5F5F7","Dark":"#111111"}}},
 {"command":"variable.bind","params":{"ids":[2],"field":"fill","variable":"bg"}},
 {"command":"variable.setMode","params":{"ids":[2],"collection":"Theme","mode":"Dark"}},
 {"command":"variable.export","params":{"format":"css"}}
]
```
```sh
figcraft-cli run tokens.json --in screen.figcraft --out screen-dark.figcraft
figcraft-cli export screen-dark.figcraft -o dark.png --node Home --scale 0.5
```
Expected: the export step returns `:root { --bg: #F5F5F7; }` and `[data-theme="Dark"] { --bg: #111111; }`;
`dark.png` (197×426) has the dark background. Variable ids come back as strings
(`VariableID:1`), so refer to variables and collections by name.

## 9. Start from a template

```sh
echo '[{"command":"file.newFromTemplate","params":{"template":"dashboard"}}]' > start.json
figcraft-cli run start.json --out dashboard.figcraft
figcraft-cli info dashboard.figcraft
```
Expected: `Dashboard (186 nodes, 19 styles, …)`, one 1440×960 frame. List templates and frame
presets with `[{"command":"template.list","params":{}},{"command":"frame.presets","params":{}}]`.

## 10. Figma REST API JSON → FigCraft / PNG

Save the response of `GET /v1/files/:key` as `figma-file.json` (images, if any, in `images/<imageRef>.png`
next to it; otherwise they render as grey placeholders). Tested with a hand-made file holding one
375×667 `FRAME "Login"`:
```sh
figcraft-cli info figma-file.json
figcraft-cli export figma-file.json -o rest-out/      # rest-out/Login.png
figcraft-cli convert figma-file.json login.figcraft
```
Expected: `page 2 "Screens": 3 nodes, 1 top-level` / `3 FRAME "Login" 375.0×667.0`, exit 0.

## 11. Convert between formats

```sh
figcraft-cli convert screen.figcraft screen-doc.json  # FigCraft JSON, pretty-printed
figcraft-cli convert screen.figcraft screen.fig       # experimental .fig
figcraft-cli convert screen.fig roundtrip.figcraft    # reads back; ids renumber (frame 2 -> 3)
figcraft-cli convert screen.figcraft screen.svg       # current page
figcraft-cli convert screen.svg fromsvg.figcraft      # SVG -> one editable frame
figcraft-cli convert page.png img.figcraft            # image -> image layer
figcraft-cli convert screen.figcraft screen.pdf       # frames, one page each
```
Each prints the output path and exits 0. `info` on an imported `.fig` or `.svg` lists anything
left out as `note:` lines on stderr.

## 12. Deterministic renders (CI) and font checks

```sh
figcraft-cli info fonts.figcraft --no-system-fonts
FIGCRAFT_NO_SYSTEM_FONTS=1 figcraft-cli render fonts.figcraft -o fonts-builtin.png
echo '[{"command":"text.fonts","params":{}}]' > lf.json
figcraft-cli run lf.json --no-system-fonts
```
With a text layer in "Helvetica": `info --no-system-fonts` prints
`missing font "Helvetica": 1 text layer (drawn in a fallback font)` (stdout), and the PNG differs
from a render with system fonts. `text.fonts` under `--no-system-fonts` lists the 20 built-in
families (Inter, Roboto, Poppins, Montserrat, Lato, Open Sans, …): pick one of them for
machine-independent output.

## 13. Confine a run to folders

```sh
mkdir -p in out
figcraft-cli render in/screen.figcraft -o out/ok.png --automation-read-root in --automation-write-root out
figcraft-cli run in/screen.json --out out/s.figcraft --automation-read-root in --automation-write-root out
```
Expected: exit 0. Writing elsewhere fails before anything is written, exit 1:
```text
error: automation path rejected: escaped.png is outside the folders that may be written: …/out
```
The `run` script itself must be inside a root, and a root that doesn't exist is an error (exit 1).

## 14. Failure behaviour (for scripting)

```sh
echo '[{"command":"node.set","params":{"id":99999,"fill":"#f00"}}]' > bad.json
figcraft-cli run bad.json --in screen.figcraft --out bad-out.figcraft
```
Expected: stdout `{"command":"node.set","error":"no such node 99999","ok":false,"rolledBack":true,"step":0}`,
stderr `error: step 0 (node.set) failed …`, exit 1, and `bad-out.figcraft` is not written.
Unknown commands or `node.set` keys fail the same way (the error lists the valid keys). Missing
`-o` or an unknown subcommand prints usage and exits 2; a missing file, unknown `--node` or
`--page` exits 1.
