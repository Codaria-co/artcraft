# Crafting App CLI issues found while building this plugin

These issues were observed in October 2026 against the CLI versions listed for each app. The skills work around every one of them. Each issue is a candidate for an upstream report at `github.com/storytold/<app>/issues`.

## cadcraft-cli 0.8.0
- **Data loss:** `run part.dxf --metric --save out.dxf` ignores the file and saves an empty drawing, with exit 0. The last option among FILE, `--sample` and `--metric` wins. Putting `--metric` first works.
- `zoom.window {"p1","p2"}` does nothing but exits 0. `zoom {"mode":"window"}` works.
- Saving as DWG drops the current layer, and `saveas` to DWG reports `"binary": false`.
- A bad answer inside a `.scr` command exits 0 and saves anyway.

## wordcraft-cli 0.8.0
- `run --template <file or unknown name>` exits 0 and writes an empty document. Only built-in templates and `file.newFromTemplate` work.
- Markdown import drops images silently. Markdown export writes a link to an image file that it never creates.
- Converting from PDF fails with exit 1, although the README implies PDF input is supported.
- `run` without `--save` exits 0 and throws the edits away.

## designcraft-cli 0.10.0
- The `units` parameter is ignored: `file.new {"units":"millimeters","width":148}` makes a 148 pt page.
- `script --keep-going` exits 0 even when steps fail.
- A relative CSV path in data merge gives "path is not valid" and merges cached rows instead. Relative image paths make preflight report a missing link.
- The help says unknown parameters are ignored, but `file.new` and `frame.create` reject them.

## gridcraft-cli 0.9.0
- `range.fill` with an explicit range anchors relative references to the active cell: filling `=B2+C2` into D2:D4 writes `=E3+F3`.
- `run --help` fails with "unknown option" and exit 1.
- `eval` exits 0 on formula errors, and a syntax error comes back as `#NAME?`.
- `convert` can't write `.pdf`, and its `.json` is the native workbook format, not JSON records.

## soundcraft-cli 0.10.0
- `file.bounce_mix` with float JSON `start`/`end` bounces 1 sample of silence and exits 0.
- The bounce format isn't checked against the extension: FLAC data can end up in a `.wav`.
- `commands --filter X` prints nothing and exits 0. The `engine.plugins` filter is ignored. Out-of-range plugin values are clamped silently.
- Bounces are stereo-only.

## lightcraft-cli 0.9.1
- `render <folder> -o x.jpg` exits 0 but renders only one photo.
- `app.export path=…` with several photos ignores the file name and writes every photo to the current directory.
- `commands --filter` is ignored. The `.gif` error hint leaves out `.jxl` and `.psd`, which do work.

## pdfcraft-cli 0.9.0
- The CLI zip doesn't include the OCR models. Pointing `PDFCRAFT_MODELS` at the app bundle's `Resources/models` works.
- `redact_mark` with `"pattern":"ssn"` skips numbers that aren't valid US SSNs, such as ones starting with 9.
- `audit` misses a black image placed over text. `check` exits 0 when files fail to open. `render` accepts a higher dpi than `page_render` allows.
- `--password` works on `text`, `render`, `edit` and `extract`, but the help doesn't document it there.

## deckcraft-cli 0.8.0
- `commands --filter X` prints nothing and exits 0, because the filter is positional.
- `.svg` export is refused.
- `insert.picture` with a `rect` stretches the image instead of keeping its aspect ratio.
- `file.export` counts a list of slides from 0 but a range string from 1.
- In a column chart, the y axis starts at 0.95.

## vectorcraft-cli 0.13.1
- `convert` accepts OUT == IN and overwrites the input when the read was lossless.
- Missing fonts fall back silently. Only `info` reports them as `missing`.

## photocraft-cli 0.10.0
- Bounds formats differ between commands: some use `[x,y,w,h]`, others `[x0,y0,x1,y1]`. Scales differ too: opacity is 0–1 or 0–100 and quality is 1–100 or 0–12, depending on the command.
- `run` without `--out` writes nothing, with exit 0.

## filmcraft-cli 0.9.0
- Sometimes a project saved with an open sequence fails with "no sequence is open". The workaround is to call `sequence.open` first.
- The EDL export report suggests `export_edl_per_track`, a command that doesn't exist.
- `describe` shows `"enabled": false` for commands that then run fine.

## effectcraft-cli 0.11.1
- In JSX, setting Scale to `[100,100]` leaves z at 0, which differs from After Effects.
- Rendering a template renames the comp.

## figcraft-cli 0.8.0
- `export -o dir/` only exports the first page.
- `text.create` lists `x`/`y` as required, but runs without them and places the text at 0,0.
