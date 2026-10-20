# FilmCraft recipes

Every recipe here was run against `filmcraft-cli 0.9.0`, headless. Outputs are trimmed. IDs (items,
clips, sequences) are the ones that run produced, so read yours from each command's JSON result.
Use absolute paths inside JSON. `$F` stands for `filmcraft-cli`.

Ticks: 254016000000 per second. For example, 1.5 s is 381024000000 and 2 s is 508032000000.

---

## 1. Get sample media without ffmpeg (from the built-in demo)

```bash
$F --demo export "$PWD/demo3s.mp4" --start 0 --end 3      # 1920x1080 23.976 H.264 + AAC, 72 frames
$F --demo export "$PWD/clipB.mp4"  --start 6 --end 10
$F --demo export "$PWD/tone.wav"   --start 0 --end 4      # format inferred from extension
```
Result: `{"job":1,"offlineMedia":[],"path":…,"result":{"bytes":3761360,"frames":72,…}}` on stdout,
`exported … in 2.0s` on stderr, exit 0. You can open the demo project (`--demo`) and inspect it, but it
has no path on disk.

## 2. Probe media

```bash
$F probe demo3s.mp4 --compact
```
Result: `{"container":"MPEG-4","duration":762810048000,"kind":"Movie","video":{"codec":"H.264 (High)",
"width":1920,"height":1080,"frame_rate":{"num":24000,"den":1001},"color":{…Bt709…}},"audio_streams":[{"codec":"AAC","channels":2,"sample_rate":48000}]}`.
`duration` is in ticks: 762810048000 / 254016000000 = 3.003 s. For a WAV, `kind` is `"AudioOnly"` and
`video` is `null`.

## 3. New project, import, sequence (one script)

```bash
cat > build.jsonl <<EOF
{"id":"file.import","params":{"paths":["$PWD/demo3s.mp4","$PWD/clipB.mp4","$PWD/tone.wav"]}}
{"id":"file.newSequence","params":{"name":"Main","width":1920,"height":1080,"fps":25}}
EOF
$F --save-as "$PWD/promo.fcproj" run build.jsonl
```
Result: one JSON line per command, for example `{"id":"file.import","line":1,"ok":true,"result":{"errors":[],"items":[1,2,3]}}`
and `{"id":"file.newSequence",…,"result":{"sequence":10}}`. Saving also creates `FilmCraft Previews/`
next to the project.

You can run these steps one at a time instead:
`$F exec file.newProject name=Promo --save-as promo.fcproj`, then
`$F --project promo.fcproj --save import a.mp4 b.mp4` (prints `{"errors":[],"items":[1,2]}`), then
`$F --project promo.fcproj --save exec file.newSequence name=Main width=1920 height=1080 fps=25`.

To make a sequence that matches a clip: `{"id":"file.newSequenceFromClip","params":{"items":[1]}}`
returns `{"clips":[6,7],"sequence":4}`.

## 4. Place, razor, ripple delete, trim, gain, music bed, title, caption

```bash
cat > edit.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"timeline.place","params":{"items":[1,2],"track":"V1","seconds":0}}
{"id":"timeline.razor","params":{"seconds":1.5}}
EOF
$F --project promo.fcproj --save run edit.jsonl
```
Result: `place` returns `{"clips":[12,13,15,16],"placed":[[12,13],[15,16]]}`, which are linked
video/audio pairs placed back to back. `razor` without `track` cuts every track
(`{"cuts":2}`). `{"frame":75,"track":"V1"}` cuts only V1.

