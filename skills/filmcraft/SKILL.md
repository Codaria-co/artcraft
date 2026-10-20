---
name: filmcraft
description: FilmCraft is an open-source, Premiere Pro-style video editor (timeline, Lumetri-style color, titles, captions, audio mixer, export) driven headless through `filmcraft-cli`. Use this skill to cut and assemble video from the shell, including importing clips, placing them on a timeline, razoring, trimming, ripple-deleting, changing speed, adding titles, lower thirds and captions/subtitles (SRT/VTT), grading color, setting audio gain and loudness, and exporting H.264/HEVC/ProRes/DNxHR/GIF/WAV or 9:16 vertical reels for TikTok, Reels and Shorts. It also renders still frames, probes media (codec, fps, duration) and exchanges timelines as FCPXML, FCP7 XML, AAF, OMF, EDL or OTIO. Trigger on .fcproj, .mp4, .mov, .mxf, .srt, .fcpxml, .aaf, .edl or .otio files, on video editing, rough cuts, social video, subtitles or burned-in captions, conform/relink, and on "export a video" requests, even if the user doesn't name FilmCraft.
---

# FilmCraft (`filmcraft-cli`)

FilmCraft is a Premiere-like non-linear video editor written in Rust. Projects are JSON `.fcproj`
files that hold bins, media items, sequences (tracks V1.., A1.., caption tracks C1..), effects and
graphics. The CLI runs the same engine without a UI. It imports video, audio, stills and captions;
exports media through 39 built-in presets (H.264/HEVC/ProRes/DNxHR/APV/MXF/image sequences/GIF/audio);
and reads and writes FCPXML, FCP7 XML, AAF, OMF, EDL, OTIO, SRT/VTT/SCC/TTML and marker CSV.

## Before you start
- Check `command -v filmcraft-cli`. If it's missing, install it with the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install filmcraft`; on Windows use `craft-clis.ps1`).
- The CLI runs headless by default, and you don't need the GUI app for anything here. Only use
  `--bridge 127.0.0.1:PORT` to drive an app the user already started with `filmcraft --control PORT`.
  Bridge mode sends commands to their live session, so use it only when they ask for that.
- Every invocation is a new process. State survives between calls only through `--save` (write back
  to `--project`) or `--save-as <new.fcproj>`. Chain related edits in one `run` script.
- Time is in ticks: **254016000000 ticks per second**. Most commands also accept `seconds=`, `frame=`
  or `timecode=`. `inspect` output gives both ticks (`start`, `end`) and frames (`startFrame`, `endFrame`).

## When to use / when not
- Use it for timeline editing, assembling clips, titles and captions, basic grading, audio levels,
  delivery exports (including vertical reels), still frames, media probing and NLE interchange.
- Use `soundcraft` for detailed audio work like multitrack mixing, restoration or mastering, and
  `effectcraft` for compositing or motion-graphics shots. For a single image, use `photocraft`.
- Generating new footage, images, voices or music from a prompt is the `genai` skill's job. Bring the
  generated files back into this skill to edit them.

## Core workflows
Run each of these from a working folder. Full scripts and outputs are in `references/recipes.md`.

```bash
F=filmcraft-cli
# 1. Inspect media before you edit it (codec, size, fps, duration in ticks)
$F probe clip.mp4 --compact

# 2. Create a project with one sequence. IDs come back in the JSON, so read them from there.
cat > build.jsonl <<'EOF'
{"id":"file.import","params":{"paths":["/abs/a.mp4","/abs/b.mp4","/abs/music.wav"]}}
{"id":"file.newSequence","params":{"name":"Main","width":1920,"height":1080,"fps":25}}
EOF
$F --save-as edit.fcproj run build.jsonl        # -> items [1,2,3], sequence 10 (for example)

# 3. Edit. Put sequence.open first in every script (see Gotchas).
cat > edit.jsonl <<'EOF'
{"id":"sequence.open","params":{"item":10}}
{"id":"timeline.place","params":{"items":[1,2],"track":"V1","seconds":0}}
{"id":"timeline.place","params":{"item":3,"track":"A2","seconds":0}}
{"id":"timeline.razor","params":{"frame":50}}
{"id":"graphics.newText","params":{"text":"SUMMER PROMO","size":140,"seconds":2,"time":0}}
{"id":"captions.newTrack","params":{"format":"Subtitle"}}
{"id":"captions.add","params":{"text":"Hello","seconds":0.5,"durationSeconds":2}}
EOF
$F --project edit.fcproj --save run edit.jsonl

# 4. Look at the timeline and check one frame before a long export
$F --project edit.fcproj inspect sequence
$F --project edit.fcproj render --seconds 1 --out check.png --scale 0.5

# 5. Export (keep test renders short with --start/--end)
$F --project edit.fcproj export out.mp4                                   # H.264, inferred from .mp4
$F --project edit.fcproj export out.mp4 --start 0 --end 3 --settings '{"burnCaptions":true,"captionSidecar":"srt"}'
$F --project edit.fcproj export reel-9x16.mp4 --preset "Social Vertical 1080×1920"   # fills 9:16 from a 16:9 sequence
$F --project edit.fcproj export master.mov --preset "Apple ProRes 422 HQ"

# 6. Hand the timeline to another NLE
printf '%s\n' '{"id":"sequence.open","params":{"item":10}}' \
  '{"id":"file.exportFcpxml","params":{"path":"/abs/main.fcpxml"}}' \
  '{"id":"file.exportAaf","params":{"path":"/abs/main.aaf"}}' | $F --project edit.fcproj run -
```

