---
name: soundcraft
description: Edit, convert and mix audio from the shell with SoundCraft (open-source Audition, `soundcraft-cli`) - load it before writing sox, ffmpeg or Python audio scripts. For WAV/AIFF/FLAC info (sample rate, bit depth, channels, peak, LUFS), batch conversion with resampling, dither and normalization, trimming, fades, gain, EQ, compression, de-essing, reverb, reverse, podcast and voice-over cleanup, multitrack .scraft sessions, and bouncing mixes or stems. Not for audio on a video timeline (filmcraft) or generating new voices or music (genai). Trigger on .wav/.aif/.aiff/.flac/.scraft files, 'normalize', 'resample', 'bounce', 'clean up this recording', even if SoundCraft isn't named.
---

# SoundCraft (`soundcraft-cli`)

SoundCraft is a Rust audio editor / DAW from the ArtCraft "Crafting Apps" suite. Its native project
is a `.scraft` session (JSON) that references audio in an `Audio Files/` folder next to it. The CLI
reads WAV, AIFF, FLAC and AAC/M4A, and writes WAV, AIFF and FLAC (no MP3 output). Every menu
action of the app is a registry command (`session.*`, `file.*`, `edit.*`, `clip.*`, `mix.*`,
`audiosuite.*`, `markers.*`) that the CLI can run headless against a session.