```bash
cat > edit2.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"edit.rippleDelete","params":{"clips":[17,19]}}
{"id":"timeline.trim","params":{"clip":15,"edge":"out","mode":"ripple","deltaFrames":-25}}
{"id":"clip.audioGain","params":{"clips":[13,16],"mode":"set","db":-6}}
{"id":"timeline.place","params":{"item":3,"track":"A2","seconds":0}}
{"id":"graphics.newText","params":{"text":"SUMMER PROMO","size":140,"seconds":2,"time":0}}
{"id":"captions.newTrack","params":{"format":"Subtitle"}}
{"id":"captions.add","params":{"text":"Hello from FilmCraft","seconds":0.5,"durationSeconds":2}}
EOF
$F --project promo.fcproj --save --keep-going run edit2.jsonl
```
Result: all lines `ok:true`. Trim returns `{"delta":-254016000000}`, gain returns
`{"gainDb":[{"clip":13,"gainDb":-6.0},…]}`, the music placement (a WAV, audio only) returns
`{"clips":[20]}`, the title `{"clip":22,"layer":0}` lands on V2, the caption track is `{"track":24}`
and the caption is `{"caption":25}`. `inspect sequence` then shows V1 at 0–1.5 s and 1.5–4.54 s,
V2 holding the title, A1 at -6 dB and A2 holding tone.wav. Check captions with `exec captions.list`.

Read the timeline compactly:
```bash
$F --project promo.fcproj inspect sequence | python3 -c 'import json,sys;s=json.load(sys.stdin)
for t in s["video"]+s["audio"]:
  print(t["name"],[(i["clip"],i["name"],i["startFrame"],i["endFrame"],i["gainDb"]) for i in t["items"]])'
```

## 5. Center and style a title

```bash
cat > title.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"graphics.set","params":{"clip":22,"layer":0,"props":{"font_style":"Bold","fill_color":"#ffcc00","stroke":true,"stroke_width":6}}}
{"id":"graphics.align","params":{"clip":22,"layers":[0],"align":"hcenter"}}
{"id":"graphics.align","params":{"clip":22,"layers":[0],"align":"top"}}
{"id":"graphics.list","params":{"clip":22}}
EOF
$F --project promo.fcproj --save run title.jsonl
$F --project promo.fcproj render --seconds 1.0 --out frame.png --scale 0.5
```
Result: a yellow, bold, stroked title centered at the top of a 960x540 PNG. Before the fix, the default
text started at the frame center and was cut off on the right. You can also set
`{"props":{"align":"center","position":[540,500]}}`, where `position` is the baseline anchor point.

## 6. Basic color

```bash
cat > color.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"effects.apply","params":{"clips":[12],"effect":"Lumetri Color"}}
{"id":"effects.setParam","params":{"clip":12,"effect":"lumetri","param":"exposure","value":0.5}}
{"id":"effects.setParam","params":{"clip":12,"effect":"lumetri","param":"saturation","value":130}}
{"id":"effects.setParam","params":{"clip":12,"effect":"lumetri","param":"temperature","value":20}}
{"id":"lumetri.applyPreset","params":{"name":"Golden Dusk","clips":[15]}}
EOF
$F --project promo.fcproj --save --keep-going run color.jsonl
```
Result: `setParam` returns `{"keyframes":0}` and the preset returns `{"clips":1,"preset":"Golden Dusk"}`.
`inspect sequence` shows `lumetri` with `exposure Float(0.5)`, `saturation Float(130.0)` (neutral is 100)
and `temperature Float(20.0)`. Get the parameter names from the `effects[].params` keys in
`inspect sequence`: exposure, contrast, highlights, shadows, whites, blacks, temperature, tint,
saturation, vibrance, look, vignette_*, wheel_*, curve_*, hsl_*. Get preset names from
`exec lumetri.presets`, which has the folders Cinematic, Film Emulation, Monochrome and Technical.

## 7. Transition, speed, normalize, track volume

```bash
cat > more.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"timeline.razor","params":{"frame":75,"track":"V1"}}
{"id":"sequence.applyVideoTransition","params":{"clip":15,"effect":"cross_dissolve","frames":10,"edge":"in"}}
{"id":"clip.speedDuration","params":{"clips":[12],"speed":50,"ripple":true}}
{"id":"clip.audioGain","params":{"clips":[20],"mode":"normalizeMax","db":-3}}
{"id":"mixer.setStrip","params":{"strip":"A2","volumeDb":-12}}
EOF
$F --project promo.fcproj --save --keep-going run more.jsonl
```
Result: `{"transition":28}`. The speed change doubles clip 12 to 75 frames and ripples what follows,
so `inspect` shows `speed:0.5`. Normalize returns `{"gainDb":[{"clip":20,"gainDb":9.6…}]}` and the
mixer strip returns its full state with `volumeDb:-12.0`.

