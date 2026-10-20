# Cross-app pipelines

Every pipeline below was run end to end on macOS with `vectorcraft-cli 0.13.1`, `photocraft-cli 0.10.0`,
`effectcraft-cli 0.11.1`, `filmcraft-cli 0.9.0`, `soundcraft-cli 0.10.0`, `gridcraft-cli 0.9.0`,
`wordcraft-cli 0.8.0`, `pdfcraft-cli 0.9.0`, `lightcraft-cli 0.9.1`, `designcraft-cli 0.10.0`,
`figcraft-cli 0.8.0` and `deckcraft-cli 0.8.0`. Run each in its own empty folder; paths are relative
unless a CLI needs absolute ones (marked). Read `safety.md` first, and each app's own skill for details.

Where a step needs a generated image or clip, the stand-in comes from a Craft CLI; swap in a file from
the `genai` skill at that point.

## Contents

1. [Hand-off formats](#hand-off-formats)
2. [Brand asset: logo to social card](#1-brand-asset-logo-to-social-card)
3. [Vertical reel with title and voiceover](#2-vertical-reel-with-title-and-voiceover)
4. [Report: spreadsheet chart to Word to PDF](#3-report-spreadsheet-chart-to-word-to-pdf)
5. [Print flyer with bleed](#4-print-flyer-with-bleed)
6. [Pitch deck from other apps' output](#5-pitch-deck-from-other-apps-output)

## Hand-off formats

| From | Best interchange format | To | Notes |
|---|---|---|---|
| VectorCraft | PNG at `--scale 2` (transparent) | PhotoCraft, WordCraft, FigCraft | `file.placeEmbedded` also takes SVG, but places it at 1 pt = 1 px |
| VectorCraft | SVG | DeckCraft, DesignCraft | stays vector; WordCraft and FigCraft `image.place` reject SVG |
| VectorCraft | PDF / EPS | DesignCraft, print shops | `document.exportPdf` with `preserveEditing:false` for a lean file |
| PhotoCraft | PNG (alpha) or JPG (flat) | DeckCraft, DesignCraft, WordCraft, FilmCraft | keep the `.psd` master; flat exports warn `N layer(s) flattened` |
| EffectCraft | ProRes 4444 `.mov` (`--format prores --channels rgba`) | FilmCraft V2+ | alpha composites over V1 without any key; H.264 has no alpha |
| FilmCraft `--demo export` | H.264 `.mp4` | FilmCraft, EffectCraft | a stand-in clip with no ffmpeg |
| macOS `say` / any TTS | AIFF, then WAV via SoundCraft | FilmCraft, SoundCraft | `say` writes 22.05 kHz mono; convert to 48 kHz/24-bit |
| GridCraft | PDF (`file.exportPdf`) | PdfCraft, or PdfCraft `render` to PNG | GridCraft can't export a chart picture on its own |
| WordCraft | PDF | PdfCraft | WordCraft can't read PDF back |
| LightCraft | JPG/TIFF at full size | DesignCraft, PhotoCraft | `render` never writes over the original |
| DesignCraft | PDF with `marks` + `bleed` | printer, PdfCraft | MediaBox grows; TrimBox and BleedBox are set |
| FigCraft | PNG at `--scale 2` per frame | DeckCraft, DesignCraft, WordCraft | `--no-system-fonts` gives the same pixels on every machine |
| DeckCraft | PPTX + PDF | PowerPoint, PdfCraft | keep `.deckcraft` as the working copy |

General rule: hand raster work over as PNG (JPG only for photos), vector work as SVG or PDF, video as
ProRes when it needs alpha and H.264 otherwise, and audio as 48 kHz WAV.

## 1. Brand asset: logo to social card

VectorCraft logo (shapes + text) to SVG + 2x PNG, then a 1080×1080 PhotoCraft card to JPG.

1. Build the logo (400×160 pt). Set paint after each shape, because shapes take the current default paint:
   ```bash
   vectorcraft-cli run --cmd file.new --params '{"width":400,"height":160,"units":"Pixels"}' \
     --cmd shape.ellipse --params '{"x":20,"y":20,"width":120,"height":120}' \
     --cmd paint.setFill --params '{"color":"#ff7a00"}' --cmd paint.setStroke --params '{"none":true}' \
     --cmd shape.star --params '{"cx":80,"cy":80,"radius1":45,"radius2":20,"points":5}' \
     --cmd paint.setFill --params '{"color":"#ffffff"}' --cmd paint.setStroke --params '{"none":true}' \
     --cmd text.create --params '{"x":160,"y":100,"text":"Acme","size":64,"color":"#ffffff"}' \
     --export logo.svg --export logo.vectorcraft
   ```
   You get one JSON line per step and `logo.svg` (763 bytes). Run `vectorcraft-cli info logo.svg` and
   check that `fonts[].status` is `exact`.
2. Export the 2x PNG:
   ```bash
   vectorcraft-cli convert logo.svg logo@2x.png --scale 2
   ```
   This gives an 800×320 transparent PNG. White text on a transparent background looks empty in
   viewers, which is expected.
3. Compose the card: a gradient fill layer, the logo, and paragraph text in a `box`:
   ```bash
   photocraft-cli run --new '{"width":1080,"height":1080}' \
     --cmd layer.newFillLayer.gradient --params '{"from":"#1e3c72","to":"#2a5298","angle":90,"style":"linear"}' \
     --cmd file.placeEmbedded --params '{"path":"logo@2x.png","center":[540,330],"smartObject":false}' \
     --cmd type.create --params '{"box":[90,560,900,300],"text":"Launch Day\nOctober 2026","align":"center","size":88,"color":"#ffffff","font":"Helvetica","fontStyle":"Bold"}' \
     --out card.psd
   photocraft-cli convert card.psd social-card.jpg --quality 88
   ```
   `placeEmbedded` returns `bounds [140,170,940,490]`. The JPG is 1080×1080 and stderr says
   `4 layer(s) flattened` (expected).

Gotchas:
- `file.placeEmbedded` with `logo.svg` also works, but at 1 px per pt (400×160 here). Export the PNG
  at the scale you need instead of resizing in PhotoCraft.
- Keep `card.psd` as the editable master. To change the headline later, use `layer.select` and then
  `type.edit`.

## 2. Vertical reel with title and voiceover

EffectCraft 3 s title (alpha) + FilmCraft demo clip + `say` voiceover → `<slug>-9x16.mp4`.

1. Animate the title in a 1080×1920 comp with a transparent background (no solid layer):
   ```bash
   effectcraft-cli --empty --save-as title.ecproj run \
     comp.new '{"name":"Title","width":1080,"height":1920,"frameRate":30,"duration":3}' \
     layer.newText '{"text":"NEW DROP","size":170,"fill":"#ffffff"}' \
     layer.newShape '{"kind":"rounded","name":"Bar","size":[600,24],"fill":"#ff5a36","position":[540,1080]}'
   effectcraft-cli --project title.ecproj --save set Title "NEW DROP" transform/opacity 0 --time 0
   effectcraft-cli --project title.ecproj --save set Title "NEW DROP" transform/opacity 100 --time 0.6
   effectcraft-cli --project title.ecproj --save set Title Bar transform/scale '[0,100,100]' --time 0.3
   effectcraft-cli --project title.ecproj --save set Title Bar transform/scale '[100,100,100]' --time 1
   effectcraft-cli --project title.ecproj render-frame --comp Title --time 1.5 --transparent --max-side 960 --out preview.png
   ```
2. Render it with alpha:
   ```bash
   effectcraft-cli --project title.ecproj render --comp Title --out title.mov --format prores --channels rgba --end 3
   ```
   The output is `(1080×1920, 90 frames)`, and `filmcraft-cli probe title.mov` shows `Apple ProRes 4444`,
   `has_alpha: true`. A PNG sequence (`--out 'seq/f_[####].png'`) is the fallback, but ProRes is one file.
3. Make the background clip (the stand-in, or a clip from the genai skill):
   ```bash
   filmcraft-cli --demo export "$PWD/bg.mp4" --start 0 --end 3
   ```
   The output is 1920×1080 H.264 + AAC, 3 s.
4. Record the voiceover and convert it to 48 kHz/24-bit WAV with a peak normalize:
   ```bash
   say -o vo.aiff "New drop. Out now. Link in bio."
   soundcraft-cli convert vo.aiff vo.wav --bit-depth 24 --rate 48000 --normalize
   ```
   `say` writes 22.05 kHz mono AIFF (2.28 s), and SoundCraft prints `wrote vo.wav (1 ch, 48000 Hz, 2.28 s)`.
   Other platforms (not tested here): Linux `espeak-ng -w vo.wav "…"`; Windows PowerShell
   `Add-Type -AssemblyName System.Speech; $s=New-Object System.Speech.Synthesis.SpeechSynthesizer;
   $s.SetOutputToWaveFile("vo.wav"); $s.Speak("…")`. Then run the same `soundcraft-cli convert`.
5. Build the vertical sequence. Use absolute paths in the JSON:
   ```bash
   cat > build.jsonl <<EOF
   {"id":"file.import","params":{"paths":["$PWD/bg.mp4","$PWD/title.mov","$PWD/vo.wav"]}}
   {"id":"file.newSequence","params":{"name":"Reel","width":1080,"height":1920,"fps":30}}
   EOF
   filmcraft-cli --save-as "$PWD/reel.fcproj" run build.jsonl      # items [1,2,3], sequence 10
   cat > edit.jsonl <<'EOF'
   {"id":"sequence.open","params":{"item":10}}
   {"id":"timeline.place","params":{"item":1,"track":"V1","seconds":0,"audio":false}}
   {"id":"edit.selectAll","params":{}}
   {"id":"clip.fillFrame","params":{}}
   {"id":"timeline.place","params":{"item":2,"track":"V2","seconds":0}}
   {"id":"timeline.place","params":{"item":3,"track":"A1","seconds":0.3}}
   EOF
   filmcraft-cli --project reel.fcproj --save run edit.jsonl
   filmcraft-cli --project reel.fcproj render --seconds 1.5 --out check.png --scale 0.5
   ```
   `fillFrame` scales the 16:9 clip to 177.8%. Run it before placing the title so the full-frame title
   isn't selected. `check.png` shows the title over the clip.
6. Export with loudness normalization:
   ```bash
   filmcraft-cli --project reel.fcproj export "$PWD/new-drop-9x16.mp4" \
     --settings '{"effects":{"loudness":{"enabled":true,"target_lufs":-14,"true_peak_dbtp":-1}}}'
   ```
   `probe` shows H.264 High, 1080×1920, 30 fps, 3.0 s, AAC.

Gotchas:
- `"audio":false` on `timeline.place` drops the demo clip's music, so A1 holds only the voiceover.
- Read ids from the JSON results (items, `sequence`) instead of copying the ones above.
- Saving creates `FilmCraft Previews/` next to the `.fcproj`.
- Keep the `-9x16.mp4` suffix. Ad tooling infers the placement from it.

## 3. Report: spreadsheet chart to Word to PDF

GridCraft workbook + chart → PDF and chart PNG → WordCraft docx → PDF → PdfCraft merge + metadata.

1. Build the workbook from CSV and check it:
   ```bash
   printf 'Month,Revenue,Cost\nJan,120,80\nFeb,150,90\nMar,170,95\nApr,210,110\n' > sales.csv
   gridcraft-cli run --in sales.csv --quiet \
     --cmd 'range.setValues={"range":"D1","values":[["Margin"],["=B2-C2"],["=B3-C3"],["=B4-C4"],["=B5-C5"]]}' \
     --cmd 'home.bold={"range":"A1:D1"}' \
     --cmd 'insert.chart={"range":"A1:C5","type":"column","title":"Revenue vs Cost","at":"F2"}' \
     --out sales.xlsx
   gridcraft-cli check sales.xlsx     # 4 formulas matched, round trip equal
   ```
2. Export the sheet to PDF (this PDF is also the report's appendix):
   ```bash
   gridcraft-cli run --in sales.xlsx --quiet --cmd 'file.exportPdf={"path":"sales.pdf","fitToPage":true}'
   ```
   The result is one Letter page with the table and the chart.
3. Turn the chart into a PNG: render the page, then crop the chart:
   ```bash
   pdfcraft-cli render sales.pdf --page 1 --dpi 150 --out sales-p1.png        # 1275×1650
   photocraft-cli run sales-p1.png --cmd image.crop --params '{"x":505,"y":130,"width":635,"height":385}' --out chart.png
   ```
   The crop box depends on the chart's anchor and size. Render the page once and look before you crop.
4. Write the report in Markdown with a placeholder line where the chart goes (see gotchas), convert it,
   then insert the picture at the placeholder:
   ```bash
   export WORDCRAFT_REGION=en-US
   printf '# Q1 Sales Report\n\nRevenue grew every month.\n\n## Revenue vs cost\n\nCHART_HERE\n\n## Summary\n\n| Month | Revenue |\n|---|---|\n| Jan | 120 |\n| Apr | 210 |\n' > report.md
   wordcraft-cli convert report.md report-draft.docx
   wordcraft-cli run --file report-draft.docx \
     --cmd 'file.properties={"title":"Q1 Sales Report","author":"Ops"}' \
     --cmd 'select.text={"text":"CHART_HERE"}' --cmd text.delete \
     --cmd 'insert.picture={"path":"chart.png","width":432,"alt":"Revenue vs cost chart"}' \
     --save report.docx
   wordcraft-cli render report.docx report-p1.png --page 1 --scale 1   # check the chart is there
   wordcraft-cli convert report.docx report.pdf
   ```
5. Merge the PDFs and set the metadata:
   ```bash
   pdfcraft-cli combine report.pdf sales.pdf --out combined.pdf
   cat > meta.json <<'EOF'
   [
    {"tool":"doc_open","args":{"path":"combined.pdf"}},
    {"tool":"doc_set_info","args":{"doc":1,"key":"Title","value":"Q1 Sales Report"}},
    {"tool":"doc_set_info","args":{"doc":1,"key":"Author","value":"Ops Team"}},
    {"tool":"doc_set_info","args":{"doc":1,"key":"Subject","value":"Quarterly sales"}},
    {"tool":"doc_set_info","args":{"doc":1,"key":"Keywords","value":"sales, q1"}},
    {"tool":"doc_save","args":{"doc":1,"path":"q1-report.pdf"}},
    {"tool":"doc_info","args":{"doc":1}}
   ]
   EOF
   pdfcraft-cli run --script meta.json --report
   pdfcraft-cli info q1-report.pdf      # pages 2, title/author set, 2 bookmarks (one per source)
   ```
   `doc_info` returns a list with one object that holds `subject` and `keywords`. CLI `info` shows only
   title and author.

Gotchas:
- **WordCraft drops Markdown images.** `![alt](chart.png)` (relative or absolute path) and `<img>` become
  plain alt text with no picture in the docx. Use the placeholder + `select.text` + `text.delete` +
  `insert.picture` step above. The delete command is `text.delete`; `edit.delete` doesn't exist.
- GridCraft has no chart-to-image export. The PDF → `pdfcraft-cli render` → `photocraft-cli` crop
  route is the tested path.
- `combine` takes PDFs only. For images or `.txt`, use `run doc_combine`.

## 4. Print flyer with bleed

LightCraft develop → DesignCraft A4 flyer, full-bleed photo + headline → print PDF → PdfCraft check.

1. Get a stand-in photo (or use a genai image or a real photo), then develop it:
   ```bash
   lightcraft-cli run --demo app.export ids='[3]' dir=src longEdge=2400   # src/LC01221.jpg, 2400×1600
   mv src/LC01221.jpg photo-raw.jpg
   lightcraft-cli render photo-raw.jpg -o photo-dev.jpg --preset lc.golden-hour \
     --set light.exposure=0.3 --set color.vibrance=20 --set vignette.amount=-20 --size 2400 --quality 92
   ```
   This prints `wrote photo-dev.jpg (2400×1600)`. A `.tif` output works too, if you'd rather skip JPEG
   compression before layout.
2. Lay out the page. All numbers are points (A4 = 595.28×841.89, 3 mm ≈ 8.5 pt), and the photo frame
   runs into the bleed. Use an **absolute** image path:
   ```bash
   cat > flyer.dcs <<EOF
   file.new {"preset":"A4","pages":1,"facingPages":false,"margins":36,"bleed":8.5,"title":"Flyer"}
   style.paragraph.create {"name":"Headline","para":{"align":"center","spaceAfter":8},"chars":{"size":44,"fontStyle":"Bold"}}
   style.paragraph.create {"name":"Sub","para":{"align":"center"},"chars":{"size":16}}
   frame.create {"spread":0,"rect":[-8.5,-8.5,603.8,460],"content":"graphic"}
   file.place {"path":"$PWD/photo-dev.jpg","frame":"\$3.id"}
   object.fit {"mode":"fillProportionally","ids":["\$3.id"]}
   frame.create {"spread":0,"rect":[36,500,559,640],"content":"text","text":"Golden Hour Walk\nSaturday 7 pm · Riverside Park"}
   text.select {"story":"\$6.story","anchor":0,"focus":16}
   style.paragraph.apply {"name":"Headline"}
   text.select {"story":"\$6.story","anchor":17,"focus":48}
   style.paragraph.apply {"name":"Sub"}
   preflight.run {}
   EOF
   designcraft-cli script flyer.dcs --save flyer.designcraft
   ```
   The last result is `{"errors":0,"issues":[],"warnings":0}`. The `text.select` offsets are UTF-8 bytes,
   and `·` takes 2 bytes.
3. Export the print PDF with marks and bleed, plus a trim-size proof:
   ```bash
   designcraft-cli run --in flyer.designcraft --export flyer-trim.pdf \
     --pdf-options '{"marks":true,"bleed":true}' --export flyer-print.pdf
   ```
   Put the plain export first, because `--pdf-options` applies to every later `--export`.
4. Check the page size:
   ```bash
   pdfcraft-cli info flyer-trim.pdf     # first_page_pt [595.28, 841.89] = A4
   pdfcraft-cli info flyer-print.pdf    # first_page_pt [660.28, 906.89] = MediaBox incl. marks
   cat > pr.json <<'EOF'
   [
    {"tool":"doc_open","args":{"path":"flyer-print.pdf"}},
    {"tool":"print_readiness","args":{"doc":1}}
   ]
   EOF
   pdfcraft-cli run --script pr.json --report
   ```
   `print_readiness` reports `trim_mm [210.0, 297.0]`, `bleed_margin_mm` ≈ 3.0 on each side, and the
   image at 246 ppi (`warn`, below 300). Use it to check trim and bleed. `info` shows only the MediaBox.

Gotchas:
- With a **relative** `file.place` path, the image is still embedded and exported, but `preflight.run`
  reports `missingLink … (the path is not valid)` as an error. Absolute paths keep preflight clean.
- `script --export x.png` renders page 1 at 2x. `run --export x.png` renders at 1 px/pt and includes the
  bleed: 612×859 for this A4 page.
- Use a 2400 px photo or larger for a half-page A4 image. Below about 150 ppi, preflight warns `lowResolution`.

## 5. Pitch deck from other apps' output

DeckCraft deck with the pipeline 1 social card and a FigCraft UI mockup → PPTX + PDF.

1. Render the UI mockup. Use built-in fonts so the output is the same on every machine:
   ```bash
   cat > app.json <<'EOF'
   [
    {"command":"frame.create","params":{"preset":"iPhone 16","x":0,"y":0,"name":"Home"}},
    {"command":"node.set","params":{"id":{"$step":0},"fill":"#F5F5F7","layout":"vertical","padding":24,"gap":16}},
    {"command":"text.create","params":{"text":"Welcome back","x":0,"y":0,"parent":{"$step":0},"props":{"fontSize":32,"fontStyle":"Bold","fontFamily":"Inter"}}},
    {"command":"node.create","params":{"type":"frame","name":"Card","parent":{"$step":0},"width":345,"height":120,
      "props":{"fill":"#FFFFFF","cornerRadius":16,"layout":"vertical","padding":16,"gap":8,"sizingH":"fill","sizingV":"hug"}}},
    {"command":"text.create","params":{"text":"Launch progress","x":0,"y":0,"parent":{"$step":3},"props":{"fontSize":20,"fontFamily":"Inter"}}},
    {"command":"shape.rectangle","params":{"x":0,"y":0,"width":220,"height":8,"parent":{"$step":3},"props":{"fill":"#ff7a00","cornerRadius":4}}}
   ]
   EOF
   figcraft-cli run app.json --out app.figcraft --no-system-fonts
   figcraft-cli export app.figcraft -o app-home.png --node Home --scale 2 --no-system-fonts   # 786×1704
   ```
2. Build the deck. Copy `social-card.jpg` from pipeline 1, or use an image from the genai skill:
   ```bash
   deckcraft-cli run --print \
     --cmd 'file.new={"theme":"Slate","blank":true}' \
     --cmd 'slide.new={"layout":"title","title":"Acme Launch","body":"Pitch deck · October 2026"}' \
     --cmd 'slide.new={"layout":"titleOnly","title":"Brand and product"}' \
     --cmd 'insert.picture={"path":"social-card.jpg","rect":[60,130,360,360]}' \
     --cmd 'insert.picture={"path":"app-home.png","rect":[560,120,175,380]}' \
     --cmd 'slide.notes={"text":"Left: launch social card. Right: app home screen."}' \
     --save pitch.deckcraft
   ```
3. Export and verify:
   ```bash
   deckcraft-cli convert pitch.deckcraft pitch.pptx
   deckcraft-cli convert pitch.deckcraft pitch.pdf          # 2 pages, 960×540 pt
   deckcraft-cli render pitch.pptx --slide 1 --scale 1 slide2.png
   deckcraft-cli info pitch.pptx                            # media: image1.jpeg, image2.png
   ```
   The PPTX embeds both images (`ppt/media/`), and rendering it back shows the card and the phone screen.

Gotchas:
- `insert.picture` with a `rect` uses that box as given, so a wrong aspect ratio **stretches** the image
  (`[0,0,400,100]` stayed 400×100). Match the image ratio (phone 786×1704 ≈ 175×380), or leave out
  `rect`: the picture is then fitted and centred (224×486 here).
- DeckCraft and DesignCraft accept `logo.svg` directly. WordCraft `insert.picture` rejects SVG
  (`not a supported image (PNG, JPEG, GIF, WebP, BMP, WMF, EMF)`), and FigCraft `image.place` rejects it
  (`format could not be determined`; use `figcraft-cli convert logo.svg logo.figcraft` instead).
- Without `--no-system-fonts`, FigCraft may use local fonts such as Helvetica, so renders differ
  between machines.
