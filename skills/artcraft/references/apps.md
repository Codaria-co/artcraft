# The Crafting Apps at a glance

Every app is open source (MIT or Apache-2.0) and lives at `github.com/storytold/<app>`. Its page is
`getartcraft.com/apps/<app>`, and its CLI is `<app>-cli`. All apps work the same way: native file
in, engine commands, files out. For exact syntax, load the app's own skill (`artcraft:<app>`).

| App | Like | Native file | Also reads | Writes | Notable |
|---|---|---|---|---|---|
| PhotoCraft | Photoshop | `.pcraft` | PSD (layers), PNG, JPEG, WebP, TIFF, EXR, GIF, BMP, TGA, DPX | same + layered TIFF | adjustment layers, type, actions/droplets, `batch` over folders, remove background |
| VectorCraft | Illustrator | `.vectorcraft` | SVG/SVGZ, PDF, AI, EPS, DXF, EMF/WMF, PSD, Affinity, raster | SVG, PDF (incl. PDF/X), AI, EPS, DXF, EMF/WMF, PSD, PNG/JPG/WebP/TIFF | artboards, Pathfinder, image trace, outline text, export for screens |
| FilmCraft | Premiere Pro | `.fcproj` (JSON) | video/audio/stills, SRT/VTT, FCPXML, FCP7 XML, AAF, OMF, EDL, OTIO | H.264, HEVC, ProRes, DNxHR, APV, MXF, PNG/TIFF seq, GIF, WAV/AIFF/AAC + interchange | Lumetri-style color, captions (burn-in or sidecar), mixer, presets incl. vertical 9:16 |
| EffectCraft | After Effects | `.ecproj` | footage, Lottie | H.264, HEVC, AV1, ProRes (alpha), WebM, GIF, PNG/JPEG/TIFF/EXR seq, Lottie | keyframes, 300+ effects, expressions, `.jsx` scripting (AE object model), `.ectemplate` templates |
| PdfCraft | Acrobat | PDF | PDF, images, .txt (via tools) | PDF, PNG/JPG/TIFF, DOCX, HTML, text | combine/extract/split, OCR (needs app models), redaction + `audit`, passwords, 170 tools |
| DeckCraft | PowerPoint / Keynote | `.deckcraft` | PPTX, POTX, PPSX | PPTX, PDF (handouts), PNG/JPG, GIF, outline | themes, starter templates, outline to slides, charts, tables, transitions |
| GridCraft | Excel | XLSX | XLSM, CSV, TSV, TXT; imports XLS, XLSB, ODS | XLSX, CSV, TSV, HTML, JSON (own), PDF (via `run`) | 500+ functions, tables, charts, pivots, conditional formats, `eval`, `check` |
| WordCraft | Word | DOCX | DOC (read), ODT, RTF, HTML, MD, TeX, TXT, Word XML | all of those but DOC, plus PDF, PNG | styles, TOC, tracked changes, comments, mail merge, templates. Cannot read PDF |
| LightCraft | Lightroom Classic | library folder | JPEG, PNG, TIFF, raw (CR3/NEF/ARW/RAF/DNG…), XMP, `.lrcat` | JPEG, PNG, TIFF, WebP, AVIF, JPEG XL, PSD, DNG | non-destructive develop, presets, batch export with naming/watermark, HDR/pano merge |
| DesignCraft | InDesign | `.designcraft` | IDML, INDD/INDT (converted) | PDF (bleed/marks), PNG/JPG, IDML, EPUB, HTML, PPTX, text, package | parent pages, styles, threaded text, data merge, preflight. All units in points |
| SoundCraft | Audition | `.scraft` session | WAV, AIFF, FLAC, AAC/M4A | WAV, AIFF, FLAC (no MP3) | clip gain, fades, plugin chains (EQ, comp, de-ess, reverb…), AudioSuite, stems bounce |
| CADCraft | AutoCAD | DXF / DWG | DXF, DWG | DXF, DWG, SVG, PNG, PDF | AutoCAD `.scr` scripts, layers, dimensions, hatches. Use `--metric` for mm |
| FigCraft | Figma | `.figcraft` | FigCraft JSON, Figma REST JSON, `.fig` (best effort), SVG, raster | PNG/JPG/WebP/SVG/PDF (bleed, CMYK), `.fig`, JSON | frames, components, auto layout, variables/modes, templates |

## Shared behaviour

- **No GUI needed.** All the CLIs run headless. The desktop apps are optional, installed with
  ArtCraft Launcher or from the releases. Use them only to watch an agent work, via each app's
  `--control` flag together with the CLI's `--bridge`/`--connect`/`app`.
- **Edits are lost without a save flag.** Most CLIs discard edits silently and still exit 0 when
  `--save`/`--out`/`--export` is missing. Always name an output.
- **Overwrites are silent.** Most outputs overwrite existing files without asking, so pick fresh names
  (see `safety.md`).
- **A failing step aborts the run.** Usually nothing is written and the exit code is 1. Exit code 2
  means a usage error.
- **Command ids are the API.** Search them with each CLI's own listing (`commands`, `tools`) and with
  `describe`. Every app skill keeps a generated `references/commands.md` for grepping.

## ArtCraft (the AI studio)

ArtCraft is a separate desktop and web app (getartcraft.com) for AI images and video. Its features
include 3D scene staging, character posing, camera blocking, image to 3D, and many hosted models
(Nano Banana, GPT Image, FLUX, Seedream, Seedance, Kling, Veo, Sora…). It runs on credits, or with
the user's own provider logins. It has no CLI, but it has an HTTP Omni API, which the `genai` skill
can use when the user has an ArtCraft API key.
