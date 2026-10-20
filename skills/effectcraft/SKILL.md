---
name: effectcraft
description: EffectCraft is an open-source After Effects-style motion graphics compositor (comps, layers, keyframes, effects, expressions, ExtendScript-like JSX, Essential Graphics templates, Lottie). This skill drives its headless CLI `effectcraft-cli` to build and edit .ecproj projects, animate text/shape/solid layers, apply effects, run .jsx scripts, and render PNG frames, MP4/H.264, HEVC, ProRes, WebM, GIF or image sequences, export/import Lottie (.json/.lottie), and fill .ectemplate templates from JSON values. Use it for motion graphics, title cards, lower thirds, kinetic type, logo reveals, animated social posts, 9:16 reels/stories, batch-rendered video variants, After Effects scripting or expressions, Lottie animations, or any .ecproj/.ectemplate/.jsx file, even if the user never says "EffectCraft" and only asks to "animate", "make a motion graphic" or "render a title video".
---

# EffectCraft (`effectcraft-cli`)

EffectCraft is an After Effects-like compositor written in Rust. Projects are `.ecproj` files holding
compositions, layers (text, shape, solid, null, adjustment, footage, precomp, camera, light), keyframed
properties, effects and AE-style expressions. The CLI runs the same engine headless: it reads/writes
`.ecproj`, imports footage and Lottie, runs JavaScript with the After Effects object model, renders frames
and movies, exports Lottie, and renders Essential Graphics templates (`.ectemplate`) with values.

## Before you start
- Check `command -v effectcraft-cli`. If missing, use the `artcraft` skill's installer
  (`skills/artcraft/scripts/craft-clis.sh install effectcraft`; Windows: `craft-clis.ps1`).
- Headless by default; no GUI needed. `--bridge PORT` only applies when the EffectCraft app is already
  running with its bridge open and you want to drive the live session instead of a file.
- Every invocation is a fresh process. State lives only in the `.ecproj` you pass with `--project`;
  persist edits with `--save` (same file) or `--save-as NEW.ecproj`.

## When to use / when not
- Use for animated graphics, titles, templated video variants, Lottie, AE-style scripting and expressions.
- Cutting/assembling long footage on a timeline is `filmcraft`; audio mixing is `soundcraft`;
  still image editing is `photocraft`; vector illustration is `vectorcraft`.
- Generating new imagery/video/voice from prompts is the `genai` skill's job; bring the result in here
  with `file.import` and composite it.

## Core workflows

Command shapes: `[--project F | --empty] [--save | --save-as F] <subcommand> ...`.
`<comp>` = id, name or `-` (active comp); `<layer>` = id, `#n` (stack index) or name.

```bash
# 1. New project + 9:16 comp + layers in one call (run = several commands in order)
effectcraft-cli --empty --save-as reel.ecproj run \
  comp.new '{"name":"Reel","width":1080,"height":1920,"frameRate":30,"duration":5,"background":"#101820"}' \
  layer.newSolid '{"name":"BG","color":"#1e3a5f"}' \
  layer.newText '{"text":"HELLO","size":160,"fill":"#ffffff"}' \
  layer.newShape '{"kind":"ellipse","name":"Dot","size":[300,300],"fill":"#ff5a36","position":[540,1400]}'

# 2. Keyframes: set with --time (creates a key), inspect paths with props
effectcraft-cli --project reel.ecproj props Reel Dot --flat
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/position '[540,2200,0]' --time 0
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/position '[540,1400,0]' --time 1.5

# 3. Effect + parameter + expression
effectcraft-cli --project reel.ecproj --save run effect.apply '{"effect":"Gaussian Blur","layers":["Dot"]}'
effectcraft-cli --project reel.ecproj --save set Reel Dot 'effects/#1/blurriness' 20
effectcraft-cli --project reel.ecproj --save set Reel Dot transform/rotation 0 --expression 'time*90'

# 4. Preview one frame (cheap; look at it before rendering a movie)
effectcraft-cli --project reel.ecproj render-frame --comp Reel --time 1.5 --max-side 960 --out preview.png

# 5. Render (format inferred from extension or --format; --end is exclusive)
effectcraft-cli --project reel.ecproj render --comp Reel --out reel-9x16.mp4 --start 0 --end 2
effectcraft-cli --project reel.ecproj render --comp Reel --out loop.gif --end 1 --resolution quarter --fps 15
effectcraft-cli --project reel.ecproj render --comp Reel --out 'seq/f_[####].png' --end 1

# 6. Lottie export (warnings list what Lottie cannot carry)
effectcraft-cli --project reel.ecproj exec file.exportLottie --params '{"comp":"Reel","path":"reel.json"}'

# 7. JSX with the After Effects object model (use --save-as to keep the result)
effectcraft-cli --empty --save-as promo.ecproj script build.jsx
effectcraft-cli --project promo.ecproj script --eval 'app.project.activeItem.numLayers'

# 8. Template variants: built-in template -> .ectemplate -> render with values
effectcraft-cli --empty exec templates.create --params '{"id":"vertical-story","projectPath":"story.ecproj"}'
effectcraft-cli --project story.ecproj exec essential.exportTemplate --params '{"path":"story.ectemplate"}'
printf '%s' '{"Headline":"BIG\nNEWS","Call to Action":"Shop now"}' > v.json   # printf keeps \n literal
effectcraft-cli render --template story.ectemplate --values v.json --out story-9x16.mp4 --end 3
```

