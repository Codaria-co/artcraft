# LightCraft recipes

Every recipe below was run against `lightcraft-cli 0.9.1` on macOS with plain JPEG test photos
(`in/sky.jpg` 800×600, `in/sunset.jpg` 640×480) and synthetic DNG brackets. Paths are relative to the
working directory. `run` prints one JSON line per command; "Expected" shows the important part.

## 1. Develop one photo with sliders, resize, set quality

```bash
lightcraft-cli render in/sky.jpg -o out/sky-edit.jpg \
  --set light.exposure=0.5 --set color.vibrance=30 --size 400 --quality 85
```
Expected: `lightcraft-cli: wrote out/sky-edit.jpg (400×300)`, exit 0.

## 2. Apply a built-in preset, then adjust on top

```bash
lightcraft-cli run presets.list            # ids like lc.golden-hour, lc.bw-high-contrast
lightcraft-cli render in/sunset.jpg -o out/sunset-mix.jpg --preset lc.golden-hour --set light.exposure=-0.3
lightcraft-cli render in/sunset.jpg -o out/sunset-bw.jpg --preset lc.bw-high-contrast --size 320
```
Expected: `wrote out/sunset-mix.jpg (640×480)`, `wrote out/sunset-bw.jpg (320×240)`.
`--preset "High Contrast B&W"` (display name) fails: `unknown preset`, exit 1.

## 3. Export to other formats / color space

```bash
for f in webp avif tif jxl psd png; do lightcraft-cli render in/sky.jpg -o out/sky.$f --size 300; done
lightcraft-cli render in/sky.jpg -o out/sky-p3.jpg --opt colorSpace=displayP3 --opt percent=50
```
Expected: one `wrote …` line per format (PSD is 16-bit RGB); `sky-p3.jpg` is 400×300.
`.dng` from a JPEG fails (`DNG export needs a raw photo`), `.gif` fails (`unknown extension`).

## 4. Apply partial settings from a JSON file

```bash
echo '{"light":{"exposure":0.8}}' > s1.json
lightcraft-cli render in/sky.jpg -o out/s1.jpg --settings s1.json
```
Expected: `wrote out/s1.jpg (800×600)`. Keys follow `develop.get` (snake_case sections), e.g.
`{"detail":{"sharpen_amount":40}}`.

## 5. Import, auto-tone, tweak, crop square, export

```bash
lightcraft-cli run --import in/sky.jpg develop.auto develop.set control=light.exposure value=0.3 \
  crop.aspect aspect=1x1 app.export path=out/sq.jpg longEdge=400
```
Expected: `develop.auto` result lists what it set (`{"exposure":-0.75,"contrast":68,…}`), then
`app.export` → `{"files":[{"path":"out/sq.jpg","width":400,"height":400,…}]}`. Order matters:
`develop.auto` placed after `develop.set` would overwrite the exposure.

## 6. Batch: same look on a whole folder, renamed web copies

```bash
lightcraft-cli run --import in/ library.selectAll preset.apply id=lc.crisp-landscape \
  app.export dir=out/web2 longEdge=2048 format=jpeg quality=85 naming='trip-{seq:3}'
```
Expected: `out/web2/trip-001.jpg`, `trip-002.jpg` (dir is created). Photos smaller than 2048 px keep
their size.

Same sliders on every photo (develop.set needs `ids`, or `develop.sync` after it):
```bash
lightcraft-cli run --import in develop.set values='{"light.exposure":0.4,"color.vibrance":25}' ids='[1,2]' \
  app.export dir=out/batch longEdge=500
# or: … library.selectAll develop.set control=light.exposure value=0.4 develop.sync app.export …
```
Expected: `catalog.query` afterwards shows `"edited": true` for both. Without `ids`/`develop.sync`
only the active photo (id 1) changes.

## 7. Batch: per-photo auto-tone

```bash
for f in in/*.jpg; do
  lightcraft-cli run --import "$f" develop.auto app.export dir=out/auto longEdge=2048 >/dev/null || echo "FAIL $f"
done
```
Expected: `out/auto/sky.jpg`, `out/auto/sunset.jpg`, each auto-toned on its own content.

## 8. Shell-loop render to WebP

```bash
for f in in/*.jpg; do b=$(basename "${f%.*}")
  lightcraft-cli render "$f" -o "out/r/$b-web.webp" --preset lc.crisp-landscape --size 1200 --quality 80
done
```
Expected: `wrote out/r/sky-web.webp (800×600)` — `--size` never upscales.

## 9. Export with watermark and conflict handling

