# soundcraft-cli recipes

Every recipe below was run against `SoundCraft CLI 0.10.0` on a 3.53 s mono speech file
(`voice.wav`, 44.1 kHz/16-bit, and `voice48.wav`, 48 kHz/16-bit). Outputs are shown trimmed.
All commands exit 0 unless noted. Run them from the folder that holds the inputs; relative paths
resolve against the current directory.

## 1. Inspect a file or session

```bash
soundcraft-cli info voice.wav
```
```json
{"bwf": null, "channels": 1, "format": "Wav", "frames": 155538,
 "sample_format": "Int16", "sample_rate": 44100, "seconds": 3.526938775510204}
```
Reads WAV, AIFF (`"format":"Aiff"`), FLAC and AAC/M4A (`"sample_format":"Compressed"`).
`info session.scraft` prints a text report (session name, rate, bit depth, files, track listing
with clip start/end times, markers). A missing file prints `soundcraft-cli: x.wav: No such file
or directory` and exits 1.

## 2. Convert bit depth, sample rate, normalize, format

```bash
soundcraft-cli convert voice.wav v24.wav --bit-depth 24 --rate 48000 --normalize
# wrote v24.wav (1 ch, 48000 Hz, 3.53 s)      -> info: Int24, 48000 Hz
soundcraft-cli convert voice.wav v32.wav --bit-depth 32f   # Float32
soundcraft-cli convert voice.wav v.flac                    # FLAC, Int24 by default
```
- Output format comes from the extension: wav, aif, aiff, flac. `.mp3` fails:
  `cannot write .mp3 files (supported: wav, aif, aiff, flac)`, exit 1.
- `--bit-depth 8` fails: `expected 16, 24 or 32f`, exit 1.
- `--normalize` is a peak normalize to about -0.1 dBFS.
- `convert x.wav x.wav --normalize` overwrites the input without asking. Use a new name.

## 3. Import, gain, fades, plugin chain, save and bounce (one call)

```bash
soundcraft-cli run \
  --cmd 'file.import_audio={"path":"voice48.wav"}' \
  --cmd 'clip.gain={"clips":[3],"db":-3}' \
  --cmd 'edit.fades_create={"clip":3,"side":"in","length":4800}' \
  --cmd 'edit.fades_create={"clip":3,"side":"out","length":9600,"shape":"s-curve"}' \
  --cmd 'mix.insert={"track":2,"plugin":"eq_7band","params":{"hpf_on":1,"hpf_freq":100}}' \
  --cmd 'mix.insert={"track":2,"plugin":"compressor","params":{"threshold":-24,"ratio":3}}' \
  --cmd 'mix.insert={"track":2,"plugin":"room_reverb","params":{"mix":15}}' \
  --save chain.scraft --bounce chain.wav
```
```text
file.import_audio: {"imported":[{"channels":1,"clip":3,"frames":169293,"source":1,"track":2}]}
clip.gain: {"clips":1}
edit.fades_create: {"fades":1}
edit.fades_create: {"fades":1}
mix.insert: {"plugin":"eq_7band","slot":0,"track":2}
mix.insert: {"plugin":"compressor","slot":1,"track":2}
mix.insert: {"plugin":"room_reverb","slot":2,"track":2}
{"bytes":1015862,"lufs":-27.67,"path":"chain.wav","peak_db":-16.96,"seconds":3.527,"true_peak_db":-16.96}
{"audio_files_written":1,"path":"chain.scraft"}
```
- Without `--in`/`--demo`, `run` starts from a blank 48 kHz/24-bit stereo-main session.
- Fade `length` is in samples (4800 = 0.1 s at 48 kHz). Shapes: linear, equal power, s-curve,
  exponential, logarithmic.
- `chain.wav` is stereo 24-bit 48 kHz. `chain.scraft` sits next to a new `Audio Files/voice48.wav`.
- Check the stored plugin values with
  `soundcraft-cli run --in chain.scraft --cmd 'track.inspect={"track":2}'` (`--inspect` shows
  insert params as `null`).

## 4. Bounce a time range

```bash
soundcraft-cli run --in chain.scraft --bounce part.wav --start 1 --end 3
# {"path":"part.wav","seconds":2.0,...}
soundcraft-cli run --in chain.scraft --bounce part.wav --start 0:01.000 --end 0:02.000
# seconds 1.0
```
Inside JSON params, numbers are samples and strings are seconds or clock time:
```bash
soundcraft-cli run --in chain.scraft --cmd 'file.bounce_mix={"path":"j1.wav","start":48000,"end":96000}'      # 1.0 s
soundcraft-cli run --in chain.scraft --cmd 'file.bounce_mix={"path":"j2.wav","start":"1.0","end":"2.0"}'      # 1.0 s
soundcraft-cli run --in chain.scraft --cmd 'file.bounce_mix={"path":"j3.flac","start":"0:01.000","end":"0:02.500","bit_depth":16,"normalize":true}'
# 1.5 s, 16-bit FLAC, peak_db -0.1
```
Traps seen:
- `"start":1.0,"end":2.0` (JSON numbers) bounced 1 sample of silence, exit 0.
- `"1s"`, `"1000ms"` -> `cannot parse position`, exit 1.
- `--start 48000 --end 96000` on the CLI flags is read as seconds -> `bounces are limited to 4 hours`, exit 1.
- `"format":"flac"` with a `.wav` path writes FLAC data into the `.wav` file.

## 5. Trim a clip

