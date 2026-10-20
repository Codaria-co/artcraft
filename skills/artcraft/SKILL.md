---
name: artcraft
description: Install, update or check the ArtCraft Crafting Apps CLIs (bundled craft-clis script, macOS/Linux/Windows), fix CLI version errors ('unknown command id', outdated <app>-cli), choose which free Craft app replaces a paid tool (Adobe Creative Cloud, Office, AutoCAD, Figma), or chain several Craft apps in one pipeline (generate -> retouch -> lay out -> PDF/video). Use for questions about ArtCraft, getartcraft.com or the suite as a whole and for multi-app jobs. When one app clearly owns the job (edit a PSD, cut a video, lay out a flyer, draw a DXF), load that app's skill instead: photocraft, vectorcraft, filmcraft, effectcraft, pdfcraft, deckcraft, gridcraft, wordcraft, lightcraft, designcraft, soundcraft, cadcraft, figcraft.
---

# ArtCraft suite

The **Crafting Apps** are a family of independent, open-source (MIT/Apache-2.0) desktop apps from the
ArtCraft team (github.com/storytold), each written from scratch in Rust and each shipping a headless
CLI. Every menu item in every app is a *command* with an id and typed params; the GUI, the CLI, an
MCP server and a JSON control channel all dispatch the same commands. So anything a person can click,
you can do from the shell — without opening the app.

**ArtCraft** itself (getartcraft.com) is a separate thing: an AI image/video studio (3D staging,
posing, many hosted models, credit-based). It has no CLI. Generative work goes through the `genai`
skill of this plugin, which can use ArtCraft's Omni API among other providers.

## Pick the app

| Job | App / skill | Like |
|---|---|---|
| Raster editing, retouch, layers, masks, PSD, batch image actions | `photocraft` | Photoshop |
| Vector art, logos, icons, SVG/PDF/AI/EPS conversion | `vectorcraft` | Illustrator |
| Video editing, timeline, color, audio mix, export, FCPXML/AAF | `filmcraft` | Premiere Pro |
| Motion graphics, keyframes, effects, titles, Lottie, templates | `effectcraft` | After Effects |
| PDF info, text, pages, combine/split, OCR, optimize, redaction audit | `pdfcraft` | Acrobat |
| Presentations, .pptx | `deckcraft` | PowerPoint / Keynote |
| Spreadsheets, formulas, .xlsx/.csv | `gridcraft` | Excel |
| Documents, .docx/.odt/.md/.pdf, tracked changes | `wordcraft` | Word |
| Photo library, raw development, develop presets | `lightcraft` | Lightroom |
| Page layout, print/publishing PDFs | `designcraft` | InDesign |
| Audio editing, sessions, effects, bounce | `soundcraft` | Audition |
| 2D CAD, DXF/DWG, .scr scripts | `cadcraft` | AutoCAD |
| UI/interface design, frames, components | `figcraft` | Figma |
| New images/video/audio from a prompt | `genai` | — |

Load the app's skill (`artcraft:<app>`) before driving its CLI: it has the tested workflows,
gotchas and a full command catalog. Details for all apps: `references/apps.md`.

## Install, update, check

The CLIs are single self-contained binaries, one per app, named `<app>-cli`. The bundled script
fetches the latest release from GitHub, verifies it against the release's `SHA256SUMS.txt` (and
Gatekeeper notarization on macOS) and installs it:

```bash
S="<this skill's dir>/scripts"
"$S/craft-clis.sh" check                    # table: installed vs latest, exit 1 if anything is missing/outdated
"$S/craft-clis.sh" install                  # all 13 apps; or name some: install photocraft filmcraft
"$S/craft-clis.sh" update                   # same as install: only replaces older binaries
```

Windows: `powershell -ExecutionPolicy Bypass -File "$S\craft-clis.ps1" install` (installs to
`%LOCALAPPDATA%\Programs\artcraft\bin` and adds it to the user PATH). On Windows, drive the CLIs from
PowerShell 7 (`pwsh`): Windows PowerShell 5.1 strips the inner quotes from JSON passed as an argument
(`--params '{"a":1}'`), so commands fail in confusing ways. Alternatively put the JSON in a script file.

Default install dir is `~/.local/bin` (override with `ARTCRAFT_BIN_DIR`). If that dir is not on
PATH, call the binaries by full path or tell the user how to add it. Set `GITHUB_TOKEN` if GitHub
rate-limits the downloads. The desktop apps are optional — the CLIs run headless. Users install the
GUI apps with ArtCraft Launcher or from each repo's releases; the launcher does not manage the macOS CLIs.

Run `check` when a command fails in a way that smells like version skew (unknown command id,
unknown flag, file written by a newer app). The apps release often; a newer CLI usually fixes it.
After updating, maintainers regenerate the catalogs with `tools/gen-catalog.sh` in the plugin repo.

## How every CLI works

Patterns shared across the suite (each app skill has the exact syntax):

- **One-shot subcommands** — `info`, `convert`, `render`, `export`: quick jobs with no scripting.
- **Command runs** — `run`/`exec` with `--cmd <id> --params '<json>'` (or `id={json}`, `key=value`),
  executed in order on a headless document, then saved/exported. Scripts as JSON lines for longer jobs.
- **Discovery** — `commands` (often `--json`/`--filter`) and `describe <id>` list ids and param specs.
  The registry is the truth; don't guess ids.
- **Live app** — `--bridge`/`--connect`/`app` drive a running GUI started with `--control PORT`
  (loopback only). Use it only when the user wants to watch or keep working in the app.
- **MCP** — `<app>-cli mcp` serves the same commands over stdio. This plugin uses the CLI; mention
  MCP only if the user asks for it, and then confine it (see safety).

## Safety defaults

Read `references/safety.md` once per session before writing files with any Craft CLI. In short:
write results to new files, never overwrite inputs unless asked, quote every path, keep control
ports on loopback, and confine MCP servers with `--automation-read-root/--automation-write-root`.

## Multi-app pipelines

For jobs spanning several apps (e.g. generate a hero image → retouch in PhotoCraft → place in a
DesignCraft flyer → export PDF; or cut a clip in FilmCraft → titles in EffectCraft → vertical 9:16
export), read `references/recipes.md`. Hand-offs between apps are plain files: pick formats every
step reads natively (PNG/PSD for raster, SVG/PDF for vector, ProRes/H.264 for video, WAV for audio).
