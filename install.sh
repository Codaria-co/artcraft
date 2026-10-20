#!/usr/bin/env bash
# One-step setup on macOS/Linux: install or update every Crafting App CLI, then show how to add
# the Claude Code plugin. Pass app names to install only some: ./install.sh photocraft filmcraft
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
"$here/skills/artcraft/scripts/craft-clis.sh" install "$@"
cat <<'MSG'

CLIs ready. To add the skills to Claude Code, run inside Claude Code:

  /plugin install artcraft --marketplace Codaria-co/artcraft

(older versions: /plugin marketplace add Codaria-co/artcraft  then  /plugin install artcraft@artcraft)
MSG