## 8. Lower third from a built-in template

```bash
printf '%s\n' '{"id":"sequence.open","params":{"item":10}}' \
 '{"id":"graphics.template.apply","params":{"template":"Lower Third – Slab","values":{"Name":"Ana Gómez","Role":"Director"},"time":508032000000}}' \
 | $F --project promo.fcproj --save run -
```
Result: `{"clip":29,"controls":[{"id":"name",…},{"id":"role",…},{"id":"slab_color",…},…],"template":"builtin:lower-third-slab"}`.
The rendered frame shows a blue slab in the lower left. `exec graphics.template.list` lists the 8
built-in templates: two lower thirds, two titles, end credits, two callouts and a ticker. Change values
later with `graphics.template.set`.

## 9. Render a frame

```bash
$F --project promo.fcproj render --seconds 1.0 --out frame.png --scale 0.5
```
Result: `rendered 960x540 in 114.5 ms → …/frame.png` on stderr, exit 0. The render includes titles
and caption tracks.

## 10. Export H.264 (whole sequence, and a range)

```bash
$F --project promo.fcproj export "$PWD/promo.mp4"
$F --project promo.fcproj export "$PWD/clip.mp4" --start 0 --end 2 --no-audio
```
Result: `{"job":1,"offlineMedia":[],"path":…,"result":{"bytes":12010701,"frames":114,…}}`. Probing
the file shows 1920x1080, 25/1 fps, H.264 High and AAC. `--no-audio` leaves `audio_streams` empty.

## 11. Vertical 9:16 reel (1080x1920) with burned captions and an SRT sidecar

```bash
cat > build.jsonl <<EOF
{"id":"file.import","params":{"paths":["$PWD/demo3s.mp4","$PWD/clipB.mp4"]}}
{"id":"file.newSequence","params":{"name":"Vertical","width":1080,"height":1920,"fps":30}}
EOF
$F --save-as "$PWD/reel.fcproj" run build.jsonl            # items [1,2], sequence 9

cat > edit.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":9}}
{"id":"timeline.place","params":{"items":[1,2],"track":"V1","seconds":0}}
{"id":"edit.selectAll","params":{}}
{"id":"clip.fillFrame","params":{}}
{"id":"graphics.newText","params":{"text":"NEW DROP","size":160,"seconds":3,"time":0}}
{"id":"captions.newTrack","params":{"format":"Subtitle"}}
{"id":"captions.add","params":{"text":"Link in bio","seconds":1,"durationSeconds":3}}
EOF
$F --project reel.fcproj --save run edit.jsonl
# graphics.newText ID was 17: center it
printf '%s\n' '{"id":"sequence.open","params":{"item":9}}' \
 '{"id":"graphics.set","params":{"clip":17,"layer":0,"props":{"align":"center","position":[540,500],"font_style":"Bold"}}}' \
 | $F --project reel.fcproj --save run -
$F --project reel.fcproj export "$PWD/reel-9x16.mp4" --start 0 --end 3 \
   --settings '{"burnCaptions":true,"captionSidecar":"srt"}'
```
Result: `clip.fillFrame` returns `{"clips":[{"clip":11,"scale":177.77…},…]}`. The export has 90
frames at 1080x1920 and 30 fps, and `reel-9x16.srt` is written next to it
(`00:00:01,000 --> 00:00:03,000 Link in bio`, clipped to the range). Re-importing both files and
rendering a frame confirmed that the caption appears **only** when `burnCaptions` is true.

To make a vertical file from a 16:9 sequence without editing it, use the
`--preset "Social Vertical 1080×1920"` preset, which scales to fill
(`$F --demo export demo-9x16.mp4 --preset "Social Vertical 1080×1920" --start 0 --end 2` gives
1080x1920).

## 12. Export presets, other formats, loudness

