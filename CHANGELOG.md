# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-20

### Added
- `artcraft` router skill: covers the whole suite, choosing an app, safety defaults and cross-app pipeline recipes.
- One skill per Crafting App: photocraft, vectorcraft, filmcraft, effectcraft, pdfcraft, deckcraft,
  gridcraft, wordcraft, lightcraft, designcraft, soundcraft, cadcraft and figcraft. Each has tested recipes
  and a generated command catalog.
- `genai` skill: a generative-AI broker. It finds local runners, MCP tools, CLIs, API keys and the ArtCraft
  Omni API, and asks for confirmation before any paid generation.
- `craft-clis.sh` / `craft-clis.ps1`: install, update and check all 13 CLIs, with SHA-256 checks and
  macOS notarization checks.
- `install.sh` / `install.ps1`, plus a plugin manifest and a marketplace manifest.
- Task eval sets (31 tasks) and skill-triggering eval sets (300 queries).
- `docs/upstream-cli-issues.md`: CLI issues found during development.