Built-in templates (`exec templates.list`): lower-third, title-card, logo-reveal, kinetic-type,
social-square, vertical-story, slideshow, text-orbit-3d. Read a template's control names and types with
`exec essential.templateInfo --params '{"path":"T.ectemplate"}'`; the `--values` keys are those names.

## Finding the right command
- `effectcraft-cli commands --filter TEXT` lists engine commands (731) with their param spec;
  add `--json` for the full, unclipped spec plus `enabled`/`why` (why a command can't run now).
- `exec <id> --params JSON` runs one; `run <id> <json> ...` chains several in one process, which is
  how you combine a selection command (`layer.select`, `keys.select`) with one that acts on the selection.
- `exec effect.list --params '{"filter":"glow"}' --json` gives effect names and parameter ids/ranges.
- `props <comp> <layer> --flat` prints every property path, its type and keys/expression markers.
- Offline: grep `references/commands.md` (generated catalog; long specs clipped).

## Safe defaults
- Work on a copy or `--save-as new.ecproj`; render outputs overwrite existing files silently,
  so pick fresh names.
- Always pass `--project` or `--empty`. Without them most subcommands load the bundled demo project.
- Quote JSON and paths with single quotes; quote `effects/#1/...` paths (the `#` is safe but the
  habit avoids shell surprises).
- For MCP use, `effectcraft-cli mcp --automation-read-root DIR --automation-write-root DIR` confines file
  access (scripts are then refused); `--autosave` keeps unsaved headless work.

## Gotchas
- **No `--save`, no change.** Edits without `--save`/`--save-as` exit 0 and are discarded. With `--save`
  the JSON output is wrapped as `{"result": ..., "saved": "file"}`; without it the result is bare.
- **Time is seconds, snapped to frames.** `comp.new` defaults to 29.97 fps, so `duration:1` becomes
  1.001 s and keys land on 0.2002 etc. Pass `"frameRate":30` (or 24/25/60) for clean numbers.
- **`set --time` is layer time; `get --time` is comp time.** They match unless the layer's start was
  moved. `prop.addKey`/`keys.set` accept `"timeBase":"comp"`.
- `set` on an already-animated property without `--time` overwrites the key at time 0 (the current time).
- Vectors: a 2-value array on a vec3 property sets z to 0 (harmless on 2D layers, flattens 3D layers).
  A bare scalar on scale is uniform (`80` -> `[80,80,80]`). Colors accept `#hex` or `[r,g,b]` 0-1.
- `get` returns `value` (pre-expression) and `evaluated` (post-expression) when an expression is set.
- `render --end` is exclusive: `--start 0 --end 2` at 30 fps = 60 frames. Image sequences get
  `_00000` numbering unless you give a `[####]` pattern; missing output dirs are created.
- `render-frame --transparent` only yields RGBA when the comp actually has transparency (no full-frame
  solid). Movie alpha: `--format prores --channels rgba`.
- `--template` needs a `.ectemplate` file path, not a built-in id; unknown `--values` keys fail with the
  list of valid control names.
- Lottie: unsupported effects (e.g. Glow) are skipped and expressions dropped unless
  `"includeExpressions":true`; read the `warnings` array. `.lottie` output is a zip.
- `script` errors exit 1 with `file:line:col`. `script` without `--project` starts empty (unlike `info`).
- Exit codes: 0 ok, 1 command/param error (message on stderr), 2 usage error (prints help).

## References
- `references/recipes.md` — tested end-to-end recipes (reel build, keyframes + easing, effects,
  expressions, JSX idioms, render formats, Lottie round-trip, templates, footage import). Read it before
  writing a multi-step job or a JSX script.
- `references/commands.md` — the full command catalog; grep it for a command id or parameter name.