```bash
$F export --list-presets --compact            # 39 presets: name, category, format, frameSize
$F export --list-presets vertical             # filter by text
$F --demo export demo.gif --preset "Animated GIF 640×360" --start 0 --end 1
$F --demo export demo.mov --format prores --start 0 --end 1 --scale 0.5
$F --demo export mix.wav --start 0 --end 2    # 48 kHz 16-bit stereo PCM
$F --project promo.fcproj export loud.mp4 --start 0 --end 2 \
   --settings '{"effects":{"loudness":{"enabled":true,"target_lufs":-14,"true_peak_dbtp":-1}}}'
# same thing through the command's flat params:
$F --project promo.fcproj exec file.exportMedia '{"path":"/abs/loud2.mp4","format":"h264","loudnessLufs":-14,"range":"custom","startSeconds":0,"endSeconds":2,"wait":true}'
# see every ExportSettings key and the resolved output before rendering:
$F --project promo.fcproj exec export.resolve '{"format":"h264","path":"x.mp4"}'
```
All of these exit 0. `--settings '{"loudnessLufs":-14}'` fails with exit 1 and `unknown key
loudnessLufs`, because `--settings` only accepts nested ExportSettings keys.

## 13. Interchange: FCPXML, AAF, EDL, OTIO, FCP7 XML, captions, markers

```bash
cat > ix.jsonl <<EOF
{"id":"sequence.open","params":{"item":10}}
{"id":"file.exportFcpxml","params":{"path":"$PWD/main.fcpxml"}}
{"id":"file.exportAaf","params":{"path":"$PWD/main.aaf"}}
{"id":"file.exportEdl","params":{"path":"$PWD/main.edl"}}
{"id":"file.exportOtio","params":{"path":"$PWD/main.otio"}}
{"id":"file.exportFcp7Xml","params":{"path":"$PWD/main.xml"}}
{"id":"captions.export","params":{"path":"$PWD/main.srt"}}
{"id":"markers.add","params":{"target":"program","time":254016000000,"name":"Beat"}}
{"id":"markers.exportCsv","params":{"path":"$PWD/markers.csv"}}
EOF
$F --project promo.fcproj --keep-going run ix.jsonl
```
Result: every line is `ok:true`, and each export returns a `report` array that lists what was lost.
For example: graphic clips become media-less or offline clips, or gaps in AAF; Lumetri is written as
a FilmCraft-specific filter in FCPXML; sub-frame positions are rounded. FCPXML is version 1.10. The
EDL holds V1 plus audio and uses relative `SOURCE FILE` paths.

## 14. Offline media and relinking

```bash
$F --project o.fcproj exec media.findMissing --compact     # {"missing":[{"item":1,"path":…,"status":"missing"}]}
$F --project o.fcproj render --seconds 0.5 --out x.png      # warning + exit 1 (placeholder frames)
$F --project o.fcproj render --seconds 0.5 --out x.png --allow-offline   # exit 0
$F --project o.fcproj --save exec media.relink '{"item":1,"path":"/abs/moved.mp4","force":true}'
$F --project o.fcproj exec media.autoRelink '{"folder":"/abs/newfolder"}'
```
Without `force:true`, relinking to a file with another name fails with "file name differs". After
the relink, `render` exits 0 again.

## 15. `run` semantics and exit codes (tested)

```bash
printf '%s\n' '{"id":"sequence.open","params":{"item":10}}' \
  '{"id":"markers.add","params":{"target":"program","name":"A"}}' \
  '{"id":"nope.cmd","params":{}}' | $F --project p.fcproj --save run - --compact
```
- If you omit `--keep-going`, the run stops at the bad line and exits 1. The project file is **not**
  changed, even with `--save`.
- With `--keep-going`, the remaining lines still run and the successful ones are saved, but the exit
  code is still 1.
- Lines starting with `#` are comments. `run -` reads from stdin.
- `$F bogus` exits 2 (usage). `$F exec nosuch.cmd` exits 1 (`unknown command`).
  `--project /missing.fcproj` exits 1.

## 16. "No sequence is open" (intermittent)

Sometimes, right after a saved edit (seen after newly imported media was placed), a new process
rejected `timeline.razor` and `effects.apply` with
`command … is not available right now: no sequence is open`, even though the project's
`open_sequences` listed the sequence. It couldn't be reproduced reliably. Starting the script with
`{"id":"sequence.open","params":{"item":<seq>}}` always fixed it, so every recipe above does that.
