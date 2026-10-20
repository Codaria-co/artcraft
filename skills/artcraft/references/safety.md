# Safe defaults for every Craft CLI

These CLIs act with the user's full file permissions and can overwrite documents in place. The
rules below keep work reversible and keep an agent from reaching outside the project.

## Files

- **Write to a new file.** Use `--out`, `--export`, `--save-as`, `-o` or a new output dir. Only use
  `--save`, `--in-place` or an output equal to the input when the user explicitly asks to modify the
  original. Several CLIs already refuse to clobber (e.g. `photocraft-cli batch` refuses `--out` equal
  to `--in`); don't work around those guards.
- **Before overwriting anything, look at it.** If a target file exists and isn't something you just
  produced, pick a new name (`name-edited.png`, `name-v2.psd`) instead of replacing it.
- **Quote every path** (`"$in"`), and pass user-supplied text as data (JSON params, script files),
  never spliced into shell code unquoted. Build JSON with a tool (`jq -n --arg`, `python -c json.dumps`)
  when text contains quotes or newlines.
- **Keep scratch work in a temp dir** (`mktemp -d`) and move only finished outputs to where the user
  wants them.

## Live apps and servers

- `--control PORT`/`--bridge`/`--connect` channels listen on 127.0.0.1. Never bind them to another
  interface, and never forward or expose those ports. Some apps protect the channel with a token
  (`--control-token-file`); keep the token file private (mode 600) and out of version control.
- If the user wants an MCP server, confine it to the project:
  `<app>-cli mcp --automation-read-root "$PWD" --automation-write-root "$PWD/out"`. A root left out
  grants none of its access. A running app is confined only by the flags it was started with.

## Scripts and automation

- Some CLIs run user-supplied scripts (`effectcraft-cli script file.jsx`, `cadcraft-cli --script-file`,
  `filmcraft-cli run script.jsonl`). Only run scripts you wrote or the user gave you and you have read.
- Exit codes matter: most CLIs exit non-zero when any command fails. Check them; don't report success
  from a run whose output says `"ok": false`.

## Downloads

- Install CLIs only through `scripts/craft-clis.sh` / `craft-clis.ps1`, which verify SHA-256 against
  the release and notarization on macOS. Don't run binaries from unverified sources.
