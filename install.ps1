# One-step setup on Windows: install or update every Crafting App CLI, then show how to add
# the Claude Code plugin. Pass app names to install only some: .\install.ps1 photocraft filmcraft
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'skills\artcraft\scripts\craft-clis.ps1') install @args
Write-Host @'

CLIs ready. To add the skills to Claude Code, run inside Claude Code:

  /plugin install artcraft --marketplace Codaria-co/artcraft

(older versions: /plugin marketplace add Codaria-co/artcraft  then  /plugin install artcraft@artcraft)
'@
