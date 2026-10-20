# Providers: how to call each option

Contents: 1. Local runners · 2. MCP tools and service CLIs · 3. Hosted APIs by key ·
4. ArtCraft studio (Omni API) · 5. If nothing is available

APIs and model ids change often. Treat the snippets as the shape of the call. Confirm the current
model id or flag with the tool's own `--help`, `/models` listing or docs before spending money.

## 1. Local runners (free, private)

**ComfyUI** (`127.0.0.1:8188`). It runs node-graph workflows for image, video and audio.
1. Export the workflow in **API format** (dev mode, "Save (API Format)").
2. Edit the prompt and size fields in the JSON.
3. Queue the job: `POST /prompt {"prompt": <workflow>}`, which returns `prompt_id`.
4. Poll `GET /history/<prompt_id>` until outputs appear.
5. Download each output with `GET /view?filename=<f>&subfolder=<s>&type=output`.

Which models are installed decides what's possible. Read them from `GET /object_info`, or check
`models/` in the ComfyUI folder.

**A1111 / Forge / Draw Things API server** (`127.0.0.1:7860`, SD WebUI API).
```bash
curl -s http://127.0.0.1:7860/sdapi/v1/txt2img -H 'Content-Type: application/json' \
  -d "$(jq -n --arg p "$PROMPT" '{prompt:$p, steps:25, width:1024, height:1024}')" \
  | jq -r '.images[0]' | base64 -d > out.png
```
`/sdapi/v1/img2img` takes `init_images` (base64) for variations. In Draw Things, turn on the HTTP
API server in its settings first.

**mflux** (Apple Silicon, FLUX on MLX). Example: `mflux-generate --model schnell --prompt "$PROMPT"
--steps 4 --seed 1 --output out.png`. Check `mflux-generate --help` for the flags of the installed
version. The first run downloads the model weights, which are several GB, so warn the user.

**Ollama** (`127.0.0.1:11434`) and **LM Studio** (`127.0.0.1:1234`, OpenAI-compatible) run local
LLMs. Use them for text: prompts, captions, scripts, alt text, slide copy. Ollama's API is
`POST /api/generate {"model","prompt","stream":false}`; list models with `GET /api/tags`.

**Voice and audio, offline:**
- **macOS:** `say -v '?'` lists the voices. Write the file with `say -v Samantha -o vo.aiff "text"`,
  then convert with `soundcraft-cli convert vo.aiff vo.wav`.
- **Linux/Windows/macOS:** use `piper`:
  `echo "text" | piper --model <voice>.onnx --output_file vo.wav`.
- **Windows:** use `System.Speech.Synthesis.SpeechSynthesizer`:
  `SetOutputToWaveFile('vo.wav')`, then `Speak('text')`.

## 2. MCP tools and service CLIs the user already has

If your tool list includes generative MCP tools (image/video/audio/3D), use them. They carry the
user's own account and model catalog. Follow the server's own instructions:
- If the server has a cost or quote tool, call it before generating and show the quote.
- Wait for jobs with the server's wait/poll tool. Don't busy-loop.
- Download the result into the project folder, so the Craft CLIs can read it.

For service CLIs found by the detector (`fal`, `replicate`, `openai`, `gemini`, `llm`, `higgsfield`,
and others), read `<cli> --help` and use the CLI's own quote or dry-run mode if it has one.

## 3. Hosted APIs by key (pay per use)

Send the key on stdin, so it never appears in the process list: `printf 'Authorization: Bearer %s' "$KEY" | curl -H @- ...`.

