---
name: genai
description: Broker for generative AI inside the ArtCraft workflow — finds what can generate images, video, audio/voice, 3D or text on THIS machine (local runners like ComfyUI, Ollama, Draw Things, A1111/Forge, LM Studio, macOS `say`; generative MCP tools and CLIs the user already has; API keys in the environment; the ArtCraft studio Omni API), picks the cheapest fitting option, quotes the cost and asks before spending, generates, and hands the file to the right Craft app. When nothing is available it recommends free or low-cost options. Use it whenever the user wants to create, generate, imagine, render-from-a-prompt, synthesize a voice, make AI art/video/music/3D, or asks "what AI can I use", "generate a background/texture/logo idea/voiceover for my PhotoCraft/FilmCraft/EffectCraft/DeckCraft project" — even if they don't say "AI".
---

# Generative AI broker

The Crafting Apps edit; they don't generate. This skill fills that gap with whatever the user
already has, so the plugin works on any machine without depending on one vendor. Your job is
to be a fair broker: use what's free and local first, reuse what the user already pays for, and
never spend their money without a clear quote and a yes.

## 1. Pin down the request

Know these before choosing a tool (ask only for what you can't infer):
- **Medium**: image, video, audio (voice / music / SFX), 3D mesh, text.
- **Specs**: size or aspect (e.g. 1080x1920 for a vertical video), duration, style, count.
- **Destination**: which Craft app gets the result next, so you pick a format it reads
  (PNG for PhotoCraft/DesignCraft/DeckCraft, SVG via VectorCraft trace for vector, MP4/MOV for
  FilmCraft/EffectCraft, WAV for SoundCraft/FilmCraft).

## 2. Take inventory

Do both:
1. **Your own tools.** Look at the tools available to you in this session for generative MCP tools
   (names like `generate_image`, `generate_video`, `text_to_speech`, `upscale`, from any server).
   Those are the user's configured accounts and usually the most capable option.
2. **The machine.** Run `scripts/detect-genai.sh` (Windows: `scripts/detect-genai.ps1`). It returns
   JSON listing running local servers, installed local apps/CLIs, hosted-service CLIs, the *names*
   of API-key variables that are set, and ArtCraft studio presence. It never prints key values.

## 3. Rank and choose

Prefer, in order, the first option that can actually meet the specs:
1. **Running local server or CLI** — free and private (ComfyUI, A1111/Forge/Draw Things API,
   Ollama, mflux, `say`, piper). Mention speed/quality limits honestly.
2. **Installed but stopped local app** — offer to start it (the user may need to open it).
3. **A generative MCP tool or service CLI the user already set up** — uses their existing plan.
4. **An API key in the environment** — pay per use.
5. **ArtCraft studio Omni API** (`ARTCRAFT_API_KEY`) — ArtCraft credits; many hosted models.
6. **Nothing fits** — recommend options from `references/providers.md` ("If nothing is available"),
   cheapest first, and stop there. Don't install software or create accounts without the user's OK.

If two options tie, prefer the one whose output needs the least conversion for the destination app.
Read `references/providers.md` for how to call each option.

## 4. Quote, then confirm

- **Free/local**: say it's free and roughly how long it may take; go ahead.
- **Anything paid**: before the call, show provider, model, settings, count and the cost — from the
  tool's own quote/estimate endpoint when it has one, otherwise from the provider's published price
  with the date you know it from. Ask for a yes. A batch or a video gets one quote for the total.
- If the user has set a budget, stay within it; if a retry would cost money, ask again.

## 5. Generate safely

- Keep prompts and outputs in the project: save to a clear name (`hero-bg-1920x1080.png`), never over
  an existing file.
- Pass API keys only through environment variables or `curl -H @-` from stdin, so they don't land in
  shell history, logs or process listings. Never echo, store or commit a key.
- Treat generated content like any download: check it is the format and size you asked for
  (`photocraft-cli info`, `filmcraft-cli probe`, `soundcraft-cli info`) before handing it on.
- Respect content rules of the provider; don't try to evade a refusal by switching providers.

## 6. Hand off

Tell the user where the file is and continue in the right Craft skill, e.g. retouch and resize in
`artcraft:photocraft`, place on a timeline in `artcraft:filmcraft`, animate in `artcraft:effectcraft`,
vectorize/trace in `artcraft:vectorcraft`, clean a voiceover in `artcraft:soundcraft`.

## References
- `references/providers.md` — how to call each local runner, CLI/MCP pattern and API (ArtCraft Omni
  API included), plus the free/low-cost fallback list. Read it once you know which option you'll use.
