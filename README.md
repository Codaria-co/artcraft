# artcraft

A Claude Code plugin for the [ArtCraft](https://getartcraft.com) **Crafting Apps**: free, open-source desktop apps that mirror Adobe, Office, Figma and AutoCAD, each with a headless command-line tool. These skills let Claude drive those apps from the shell, install and update their CLIs, chain several apps in one pipeline, and generate new media with whatever AI tools the machine already has.

## Install

Inside Claude Code:

```
/plugin install artcraft --marketplace Codaria-co/artcraft
```

On older Claude Code versions, add the marketplace first and then install:

```
/plugin marketplace add Codaria-co/artcraft
/plugin install artcraft@artcraft
```

Next, install the Crafting App CLIs. Either clone this repo and run its installer, or ask Claude to "install the ArtCraft CLIs":

```bash
git clone https://github.com/Codaria-co/artcraft.git && cd artcraft
./install.sh                     # macOS / Linux  -> ~/.local/bin
./install.sh photocraft filmcraft   # only some apps
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1   # Windows -> %LOCALAPPDATA%\Programs\artcraft\bin
```

The installer gets the latest release of each `<app>-cli` from `github.com/storytold/<app>`. Before installing, it checks each download against the release's `SHA256SUMS.txt`, and on macOS it also checks Gatekeeper notarization. It never replaces a CLI with an older version. To see what is installed and what is outdated, run `skills/artcraft/scripts/craft-clis.sh check`.

The desktop apps are optional, because every skill works headless. If you want them, install them with ArtCraft Launcher.

## Skills

| Skill | App | Like |
|---|---|---|
| `artcraft` | the suite: install/update CLIs, choosing an app, multi-app pipelines | — |
| `photocraft` | PhotoCraft | Photoshop |
| `vectorcraft` | VectorCraft | Illustrator |
| `filmcraft` | FilmCraft | Premiere Pro |
| `effectcraft` | EffectCraft | After Effects |
| `pdfcraft` | PdfCraft | Acrobat |
| `deckcraft` | DeckCraft | PowerPoint / Keynote |
| `gridcraft` | GridCraft | Excel |
| `wordcraft` | WordCraft | Word |
| `lightcraft` | LightCraft | Lightroom Classic |
| `designcraft` | DesignCraft | InDesign |
| `soundcraft` | SoundCraft | Audition |
| `cadcraft` | CADCraft | AutoCAD |
| `figcraft` | FigCraft | Figma |
| `genai` | broker for generative AI (local runners, your MCP tools/CLIs, API keys, ArtCraft Omni API) | — |

Each app skill includes tested workflows, the gotchas found while testing, task recipes (`references/recipes.md`) and a full generated command catalog (`references/commands.md`).

## Safety

- Results go to new files. Inputs are never overwritten unless you ask.
- Control channels stay on loopback, and any MCP server runs confined with `--automation-read-root` and `--automation-write-root`.
- `genai` runs free local options first. Before any paid generation it shows a cost quote and waits for your confirmation. API keys are reported by variable name only.

## Notes

- **Overlapping generic skills.** If you also have generic document skills installed (for example `xlsx`, `docx`, `pptx`, `pdf`), Claude may pick one of those for spreadsheet or Word tasks. To use the Crafting Apps instead, name the app ("with GridCraft…") or disable the overlapping skills.
- **Windows.** Use PowerShell 7 (`pwsh`). Windows PowerShell 5.1 strips the quotes inside JSON arguments.
- **Known CLI issues.** Issues found while building this plugin are listed in [`docs/upstream-cli-issues.md`](docs/upstream-cli-issues.md).

## Maintaining

```bash
skills/artcraft/scripts/craft-clis.sh update   # newest CLIs
tools/gen-catalog.sh                           # regenerate every references/commands.md
```

The eval sets are in `evals/`: task evals in `batch-*.json` and skill-triggering evals in `triggers/`.

## License

MIT. ArtCraft and the Crafting Apps are separate projects by their authors, licensed under MIT/Apache-2.0.
