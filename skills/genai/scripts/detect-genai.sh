#!/usr/bin/env bash
# Report which generative-AI options this machine has, as JSON on stdout (macOS, Linux).
#
#   detect-genai.sh            quick scan (~2 s): local servers, apps, CLIs, API-key names, ArtCraft
#
# It never prints secret values: for API keys it reports only the variable NAME when set.
# It only talks to 127.0.0.1 (short timeouts) to see which local servers are up.
set -uo pipefail

json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

items=()
add() { # kind name status detail
  items+=("{\"kind\":$(json_str "$1"),\"name\":$(json_str "$2"),\"status\":$(json_str "$3"),\"detail\":$(json_str "$4")}")
}

probe() { # url -> 0 when something answers with HTTP 2xx
  curl -fs -o /dev/null --max-time 1 --connect-timeout 0.5 "$1" 2>/dev/null
}

# --- local servers (free, private) ---------------------------------------------------------
probe http://127.0.0.1:8188/system_stats   && add local-server ComfyUI running "http://127.0.0.1:8188 (image/video/audio via workflows)"
probe http://127.0.0.1:11434/api/tags      && add local-server Ollama running "http://127.0.0.1:11434 (text/vision LLMs)"
probe http://127.0.0.1:1234/v1/models      && add local-server "LM Studio" running "http://127.0.0.1:1234 (OpenAI-compatible LLM server)"
probe http://127.0.0.1:7860/sdapi/v1/sd-models && add local-server "A1111/Forge/Draw Things API" running "http://127.0.0.1:7860 (SD WebUI API: /sdapi/v1/txt2img)"
probe http://127.0.0.1:9090/api/v1/app/version && add local-server InvokeAI running "http://127.0.0.1:9090"

# --- local apps / CLIs installed but maybe not running ---------------------------------------
app_dirs=("/Applications" "$HOME/Applications")
for app in "Draw Things" "DiffusionBee" "ComfyUI" "LM Studio" "Ollama" "InvokeAI" "Pinokio" "Krita"; do
  for d in "${app_dirs[@]}"; do
    [[ -d "$d/$app.app" ]] && { add local-app "$app" installed "$d/$app.app"; break; }
  done
done
for c in ollama comfy mflux-generate sd sd-cli llama-cli whisper whisper-cli piper espeak-ng ffmpeg; do
  p=$(command -v "$c" 2>/dev/null) && add local-cli "$c" installed "$p"
done
[[ "$(uname -s)" == Darwin ]] && command -v say >/dev/null && add local-cli say installed "macOS text-to-speech (free, offline)"

# --- hosted-service CLIs ---------------------------------------------------------------------
for c in higgsfield fal replicate openai gemini llm aider; do
  p=$(command -v "$c" 2>/dev/null) && add service-cli "$c" installed "$p"
done

# --- API keys (names only) --------------------------------------------------------------------
for v in ARTCRAFT_API_KEY OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY FAL_KEY FAL_API_KEY \
         REPLICATE_API_TOKEN STABILITY_API_KEY BFL_API_KEY TOGETHER_API_KEY HF_TOKEN \
         HUGGINGFACE_API_KEY ELEVENLABS_API_KEY RUNWAYML_API_SECRET LUMAAI_API_KEY XAI_API_KEY \
         MINIMAX_API_KEY IDEOGRAM_API_KEY RECRAFT_API_TOKEN; do
  [[ -n "${!v:-}" ]] && add api-key "$v" set "value hidden"
done

# --- ArtCraft studio -------------------------------------------------------------------------
for d in "${app_dirs[@]}"; do
  [[ -d "$d/ArtCraft.app" ]] && add artcraft-studio ArtCraft installed "$d/ArtCraft.app"
done
[[ -e "$HOME/Library/Caches/ai.artcraft.app/.cookies" ]] && add artcraft-studio "ArtCraft session" present "desktop app has signed in at least once"

printf '{"os":%s,"arch":%s,"options":[' "$(json_str "$(uname -s)")" "$(json_str "$(uname -m)")"
( IFS=,; printf '%s' "${items[*]:-}" )
printf ']}\n'
