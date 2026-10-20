# deckcraft-cli recipes

Every recipe below was run against `deckcraft-cli 0.8.0`. Paths are relative to the working directory.
Coordinates are points on a 960×540 slide; `rect` = `[x, y, w, h]`. Slide indices are 0-based.

## 1. Build a themed deck from scratch

```bash
deckcraft-cli run --print \
  --cmd 'file.new={"theme":"Harbor","blank":true}' \
  --cmd 'slide.new={"layout":"title","title":"Q3 Results","body":"Operations review"}' \
  --cmd 'slide.new={"layout":"titleAndContent","title":"Highlights","body":"Revenue up 12%\nChurn down to 3.1%"}' \
  --cmd 'slide.new={"layout":"titleOnly","title":"Pipeline"}' \
  --cmd 'shape.insert={"preset":"roundRect","rect":[80,160,240,120],"text":"Leads"}' \
  --cmd 'shape.fill={"color":"#1B7FA6"}' \
  --cmd 'format.size={"size":28}' \
  --cmd 'insert.picture={"path":"photo.png","rect":[480,140,400,225]}' \
  --cmd 'slide.notes={"text":"Thank the team."}' \
  --save q3.deckcraft
```

Expected (exit 0):

```text
file.new → {"document":1,"slides":0}
slide.new → {"id":257,"index":0}
slide.new → {"id":260,"index":1}
slide.new → {"id":263,"index":2}
shape.insert → {"id":265}
shape.fill → 1
format.size → null
insert.picture → {"id":267}
slide.notes → null
```

Layout kinds for `slide.new`: `title, titleAndContent, sectionHeader, twoContent, comparison, titleOnly,
blank, contentWithCaption, pictureWithCaption`. Theme names: `DeckCraft, Harbor, Ember, Meadow, Nocturne,
Paper, Coral Reef, Slate` (list with `--cmd design.themes`).

## 2. Deck from a Markdown outline

```bash
printf '# Roadmap 2027\n- Ship v2\n- Hire two engineers\n  - one backend\n# Risks\n- Vendor lock-in\n' > outline.md
P=$(python3 -c 'import json,sys;print(json.dumps({"text":open(sys.argv[1]).read(),"markdown":True}))' outline.md)
deckcraft-cli run --cmd 'file.new={"theme":"Slate","blank":true}' --cmd "slide.fromOutline=$P" --save roadmap.deckcraft
```

Expected: exit 0; `deckcraft-cli info roadmap.deckcraft` shows two slides, "Roadmap 2027" and "Risks",
each Title and Content with bullets ("one backend" as a sub-bullet).

## 3. Start from a starter template

```bash
deckcraft-cli run --print --cmd file.templates
deckcraft-cli run --print --cmd 'file.new={"template":"Pitch"}' --save pitch.deckcraft
```

Expected: templates `Briefing, Lesson, Pitch, Field Notes, Quarterly, Evening Talk` (5 slides each, own
theme); `file.new → {"document":1,"slides":5,"template":"Pitch"}`. Then edit with recipe 5.

## 4. Inspect a deck and find shape ids

```bash
deckcraft-cli info q3.pptx
deckcraft-cli run --in q3.pptx --print --cmd 'slide.inspect={"index":1}'
```

Expected: `info` prints pretty JSON with `slides[]` (`index, id, title, layout, shapes, notes, transition,
hidden`), `layouts`, `fonts`, `theme`, `media`, `slideSize` (`[960.0, 540.0]`). `slide.inspect` prints
`slide.inspect → {…"shapes":[{"box":[60.0,144.0,840.0,343.0],"id":262,"kind":"placeholder","placeholder":"obj","text":"Revenue up 12%\n…"}…]}`.

Parse it:

```bash
deckcraft-cli run --in q3.pptx --print --cmd 'slide.inspect={"index":1}' \
  | sed 's/^[^ ]* → //' | python3 -c 'import json,sys;print([(s["id"],s.get("text")) for s in json.load(sys.stdin)["shapes"]])'
```

## 5. Edit an existing .pptx

```bash
deckcraft-cli run --in q3.pptx --print \
  --cmd 'slide.go={"index":1}' \
  --cmd 'text.set={"id":262,"text":"Revenue up 14%\nChurn down to 2.9%\nThree new regions live"}' \
  --cmd 'design.theme={"name":"Nocturne"}' \
  --cmd 'slide.move={"from":3,"to":1}' \
  --cmd 'slide.delete={"index":3}' \
  --cmd 'transition.set={"kind":"fade","duration":500}' \
  --cmd transition.applyAll \
  --cmd 'file.properties={"title":"Q3 Results","author":"Ops"}' \
  --save q3-v2.pptx
```

Expected: exit 0; `slide.delete → {"deleted":1,"remaining":3}`; `info q3-v2.pptx` shows theme `Nocturne`
and every slide with transition `fade`. Without the `slide.go` line, `text.set` fails:
`deckcraft-cli: invalid parameters for 'text.set': no such shape`, exit 1, nothing saved.