## Before you start
- Check `command -v soundcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install soundcraft`; Windows: `craft-clis.ps1`).
- Everything here runs headless. The GUI app is optional: it is only needed for
  `soundcraft-cli app [--port P] METHOD [JSON]` (drives a running app's control channel) and
  `soundcraft-cli mcp --connect PORT` (MCP bridged to a running app). Without `--connect`,
  `mcp` runs its own in-process engine on stdio.

## When to use / when not
- Use for: file info, format/bit-depth/rate conversion, peak normalize, voice/podcast chains,
  multitrack mixdowns, range bounces, stems, loudness/peak readout of a bounce.
- Not for: video editing or muxing audio into video (use `filmcraft`), visual effects
  (`effectcraft`), generating new audio/music/voice from a prompt (hand off to the `genai` skill).
- Not for MP3/AAC output: bounce to WAV/FLAC and let another tool encode.

## Core workflows

```bash
# 1. What is this file? (JSON: channels, format, frames, sample_format, sample_rate, seconds)
soundcraft-cli info input.wav
soundcraft-cli info session.scraft          # text summary of a session (tracks, clips, markers)

# 2. Convert: bit depth 16|24|32f, resample, peak-normalize (~ -0.1 dBFS). Format from extension.
soundcraft-cli convert input.wav out-24-48k.wav --bit-depth 24 --rate 48000 --normalize
soundcraft-cli convert input.wav out.flac

# 3. Build a session from a file, process it, save and bounce in one call
soundcraft-cli run \
  --cmd 'file.import_audio={"path":"voice.wav"}' \
  --cmd 'clip.gain={"clips":[3],"db":-3}' \
  --cmd 'edit.fades_create={"clip":3,"side":"in","length":4800}' \
  --cmd 'edit.fades_create={"clip":3,"side":"out","length":9600,"shape":"s-curve"}' \
  --cmd 'mix.insert={"track":2,"plugin":"eq_7band","params":{"hpf_on":1,"hpf_freq":100}}' \
  --cmd 'mix.insert={"track":2,"plugin":"compressor","params":{"threshold":-24,"ratio":3}}' \
  --save voice.scraft --bounce voice-mix.wav

# 4. Bounce a time range of an existing session (CLI flags: bare numbers are SECONDS)
soundcraft-cli run --in voice.scraft --bounce part.wav --start 1 --end 3

# 5. Same job from a script file (one `ID JSON` per line, `#` comments and blank lines OK)
soundcraft-cli script chain.txt --save out.scraft --bounce out.wav

# 6. Stems, one file per track
mkdir -p stems && soundcraft-cli run --in song.scraft \
  --cmd 'file.bounce_stems={"dir":"stems","format":"flac"}'

# 7. Read the session state as JSON (after any --cmd)
soundcraft-cli run --in voice.scraft --inspect
soundcraft-cli run --in voice.scraft --cmd 'track.inspect={"track":2}'
```

In a fresh session, the first imported file lands on track id `2` with clip id `3`. Do not
hard-code that for anything else: read the ids from the `file.import_audio` result line
(`{"imported":[{"clip":3,"source":1,"track":2,...}]}`) or from `--inspect`.

The `--bounce` result line reports `peak_db`, `true_peak_db`, `lufs` and `seconds`, which makes it
a cheap loudness check. `--demo` loads a built-in 7-track sample session ("Midnight Groove") for
trying commands without your own audio.

## Finding the right command
- `soundcraft-cli commands FILTER` lists ids whose name/label matches (positional filter;
  `--filter X` is not a flag and silently prints nothing).
- `soundcraft-cli describe ID` prints the param spec, e.g. `{clip: id, side: in|out, length: samples, shape?}`.
  Its `enabled`/`disabled_reason` reflect an empty session, so "nothing is selected" there is normal.
- `soundcraft-cli plugins` lists plugin ids; for each plugin's parameter ids, ranges and units run
  `soundcraft-cli run --cmd engine.plugins | sed 's/^engine.plugins: //' | jq '.[] | select(.id=="compressor")'`.
- Offline: grep `references/commands.md` (generated catalog of all ~480 ids). Recipes with tested
  output are in `references/recipes.md`.

## Time units (read this before passing positions)
- JSON number = samples at the session rate: `"start":48000` is 1 s at 48 kHz.
- JSON string = seconds or clock: `"start":"1.0"`, `"0:01.000"`, bars `"2|1|000"`.
- CLI `--start/--end` on `run`: bare numbers are seconds (`--start 1 --end 3`).
- Unit suffixes like `"1s"` or `"1000ms"` are rejected. Fade `length` is always samples.
- `session.format_time={"at":48000,"format":"min_secs"}` converts samples to text.

## Safe defaults
- Write to new files. `convert IN IN` and `--save` over an existing session overwrite silently.
- Create output folders first: `--bounce`/`--save` do not create parent directories (exit 1).
- `--save dir/x.scraft` copies imported audio into `dir/Audio Files/`; keep the session and that
  folder together when moving it.
- Quote JSON in single quotes and paths with spaces in double quotes.
- For agents over MCP, confine file access:
  `soundcraft-cli mcp --automation-read-root DIR --automation-write-root DIR` (a root left out
  grants no access of that kind; the roots cannot be combined with `--connect`).

## Gotchas
- `run --in X` without `--save` never changes X; edits only live for that call.
- A bare float in JSON is samples: `"start":1.0,"end":2.0` bounces 1 sample of silence with exit 0.
  Use strings for seconds.
- Bounce range defaults to the edit selection if one exists (an `edit.select` in your chain
  shortens the bounce), otherwise session start (0) to the end of the last clip. Trimming a clip's
  head leaves silence before it in a full bounce; use `--start`.
- `file.bounce_mix` `format` overrides the extension: `{"path":"x.wav","format":"flac"}` writes FLAC
  bytes into a `.wav`. Let the extension choose, or keep them consistent.
- Mono tracks bounce to the stereo main bus about 3 dB lower (pan law); add `clip.gain` +3 dB to
  keep the source level. Bounces are always stereo (no mono export) and 24-bit unless `bit_depth`
  is set. `--normalize` is peak normalization, not loudness: read `lufs` from the bounce result and
  adjust gain if a platform target (e.g. -16 LUFS podcasts) matters.
- Imports at another sample rate are resampled to the session rate (default 48000).
- Plugin values out of range are clamped silently (ratio 200 -> 100); unknown param ids fail.
- `--inspect` shows insert `params: null`; use `track.inspect` to see real plugin values.
- Selection-based commands (`clip.gain` without `clips`, `edit.trim_to_selection`,
  `audiosuite.process` without `clips`) fail with "nothing is selected" unless you pass ids or run
  `edit.select` first. `audiosuite.process` renders to a new source and resets clip gain to 0 dB.
- Each `--cmd` prints `ID: {result}` on stdout before `--inspect` JSON, so strip those lines before
  piping to `jq`, or use `track.inspect`/`clip.inspect` results directly.
- Exit codes: 0 success, 1 for any error (unknown id, bad JSON line `file:N`, missing file,
  unsupported format, disabled command). Commands before the failing one already ran, but nothing
  is saved or bounced.

## References
- `references/recipes.md` - tested end-to-end recipes with expected output; read it when building
  a chain, a script file, a range bounce or stems.
- `references/commands.md` - generated catalog of every command id; grep it to find an id offline,
  then confirm params with `describe`.
