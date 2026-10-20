<#
Report which generative-AI options this Windows machine has, as JSON on stdout.
Never prints secret values: for API keys it reports only the variable NAME when set.
Only talks to 127.0.0.1 (short timeouts) to see which local servers are up.
#>
$ErrorActionPreference = 'SilentlyContinue'
$items = New-Object System.Collections.Generic.List[object]
function Add-Item($kind, $name, $status, $detail) { $items.Add([ordered]@{ kind = $kind; name = $name; status = $status; detail = $detail }) }

function Test-Url([string]$Url) {
  try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 -Uri $Url; return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) } catch { return $false }
}

if (Test-Url 'http://127.0.0.1:8188/system_stats') { Add-Item 'local-server' 'ComfyUI' 'running' 'http://127.0.0.1:8188 (image/video/audio via workflows)' }
if (Test-Url 'http://127.0.0.1:11434/api/tags') { Add-Item 'local-server' 'Ollama' 'running' 'http://127.0.0.1:11434 (text/vision LLMs)' }
if (Test-Url 'http://127.0.0.1:1234/v1/models') { Add-Item 'local-server' 'LM Studio' 'running' 'http://127.0.0.1:1234 (OpenAI-compatible LLM server)' }
if (Test-Url 'http://127.0.0.1:7860/sdapi/v1/sd-models') { Add-Item 'local-server' 'A1111/Forge API' 'running' 'http://127.0.0.1:7860 (SD WebUI API: /sdapi/v1/txt2img)' }
if (Test-Url 'http://127.0.0.1:9090/api/v1/app/version') { Add-Item 'local-server' 'InvokeAI' 'running' 'http://127.0.0.1:9090' }

foreach ($c in 'ollama', 'comfy', 'sd', 'llama-cli', 'whisper', 'piper', 'espeak-ng', 'ffmpeg') {
  $p = (Get-Command $c -ErrorAction SilentlyContinue).Source
  if ($p) { Add-Item 'local-cli' $c 'installed' $p }
}
foreach ($c in 'higgsfield', 'fal', 'replicate', 'openai', 'gemini', 'llm') {
  $p = (Get-Command $c -ErrorAction SilentlyContinue).Source
  if ($p) { Add-Item 'service-cli' $c 'installed' $p }
}
foreach ($v in 'ARTCRAFT_API_KEY', 'OPENAI_API_KEY', 'GEMINI_API_KEY', 'GOOGLE_API_KEY', 'FAL_KEY', 'FAL_API_KEY',
  'REPLICATE_API_TOKEN', 'STABILITY_API_KEY', 'BFL_API_KEY', 'TOGETHER_API_KEY', 'HF_TOKEN', 'HUGGINGFACE_API_KEY',
  'ELEVENLABS_API_KEY', 'RUNWAYML_API_SECRET', 'LUMAAI_API_KEY', 'XAI_API_KEY', 'MINIMAX_API_KEY', 'IDEOGRAM_API_KEY', 'RECRAFT_API_TOKEN') {
  if ([Environment]::GetEnvironmentVariable($v)) { Add-Item 'api-key' $v 'set' 'value hidden' }
}
$roots = @("$env:LOCALAPPDATA\Programs", $env:ProgramFiles)
foreach ($app in 'ArtCraft', 'Draw Things', 'DiffusionBee', 'ComfyUI', 'LM Studio', 'Ollama', 'InvokeAI', 'Pinokio', 'Krita') {
  foreach ($r in $roots) {
    if ($r -and (Test-Path -LiteralPath (Join-Path $r $app))) {
      $kind = if ($app -eq 'ArtCraft') { 'artcraft-studio' } else { 'local-app' }
      Add-Item $kind $app 'installed' (Join-Path $r $app); break
    }
  }
}
Add-Item 'local-cli' 'System.Speech' 'available' 'Windows text-to-speech via PowerShell (free, offline)'

[ordered]@{ os = 'Windows'; arch = $env:PROCESSOR_ARCHITECTURE; options = $items } | ConvertTo-Json -Depth 4 -Compress