| Key variable | Service | Call shape |
|---|---|---|
| `OPENAI_API_KEY` | OpenAI Images | `POST https://api.openai.com/v1/images/generations` `{model, prompt, size}`, returns `data[0].b64_json` |
| `GEMINI_API_KEY` / `GOOGLE_API_KEY` | Google AI Studio (Gemini image models) | `POST https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`, header `x-goog-api-key` |
| `FAL_KEY` | fal.ai (many image/video/audio models) | `POST https://fal.run/<model-id>`, header `Authorization: Key <key>`. Use `queue.fal.run` for long jobs |
| `REPLICATE_API_TOKEN` | Replicate | `POST https://api.replicate.com/v1/models/<owner>/<name>/predictions`, header `Prefer: wait` |
| `STABILITY_API_KEY`, `BFL_API_KEY`, `IDEOGRAM_API_KEY`, `RECRAFT_API_TOKEN` | image vendors | see the vendor docs |
| `ELEVENLABS_API_KEY` | voice/TTS | see the vendor docs |
| `RUNWAYML_API_SECRET`, `LUMAAI_API_KEY`, `MINIMAX_API_KEY` | video vendors | see the vendor docs |
| `HF_TOKEN` | Hugging Face Inference | provider-routed models. Free accounts get a small monthly credit |

Give a cost quote for every option in this table before calling it.

## 4. ArtCraft studio: Omni API

ArtCraft (getartcraft.com, by Storyteller) is a hosted AI studio paid with credits. Its desktop app has
no CLI. Its HTTP API is documented in the repo (`storytold/artcraft`, `_docs/artcraft_omni_api.md`):

- **Base URL:** `https://api.storyteller.ai`.
- **Auth:** `Authorization: Bearer artcraft_api_<40 chars>`. Create the key at app.getartcraft.com,
  under Account, Settings, API Keys. API access is enabled per account, and the key is shown only once.
  Keep it in `ARTCRAFT_API_KEY`.
- **Generate video:** `POST /v1/omni_api/generate/video`.
  - Required: `model` (e.g. `seedance_2p0`) and `idempotency_token` (a fresh UUID per job).
  - Optional: `prompt`, `negative_prompt`, `duration_seconds`, `aspect_ratio` (e.g.
    `wide_sixteen_by_nine`, `square`), `resolution` (e.g. `ten_eighty_p`) and `generate_audio`.
  - References, as URLs: `start_frame_image_url`, `end_frame_image_url`, `reference_image_urls`,
    `reference_video_urls` (mp4) and `reference_audio_urls`.
- **Generate image:** `POST /v1/omni_api/generate/image` (accepts `image_urls` for references).
- **Poll:** `GET /v1/omni_api/job_status/job/<token>`. Keep polling while the status is `pending`,
  `started` or `attempt_failed`. On success, download `state.maybe_result.media_links.cdn_url`.
- **Errors:**
  - 400: bad file type.
  - 401: bad or banned key.
  - 402: out of credits. Tell the user and stop; don't retry.
- **Unconfirmed:** the full list of model ids beyond `seedance_2p0`. Ask the API or the docs, and quote
  credits before generating.

Pricing as published on getartcraft.com/pricing (Oct 2026; re-check):

| Plan | Price | Credits |
|---|---|---|
| Basic | $10/mo | 1,000 |
| Pro | $35/mo | 3,750 |
| Max | $60/mo | 6,600 |

1,000 credits buys roughly 250 Nano Banana images or about 63 s of Seedance 2.0. Credits are refunded
when a generation fails.

## 5. If nothing is available

Recommend options in this order, matched to the user's OS and hardware. Ask the user before
installing anything.

**Free, local:**
- **Image:**
  - Draw Things (macOS/iOS, App Store, free; Apple Silicon).
  - DiffusionBee (macOS, free).
  - mflux (Apple Silicon, `pip install mflux`).
  - ComfyUI (Windows/Linux/macOS; NVIDIA GPU or Apple Silicon recommended, 8+ GB VRAM/unified memory
    for SDXL/FLUX-class models). ComfyUI also runs local video and audio models on strong GPUs.
- **Voice:** `say` (macOS, built in), Windows System.Speech (built in), Piper (all OSes, small
  neural voices).
- **Text:** Ollama or LM Studio, with a small model on modest hardware.

**Free tiers or very low cost, hosted:**
- Google AI Studio: a Gemini API key with a rate-limited free tier, including image models.
- Hugging Face Inference: a small free monthly credit.
- fal.ai and Replicate: pay per use, typically a few cents per image. Video costs much more per second.
- ArtCraft Basic: $10/mo for 1,000 credits, with many image and video models in one account, plus the
  3D staging studio.

State plainly which option fits their hardware and budget. Note that prices and free tiers change,
so the user should confirm them on the provider's page.