```bash
soundcraft-cli run --in chain.scraft \
  --cmd 'edit.trim_clip={"clip":3,"start":"0.5","end":"2.5"}' --bounce trimmed.wav
# edit.trim_clip: {"end":120000,"start":24000}
# bounce seconds 2.5  (0.0-0.5 s is silence: the full bounce starts at session 0)
```
Selection-based alternative:
```bash
soundcraft-cli run --in chain.scraft \
  --cmd 'edit.select={"tracks":[2],"start":"0.5","end":"2.5"}' \
  --cmd 'edit.trim_to_selection' --cmd 'track.inspect={"track":2}'
# edit.select: {"selection":{"end":120000,"start":24000},"tracks":[2]}
# edit.trim_to_selection: {"trimmed":1}
```
`edit.trim_to_selection` with a zero-length selection fails with
`not available: make an edit selection first`, exit 1.

## 6. AudioSuite (offline) processing

```bash
soundcraft-cli run --in chain.scraft \
  --cmd 'edit.select={"clips":[3]}' \
  --cmd 'audiosuite.process={"process":"reverse"}' \
  --cmd 'audiosuite.process={"process":"normalize"}' \
  --cmd 'clip.inspect={"clip":3}' --bounce rev.wav
# audiosuite.process: {"process":"reverse","processed":1}
# audiosuite.process: {"process":"normalize","processed":1}
# clip.inspect: {...,"gain_db":0.0,"name":"voice48-reve-norm","source":5,...}
```
Passing `"clips":[3]` inside `audiosuite.process` works without `edit.select`. Processing renders
a new source; clip gain is folded in and reset to 0 dB.

## 7. Mix moves: rename, volume, pan, marker

```bash
soundcraft-cli run --in chain.scraft \
  --cmd 'track.rename={"track":2,"name":"Voice"}' \
  --cmd 'mix.volume={"tracks":["Voice"],"db":-6}' \
  --cmd 'mix.pan={"tracks":["Voice"],"pan":-0.5}' \
  --cmd 'markers.add={"name":"Hook","at":"1.0"}' \
  --save out/mixed.scraft --bounce out/mixed.wav
# mix.volume: {"tracks":1}   mix.pan: {"pan":-0.5}   markers.add: {"id":4,"number":1}
```
Tracks can be referenced by id or name. `out/` must already exist.

## 8. Script file

`podcast.txt`:
```text
# podcast cleanup
session.new {"name":"Episode","sample_rate":48000}
file.import_audio {"path":"voice48.wav"}

mix.insert {"track":2,"plugin":"eq_7band","params":{"hpf_on":1,"hpf_freq":90}}
mix.insert {"track":2,"plugin":"de_esser"}
mix.insert {"track":2,"plugin":"compressor","params":{"threshold":-22,"ratio":3,"makeup":4}}
edit.fades_create {"clip":3,"side":"out","length":24000}
```
```bash
mkdir -p ep
soundcraft-cli script podcast.txt --save ep/episode.scraft --bounce ep/episode.wav
# prints one `ID: result` line per command; writes ep/episode.scraft, ep/episode.wav, ep/Audio Files/
```
- Comments (`#`) and blank lines are fine; no-param commands may omit the JSON.
- A bad line fails with `podcast.txt:N: bad JSON: ...`, exit 1.
- Without `mkdir -p ep`: `ep/episode.wav: audio write failed: No such file or directory`, exit 1,
  and nothing is saved.
- If the script ends with an `edit.select` range, the bounce covers only that range (3.0 s in the
  test). Leave selection out, or pass explicit range params, for a full mix.

## 9. Stems

```bash
mkdir -p stems
soundcraft-cli run --demo --cmd 'file.bounce_stems={"dir":"stems","start":"0","end":"5.0","format":"flac"}'
# file.bounce_stems: {"files":["stems/Midnight Groove - Kick.flac", ... "stems/Midnight Groove - Lead.flac"]}
```
Files are named `<session name> - <track name>.<ext>`.

## 10. Plugins and their parameters

```bash
soundcraft-cli plugins
# eq_1band eq_7band compressor expander_gate de_esser maximizer channel_strip room_reverb
# plate_reverb mod_delay chorus flanger phaser saturator lofi rectifier pitch_shifter time_shift
# gain trim invert dc_offset_removal signal_generator dither
# (instruments: subtractive_synth drum_synth sampler)
soundcraft-cli run --cmd engine.plugins | sed 's/^engine.plugins: //' \
  | jq -c '.[] | select(.id=="compressor") | [.params[] | {id,min,max,unit}]'
# [{"id":"threshold","min":-60,"max":0,"unit":"Db"},{"id":"ratio","min":1,"max":100,"unit":"Ratio"},...]
```
Out-of-range values are clamped silently (`"ratio":200` is stored as 100). Unknown param ids fail:
`compressor has no parameter bogus`, exit 1.

## 11. Discover and describe commands

```bash
soundcraft-cli commands fade          # positional filter
soundcraft-cli describe edit.fades_create
# "params": "{shape?: linear|equal power|s-curve|exponential|logarithmic, tracks?, start?, end?}
#            or {clip: id, side: in|out, length: samples, shape?, curvature?: -1..1}"
soundcraft-cli run --cmd 'session.format_time={"at":48000,"format":"bars_beats"}'
# session.format_time: {"text":"1| 3| 000"}    (min_secs -> "0:01.000", timecode -> "00:00:01:00")
soundcraft-cli run --demo --cmd session.audio_health
# {"audio_clips":11,"healthy":true,"issue_count":0,...}
```
`describe nope.x` / `--cmd nope.x` -> `unknown command`, exit 1.