For a native vertical edit, create the sequence at `width:1080,height:1920`, place the 16:9 clips, and
run `edit.selectAll` and then `clip.fillFrame`. That scales them to 177.8% so they cover the frame.
To grade, run `effects.apply` with `"effect":"Lumetri Color"`, then `effects.setParam` with
`"effect":"lumetri","param":"exposure|contrast|saturation|temperature|…"`. Saturation is neutral at
100. You can also use `lumetri.applyPreset` with a preset name such as "Golden Dusk" or "Neutral Mono".

## Finding the right command
There are 701 command IDs, grouped as `file.*`, `timeline.*`, `clip.*`, `sequence.*`, `graphics.*`,
`captions.*`, `lumetri.*`, `mixer.*`, `export.*`, `media.*` and others.
- `filmcraft-cli commands <word>` searches by ID or label. Add `--json` to get the full parameter specs.
- `filmcraft-cli describe <id>` returns one command's parameter spec. The `enabled` field reflects
  only the current, empty state, so ignore it.
- Read the spec like this: `key:type=default`. A `?` marks an optional key, `a|b` lists the choices,
  `id` is an item or clip number from `inspect`, and `ticks` is an integer time.
- `exec <id> key=value …` parses each value as JSON when it can. For nested values, pass a single JSON
  object instead: `exec timeline.place '{"items":[1,2],"seconds":0}'`.
- List-type helpers: `export --list-presets [query]`, `exec lumetri.presets`,
  `exec graphics.template.list`, `exec captions.list`, `exec media.findMissing`, `exec export.formats`.
- Run `exec export.resolve '{"format":"h264","path":"x.mp4"}'` to see every ExportSettings key that
  `--settings` accepts.
- For offline lookup, grep `references/commands.md`. It was generated from this CLI and has a clipped
  spec for every command.

## Safe defaults
- Write to new files. Use `--save-as new.fcproj` the first time and only `--save` your own copies.
  Never overwrite the user's media, and send exports to new paths.
- Quote paths, and give absolute paths inside JSON scripts. Imports are stored as absolute paths
  resolved from the current folder.
- `run` without `--keep-going` stops at the first failing line and saves nothing, which is a safe
  all-or-nothing edit. With `--keep-going`, the lines that succeeded are saved and the exit code is
  still 1.
- Render a frame with `render --scale 0.5` before a full export, and limit test exports with
  `--start/--end` (in seconds).
- Saving writes a `FilmCraft Previews/` folder next to the `.fcproj`. Tell the user if it shows up
  in their folder.

## Gotchas
- **"command … is not available right now: no sequence is open"**: in some new processes, editing
  commands (`timeline.*`, `effects.*`) fail like this even though the project has an active sequence.
  The failures were intermittent in testing. Put `{"id":"sequence.open","params":{"item":<seq>}}` as
  the first line of every edit script so the problem can't happen. `inspect`, `captions.list` and
  `export` work without it.
- Sub-frame cuts: `timeline.razor seconds=1.5` on a 25 fps sequence cuts at frame 37.5. Interchange
  exports then report rounding. Cut with `frame=` (or seconds that land on whole frames) instead.
- `timeline.place` returns `placed: [[videoClip, audioClip], …]`. Those pairs are linked, so give both
  IDs to `edit.rippleDelete` or `clip.audioGain`. Pass `"video":false` or `"audio":false` when you
  need only one side.
- With no `position`, `graphics.newText` starts left-aligned at the frame center and runs off the
  right edge. Run `graphics.set` with `{"align":"center","position":[W/2,y]}`, or `graphics.align`
  with `align:"hcenter"`. Titles go on the first free video track above your clips.
- `render` draws captions, but `export` does **not** burn them in unless you add
  `--settings '{"burnCaptions":true}'`. The `captionSidecar:"srt"` setting writes `<name>.srt` next to
  the video, clipped to the export range.
- `--settings` takes ExportSettings keys (camelCase, nested), for example
  `{"effects":{"loudness":{"enabled":true,"target_lufs":-14}}}`. The flat keys in
  `file.exportMedia`'s spec (`loudnessLufs`, `startSeconds`, …) work only through
  `exec file.exportMedia '{…,"wait":true}'`. If you pass them to `--settings`, export fails with
  "unknown key".
- Captions don't appear in `inspect sequence`. Use `exec captions.list`.
- Offline (missing) media makes `export` and `render` exit 1 after they draw placeholder frames.
  `media.relink` refuses a file with a different name unless you pass `"force":true`. To repair a
  moved folder, use `media.autoRelink {"folder":…}`.
- With `--save-as`, the project name comes from the file stem, not from `file.newProject name=`.
- Exit codes: 0 means ok. 1 means a command failed, an ID is unknown, or offline media was drawn.
  2 means a usage error, such as an unknown subcommand.
- The EDL export holds only V1 and A tracks. Its report mentions `export_edl_per_track`, but no CLI
  command by that name exists. Use FCPXML, XML, AAF or OTIO for multitrack timelines. Graphic clips
  become gaps or offline clips in every interchange format.

## References
- `references/recipes.md`: tested, step-by-step recipes with outputs. These cover building a new
  edit, a 9:16 reel with burned captions, color, audio and loudness, transitions and speed, templates,
  interchange, relinking, presets and `run` semantics. Read it before a multi-step job.
- `references/commands.md`: the generated catalog of all 701 commands with parameter specs. Grep it
  for a verb such as `grep -n 'speed\|razor' references/commands.md`.