## 6. Table, chart and a formatted text box

```bash
deckcraft-cli run --in q3.deckcraft --print \
  --cmd 'slide.go={"index":3}' \
  --cmd 'slide.new={"layout":"titleOnly","title":"By region"}' \
  --cmd 'insert.table={"rows":3,"cols":2,"rect":[60,140,400,150]}' \
  --cmd 'text.set={"cell":[0,0],"text":"Region"}' \
  --cmd 'text.set={"cell":[0,1],"text":"Revenue"}' \
  --cmd 'text.set={"cell":[1,0],"text":"North"}' \
  --cmd 'text.set={"cell":[1,1],"text":"$1.2M"}' \
  --cmd 'table.style={"style":"medium2-accent1"}' \
  --cmd 'insert.chart={"type":"column","rect":[500,140,400,300],"categories":["Q1","Q2","Q3"],"series":[{"name":"Revenue","values":[1.0,1.1,1.2]}]}' \
  --cmd 'chart.options={"title":"Revenue ($M)","legend":null}' \
  --cmd 'insert.textBox={"rect":[60,460,840,40],"text":"Source: finance, unaudited"}' \
  --cmd 'format.size={"size":12}' \
  --cmd 'format.italic={"on":true}' \
  --cmd 'format.color={"color":"#5D576B"}' \
  --save q3-tables.deckcraft
```

Expected: exit 0; new slide at index 4 with a styled header-row table, a titled column chart, and a
small italic caption. (`slide.go` to the last slide first, so `slide.new` appends.)

## 7. Merge another deck's slides

```bash
deckcraft-cli run --in q3.deckcraft --print \
  --cmd 'slide.go={"index":3}' \
  --cmd 'slide.reuse={"path":"roadmap.deckcraft"}' \
  --save merged.pptx
```

Expected: `slide.reuse → {"from":"roadmap.deckcraft","ids":[…],"keepFormatting":false,"slides":2}`;
the reused slides take the destination theme (pass `"keepFormatting":true` to keep theirs).

## 8. Change slide size to 4:3

```bash
deckcraft-cli run --in q3.deckcraft --print --cmd 'design.slideSize={"preset":"standard","scale":"ensureFit"}' --save q3-43.deckcraft
```

Expected: `design.slideSize → {"h":540.0,"w":720.0}`; content is scaled to fit.

## 9. Convert

```bash
deckcraft-cli convert q3.deckcraft q3.pptx   # also .pdf .gif .jpg .png .md .txt .potx .ppsx .deckcraft
```

Expected: prints `q3.pptx`, exit 0. `.png`/`.jpg` = first slide only; `.md`/`.txt` = tab-indented outline
(slide titles, then tab + each text line). `.svg` → `unsupported output format .svg`, exit 1.

## 10. Render slides to PNG

```bash
mkdir -p png
deckcraft-cli render q3.deckcraft --all --scale 1 png      # png/slide-01.png … (960×540)
deckcraft-cli render q3.deckcraft --slide 2 slide-3.png     # 1920×1080 (default scale 2)
deckcraft-cli render --sample --slide 0 --scale 0.5 sample.png
```

Expected: prints each path with its size, e.g. `png/slide-01.png (960×540)`. An out-of-range `--slide 9`
→ `no slide index 9 (this deck has 3 slides, numbered 0 through 2 …)`, exit 1.

## 11. Exports with options (PDF subsets, handouts, GIF, all slides as PNG)

```bash
# handouts, 6 per A4 page
deckcraft-cli run --in q3.deckcraft --export handout.pdf --export-params '{"layout":"handouts","perPage":6,"paper":"a4"}'
# only some slides: list = 0-based indices, string range = 1-based
deckcraft-cli run --in q3.deckcraft --cmd 'file.export={"path":"sub.pdf","slides":[1,2]}'   # slides 2 and 3
deckcraft-cli run --in q3.deckcraft --cmd 'file.export={"path":"sub.pdf","slides":"1-2"}'   # slides 1 and 2
# every slide as PNG through file.export
mkdir -p exp
deckcraft-cli run --in q3.deckcraft --print --cmd 'file.export={"path":"exp/s.png","all":true,"scale":1}'
# animated GIF
deckcraft-cli run --in q3.deckcraft --export deck.gif --export-params '{"width":"small","secondsPerSlide":2}'
# the current slide as PNG
deckcraft-cli run --in q3.deckcraft --cmd 'slide.go={"index":2}' --export slide-3.png
```

Expected: exit 0 each. The `all` export answers `{"files":["exp/s1.png","exp/s2.png",…]}`;
`sub.pdf` answers `{"bytes":…,"path":"sub.pdf"}`. `--save` and `--export` can be combined in one run.

## 12. Look up a command or a valid name

```bash
deckcraft-cli commands chart            # positional filter
deckcraft-cli describe file.export
deckcraft-cli run --print --cmd shape.presets   # also insert.icons, transition.list, animation.list
```