```bash
lightcraft-cli run --import in app.export dir=out/web naming='web-{seq:3}' longEdge=300 watermark='© Demo'
lightcraft-cli run --import in app.export dir=out/batch longEdge=200                 # existing names → sky-2.jpg …
lightcraft-cli run --import in app.export dir=out/batch longEdge=200 conflict=skip   # → {"skipped": …}
```
Expected: `web-001.jpg`, `web-002.jpg`; then `-2` suffixed copies; then a `skipped` result per file.
Note: `path=FILE` (single file) silently overwrites an existing export.

## 10. Persistent library: import, edit, rate, tag, query, export

```bash
lightcraft-cli run --library lib --import in library.info
lightcraft-cli run --library lib develop.set ids='[1]' values='{"light.exposure":0.6}' \
  photo.rate rating=4 ids='[1]' photo.setMeta ids='[1]' title="Blue sky" keywords='["sky","test"]'
lightcraft-cli run --library lib catalog.query
lightcraft-cli run --library lib develop.get id=1
lightcraft-cli run --library lib app.export ids='[1]' path=out/lib-sky.jpg longEdge=600
```
Expected: `lib/` holds `catalog.log`, `catalog.snap`, `catalog.lock`, `view.json`. `catalog.query` shows
id 1 with `rating 4`, `title "Blue sky"`, `edited true`; `develop.get` shows `light.exposure 0.6`.
Re-importing the same folder reports `duplicates` (reason `content`) and imports nothing.

## 11. Read and strip metadata

```bash
lightcraft-cli run --import out/lib-sky.jpg photo.allMetadata
lightcraft-cli run --library lib app.export ids='[1]' path=out/lib-sky-nometa.jpg metadata=none
lightcraft-cli run --import out/lib-sky-nometa.jpg photo.allMetadata
```
Expected: first → `xmp` includes `dc:title "Blue sky"`, `dc:subject "sky; test"`, `xmp:Rating 4`;
the `metadata=none` export → `{"exif":[],"xmp":[]}`.

## 12. Save a look as a preset and reuse it in `render`

```bash
lightcraft-cli run --library lib library.select ids='[1]' active=1 preset.create name="My Look" \
  preset.export path=out/my.lcpreset
lightcraft-cli render in/sunset.jpg -o out/sunset-mylook.jpg --settings out/my.lcpreset --size 300
```
Expected: `preset.create` → `{"id":"user.41.my-look"}`; `render` writes 300×225.
`render --preset user.41.my-look` fails (`unknown preset`): user presets live in the library.

## 13. Demo library (safe sandbox)

```bash
lightcraft-cli run --demo catalog.stats
lightcraft-cli run --demo app.export ids='[1,2]' dir=out/demo longEdge=400
```
Expected: 24 synthetic photos, 6 albums; `out/demo/LC01207.jpg`, `LC01214.jpg`.

## 14. Command script file

```bash
printf '%s\n' '{"command":"develop.auto"}' \
  '{"command":"app.export","params":{"path":"out/script.jpg","longEdge":300}}' > job.jsonl
lightcraft-cli run --import in/sky.jpg --script job.jsonl
```
Expected: two JSON result lines, exit 0, `out/script.jpg` 300×225.

## 15. HDR merge (synthetic brackets)

```bash
lightcraft-cli synth-merge hdr -o syn                   # bracket-0/1/2.dng
lightcraft-cli merge hdr --preview out/hdrprev.png syn/bracket-*.dng   # preview only, ≤1024 px
lightcraft-cli merge hdr syn/bracket-*.dng              # writes syn/bracket-0-HDR.dng
lightcraft-cli render syn/bracket-0-HDR.dng -o out/hdr.jpg --size 600
```
Expected: JSON with `ev` ≈ [-2, 0, 2], `path …/bracket-0-HDR.dng`, then `wrote out/hdr.jpg (600×400)`.

## 16. Headless UI screenshot

```bash
lightcraft-cli snapshot --demo -o out/ui.png --size 1200x800
```
Expected: `wrote out/ui.png (1200×800)` in about 2 s.

## Errors and exit codes seen

| Command | Message | Exit |
|---|---|---|
| `render … --set light.exposur=0.5` | `unknown control` | 1 |
| `render in/nope.jpg …` | `not a readable photo` | 1 |
| `render a.jpg -o a.jpg` | `LightCraft never writes over an original` | 1 |
| `render … --set light.exposure=9` | clamped to 5, no warning | 0 |
| `run … develop.set control=nope …` | `"ok":false`, `1 command(s) failed` | 1 (also with `--keep-going`) |
