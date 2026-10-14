# Image generation and editing APIs for HOOKKADR: state as of 14 October 2026

All sources were accessed 2026-10-14. Where a page shows its own "last updated" or publication date, it is given in brackets. "Secondary" marks a non-official source such as a blog, aggregator or press coverage. HOOKKADR code that hard-codes image models: `lib/features/ai/ai_clients.dart:307` (`imageModel = 'gpt-image-1'`, POST `/v1/images/generations`), `lib/features/ai/ai_clients.dart:437` (`imageModel = 'gemini-2.5-flash-image'`, POST `v1beta/models/...:generateContent` with `generationConfig.imageConfig.aspectRatio`), and `lib/features/director/capability_registry.dart:80` (note `'gpt-image-1'`).

## Are `gpt-image-1` and `gemini-2.5-flash-image` still current?

### Takeaway
Both are outdated. `gpt-image-1` will be **shut down on 23 October 2026**, nine days after these notes were written. OpenAI's replacements are `gpt-image-2.5-flare` (fast default) and `gpt-image-2.5-sunburst` (most precise editing). `gemini-2.5-flash-image` is deprecated with earliest retirement on 15 March 2027 (moved from 2 October 2026). Google names `gemini-3.1-flash-lite-image` as its direct replacement and recommends `gemini-nano-banana-2.1` for new projects.

### Cited Findings
- OpenAI deprecations table: `gpt-image-1` deprecation announced April 22, 2026, shutdown **Oct 23, 2026**, replacement `gpt-image-2.5-sunburst` or `gpt-image-2.5-flare` — [OpenAI Deprecations](https://developers.openai.com/api/docs/deprecations)
- OpenAI: `gpt-image-1-mini`, `gpt-image-1.5` and `chatgpt-image-latest` deprecation announced June 2, 2026, removal from API **Dec 1, 2026**, same 2.5 replacements — [OpenAI Deprecations](https://developers.openai.com/api/docs/deprecations)
- OpenAI: `dall-e-2` and `dall-e-3` deprecation announced Nov 14, 2025, shutdown May 12, 2026 (already gone) — [OpenAI Deprecations](https://developers.openai.com/api/docs/deprecations)
- `gpt-image-2` (snapshot `gpt-image-2-2026-04-21`) has no deprecation entry and is listed as an "earlier model". The guide says "For new integrations, use one of the GPT Image 2.5 models" — [OpenAI image generation guide](https://developers.openai.com/api/docs/guides/image-generation); [gpt-image-2 model page](https://developers.openai.com/api/docs/models/gpt-image-2)
- The OpenAI models page lists only two image models under "Specialized models > Image": GPT-Image-2.5 Sunburst ("Our most capable model for image generation and editing") and GPT-Image-2.5 Flare ("Fast, high-quality everyday image generation") — [OpenAI Models](https://developers.openai.com/api/docs/models)
- Snapshot IDs `gpt-image-2.5-sunburst-2026-09-08` and `gpt-image-2.5-flare-2026-09-08` — [Sunburst page](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst); [Flare page](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare)
- Timeline (secondary): gpt-image-2 launched in the API on April 21, 2026 and in ChatGPT as "ChatGPT Images 2.0" on April 22. GPT Image 2.5 (Flare/Sunburst) followed on Sept 8, 2026 — [Wikipedia: GPT Image](https://en.wikipedia.org/wiki/GPT_Image); [fal GPT Image 2.5 page, updated Sept 10, 2026](https://fal.ai/gpt-image-2.5)
- Gemini API deprecations table, "Nano Banana models": `gemini-2.5-flash-image` released October 2, 2025, shutdown **March 15, 2027**, replacement `gemini-3.1-flash-lite-image`. Dates are "the earliest possible dates on which a model might be retired" [page last updated 2026-10-12] — [Gemini API Deprecations](https://ai.google.dev/gemini-api/docs/deprecations)
- **Conflict:** the Gemini API pricing page still says "Gemini 2.5 Flash Image (gemini-2.5-flash-image) is deprecated and will be shut down on October 2, 2026" — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing). The Agent Platform (formerly Vertex AI) release note of Sept 14, 2026 settles this: it deprecated `gemini-2.5-flash-image` and **moved retirement from October 2, 2026 to March 15, 2027**, with migration to `gemini-3.1-flash-lite-image` (whose own retirement is "June 28, 2027 or later"). The pricing page is therefore stale — [Gemini Enterprise Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes)
- On the Gemini image generation page, Nano Banana 2 is marked "Recommended for all new projects to use Nano Banana 2.1", and migration from the legacy model is to Nano Banana 2 Lite — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Other dead Google IDs: `gemini-2.5-flash-image-preview` (shutdown Jan 15, 2026), `gemini-2.0-flash-preview-image-generation` (Nov 14, 2025), `gemini-3-pro-image-preview` and `gemini-3.1-flash-image-preview` (June 25, 2026 on the Gemini API; Agent Platform retired them July 17, 2026) — [Gemini API Deprecations](https://ai.google.dev/gemini-api/docs/deprecations); [Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes)

### Inferences
- **Urgent:** after 23 Oct 2026, HOOKKADR's OpenAI image path (`ai_clients.dart:307`) will fail. The same endpoint `POST /v1/images/generations` accepts the 2.5 models, and the app's sizes `1024x1536`/`1536x1024`/`1024x1024` are still the recommended sizes, so a one-line model swap to `gpt-image-2.5-flare` should be the minimum fix. Whether the response still carries `data[0].b64_json` exactly as today was not verified, so a smoke test is needed. The Flutter app's `verify()` and the capability-registry note (`capability_registry.dart:80`) also need updating.
- The Gemini path keeps working until at least 15 Mar 2027, but it runs on a deprecated model and on `generateContent`, which Google now positions as legacy (see the Google section). Plan a migration to `gemini-nano-banana-2.1` (quality/price default) or `gemini-3.1-flash-lite-image` (cheapest, 1K only).
- A model ID should not be a hard-coded Dart constant in the client. These IDs changed three times in 18 months (dall-e → gpt-image-1 → gpt-image-2 → gpt-image-2.5-*; gemini-2.0 preview → 2.5 → 3.x → nano-banana-2.1). Put the ID in server config (`server/`) behind an adapter, which also matches the CLAUDE.md rule that AI keys live only on the server.

### Gaps
- No OpenAI announcement page was fetched directly for GPT Image 2.5; launch-day claims (for example "up to 50% lower latency" for Flare) come only from secondary sources.
- Whether OpenAI will set a shutdown date for `gpt-image-2` is unknown; it has no deprecation entry.

## OpenAI image API (endpoints, editing, references, fidelity, sizes, formats, verification, pricing, limits)

### Takeaway
Use the Images API (`/v1/images/generations` and `/v1/images/edits`) with `gpt-image-2.5-flare` for speed or `gpt-image-2.5-sunburst` for editing precision. The Responses API `image_generation` tool adds multi-turn editing and cached-input pricing. Masks are supported but are "prompt-based" and not pixel-exact. Token prices: $8/M image input, $30/M image output, $5/M text input. Batch costs half.

### Cited Findings
**Models and endpoints**
- 2.5 models support `v1/images/generations`, `v1/images/edits` and `v1/batch`. Input is text and image, output is image. Listed feature: "inpainting" — [Sunburst](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst); [Flare](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare)
- Responses API: pick a mainline model at the top level and set the image model in the `image_generation` tool's `model` field. "`gpt-5` and newer models should support the image generation tool." The model pages mark `v1/responses` as "Not supported" for the image model itself; it is usable only as a tool model — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation); [Sunburst page](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst)
- Positioning: Sunburst "for workflows where editing precision matters most"; Flare "for fast, high-quality everyday generation" — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Secondary: Sunburst is "better at preserving earlier edits and reference subjects across turns" and slower than Flare — [fal GPT Image 2.5](https://fal.ai/gpt-image-2.5); [grida.co summary](https://grida.co/docs/models/gpt-image-2.5)

**Editing, masks, references**
- Input images can be a URL, a Base64 data URL or a File ID (Responses). The guide's reference-image example uses 4 input images, and no maximum is stated — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Masks: Images API `mask`, Responses tool `input_image_mask`. Masking is prompt-based, and the model "may not follow its exact shape with complete precision". With several input images, the mask applies to the first one. Image and mask must share format and size and be under 50MB, and the mask needs an alpha channel — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Responses tool `action`: `"auto"`, `"generate"` or `"edit"`. Forcing `"edit"` with no image in context is an error. Multi-turn works via `previous_response_id` or an image generation call ID — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- `input_fidelity`: "For `gpt-image-2`, omit this parameter; the API doesn't allow changing it because the model processes every image input at high fidelity automatically", so edits with references use more input tokens. The guide does not say how 2.5 handles this — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)

**Sizes, quality, background, formats**
- Recommended sizes: `1024x1024`, `1536x1024`, `1024x1536`. Custom `WIDTHxHEIGHT` is allowed if both edges are multiples of 16, the aspect ratio is between 1:3 and 3:1, no edge exceeds 3840px, and total pixels are between 655,360 and 8,294,400. Sizes above `2560x1440` are "experimental" — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Quality: `low`, `medium`, `high`, `xhigh`, `max`, `auto`. `xhigh` and `max` are new in 2.5 (earlier models top out at `high`), and 2.5 defaults to `auto` — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Transparent background: `background: "transparent"` with `output_format` `png` or `webp`. The guide states this only for the 2.5 models. `background` options are transparent, opaque and auto — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Output formats: `png` (default), `jpeg`, `webp`. `output_compression` takes 0–100 (jpeg/webp only), and jpeg is faster than png — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Streaming: `partial_images` 0–3 in both the Images and Responses APIs. Each partial image adds 100 image output tokens — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- `revised_prompt` is returned when the mainline model rewrites the prompt (Responses). `n` sets the image count (default 1) — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)

**Verification, moderation, limits**
- Organization verification: "you may need to complete" it in the developer console before using GPT Image models — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- `moderation`: `auto` (default) or `low`. Blocked requests return `error.code` `"moderation_blocked"` with `moderation_details` (`moderation_stage`: `input`/`output`/`unknown`, coarse `categories`); `error.type` may be `"image_generation_user_error"` — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Documented limitations: latency "up to about 2 minutes" for complex prompts, weaker text rendering, imperfect character/brand consistency, limited precision in layout-sensitive compositions — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Default rate limits for `gpt-image-2`, `gpt-image-2.5-sunburst` and `gpt-image-2.5-flare`: Build tier 250,000 TPM / 20 IPM; Launch 3,000,000 TPM / 150 IPM; Grow 8,000,000 TPM / 250 IPM — [Sunburst](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst); [Flare](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare); [gpt-image-2](https://developers.openai.com/api/docs/models/gpt-image-2)
- The OpenAI API supported-countries list includes Uzbekistan, Kazakhstan, Kyrgyzstan, Tajikistan and Turkmenistan. Access from unlisted countries "may result in your account being blocked or suspended" (no date on page) — [OpenAI supported countries](https://developers.openai.com/api/docs/supported-countries)

**Pricing (per 1M tokens, Standard / Batch)**
- `gpt-image-2.5-sunburst`, `gpt-image-2.5-flare`, `gpt-image-2`: image input $8 / $4, cached image input $2 / $1, image output $30 / $15, text input $5 / $2.50, text output not billed — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)
- `gpt-image-1.5` and `chatgpt-image-latest`: image in $8, image out $32, text out $10. `gpt-image-1-mini`: image in $2.50, image out $8. `gpt-image-1`: image in $10, image out $40 — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)
- Cached-input rates for GPT Image 2/2.5 "only apply to images generated with the Responses API" — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)
- Per-image at 1024×1024 for `gpt-image-2`: low $0.006, medium $0.053, high $0.211 (portrait/landscape: $0.005 / $0.041 / $0.165). The guide gives no fixed per-image table for 2.5 ("Equal token rates don't mean equal cost per image") and points to its calculator. Older high-quality per-image prices: gpt-image-1.5 $0.133 square, gpt-image-1 $0.167, gpt-image-1-mini $0.036 — [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- Secondary, via fal (billed by fal, same token rates): GPT Image 2.5 at 1024² costs $0.0060 low, $0.0133 medium, $0.0528 high for text-to-image; edits with one 1024² reference cost $0.0142, $0.0215 and $0.0610. At 3840×2160 high: $0.1002 for text-to-image, $0.1084 for edit — [fal GPT Image 2.5](https://fal.ai/gpt-image-2.5)

### Inferences
- **Size mapping for vertical video (an HOOKKADR need):** `864x1536` is an exact 9:16 that meets every rule (both edges are multiples of 16; 1,327,104 px). `2160x3840` is an exact 9:16 at the pixel ceiling (8,294,400 px) but counts as experimental. The app's current `1024x1536` (2:3) for `9:16`/`4:5` therefore forces a crop; switch to exact custom sizes on 2.5.
- The per-image numbers from fal and OpenAI differ: fal's "high" for 2.5 ($0.0528) is about OpenAI's "medium" for gpt-image-2 ($0.053). Either 2.5 uses fewer output tokens or the quality labels differ between them. Budget with OpenAI's calculator or `usage` tokens, not fixed per-image constants.
- For a product edit, prefer `/v1/images/edits` on `gpt-image-2.5-sunburst` with the product photo as the **first** image (the mask applies to the first image). Even so, OpenAI says masks are not pixel-exact; see the use-case section for a compositing fallback.
- No webhook or async-job mechanism is documented for the Images API. Requests are synchronous and can take about 2 minutes, so the Node server should run them as background jobs and push the result to the app. Batch (50% off) only suits non-interactive work.

### Gaps
- Explicit maximum number of reference images on `/v1/images/edits` for 2.5 (the docs show only a 4-image example).
- Whether `input_fidelity` is accepted or ignored on 2.5 models, and whether `gpt-image-2` supports `background: "transparent"` (the guide states it only for 2.5).
- RPM limits and free-tier limits are not on the model pages; the tier names (Build/Launch/Grow) replace the older Tier 1–5 scheme, and how they map is unverified.
- The organization-verification wording is "may need to"; current exact conditions were not found.

## Google: Gemini image models (Nano Banana family), Imagen and Vertex AI (now "Gemini Enterprise Agent Platform")

### Takeaway
Current IDs: `gemini-nano-banana-2.1` (recommended, GA 6 Oct 2026), `gemini-3.1-flash-image` (Nano Banana 2), `gemini-3.1-flash-lite-image` (Nano Banana 2 Lite), `gemini-3-pro-image` (Nano Banana Pro) and the legacy `gemini-2.5-flash-image`. **Imagen is shut down or deprecated on both the Gemini API and Vertex.** All outputs carry SynthID. None of the Gemini image models documents mask-based inpainting, and the Gemini API has no free tier for image models. Uzbekistan is a supported Gemini API region.

### Cited Findings
**Models, references, resolutions**
- Model table: Nano Banana 2.1 `gemini-nano-banana-2.1`; Nano Banana 2 Lite `gemini-3.1-flash-lite-image`; Nano Banana 2 `gemini-3.1-flash-image`; Nano Banana Pro `gemini-3-pro-image`; Nano Banana (legacy) `gemini-2.5-flash-image` — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Model status: `gemini-nano-banana-2.1` "New Stable"; 3.1 Flash Image, 3.1 Flash Lite Image and 3 Pro Image "Stable" [page last updated 2026-10-13] — [Gemini models](https://ai.google.dev/gemini-api/docs/models)
- Release dates: `gemini-3.1-flash-image` and `gemini-3-pro-image` released (GA) May 28, 2026 with no shutdown announced; 4K output became GA on Aug 31, 2026; `gemini-nano-banana-2.1` reached GA on Oct 6, 2026 ("optimized for high-speed multimodal image generation and editing", 1K/2K/4K) — [Gemini API Deprecations](https://ai.google.dev/gemini-api/docs/deprecations); [Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes)
- Reference images, up to 14 in total: Flash Lite takes 14 object images and no character images; Nano Banana 2.1 and 3.1 Flash take 10 object and 4 character images; 3 Pro takes 6 object, 5 character and 3 style images — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Resolutions: 1K/2K/4K, with Flash Lite limited to 1K. 512px ("0.5K") exists only on 3.1 Flash Image. `image_size` must use an uppercase K ("Lowercase parameters (e.g., 1k) will be rejected."), and Gemini 3 image models default to 1K. The documented Flash Lite aspect ratios are 1:1, 3:2, 2:3, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9 — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Flash Lite is "Not optimized for multiple reference inputs or multi-turn sequential editing" — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)

**Editing, grounding, thinking**
- Text-and-image-to-image editing is supported. Multi-turn conversational editing via `previous_interaction_id` is "the recommended way to iterate on images". Masks and inpainting are not mentioned — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Google Search grounding works on every model except Flash Lite. Google Image Search grounding works only on 2.1 and 3.1 Flash. Video-to-image input (YouTube URL or Files API) works on 2.1, 3.1 Flash and 3.1 Flash Lite — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Thinking "cannot be disabled in the API". 2.1 supports minimal/medium/high (default medium); 3.1 Flash and Flash Lite support minimal/high (default minimal). Up to 2 interim "thought" images may be produced. Thinking tokens are billed — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Text rendering guidance: "Use Gemini 3 Pro Image for professional asset production" (accurate text in images) — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Watermark: "All generated images include a SynthID watermark." — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)

**API surface**
- The official image-generation docs now show only the **Interactions API**: REST `POST https://generativelanguage.googleapis.com/v1beta/interactions`, with image settings in `response_format: {"type":"image", "mime_type", "aspect_ratio", "image_size"}`. `generateContent` is not mentioned — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Secondary/localized: Google recommends the Interactions API "for all new projects", and a localized page describes `generateContent` as still supported but legacy — [Gemini API (ja)](https://ai.google.dev/gemini-api?hl=ja). Vertex/Agent Platform docs still show `gemini-3.1-flash-image` called via `generate_content` with `response_modalities` — [Vertex: Generate images with Gemini](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/image-generation?hl=en)
- Secondary (forum user report): with `generateContent`, `generationConfig.imageConfig.{aspectRatio,imageSize}` works on 3.1 Flash Image, but with `responseModalities: ["IMAGE","TEXT"]` only 1K was returned; IMAGE-only returned the requested size — [Google AI forum](https://discuss.ai.google.dev/t/gemini-3-1-flash-image-preview-only-generate-1k-image/142496)

**Pricing (Gemini API, paid tier; "Not available" on the free tier for every image model)**
- Per image, Standard: `gemini-nano-banana-2.1` 1K $0.0336, 2K $0.0504, 4K $0.113; `gemini-3.1-flash-image` 0.5K $0.045, 1K $0.067, 2K $0.101, 4K $0.151; `gemini-3.1-flash-lite-image` 1K $0.0336; `gemini-3-pro-image` 1K/2K $0.134, 4K $0.24; `gemini-2.5-flash-image` $0.039 (up to 1024²) — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Per 1M tokens (input / image output): 2.1 $1.50 / $30; 3.1 Flash $0.50 / $60; Flash Lite $0.25 / $30; 3 Pro $2.00 / $120 — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Batch is roughly half price (2.1 at 1K $0.0168, Flash Lite 1K $0.0168, 3 Pro 1K/2K $0.067), with up to 24h turnaround — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing); [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- "5,000 free search requests per month" for Search grounding on Gemini 3+ — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)

**Imagen**
- Gemini API: `imagen-4.0-generate-001`, `imagen-4.0-ultra-generate-001` and `imagen-4.0-fast-generate-001` had shutdown on Aug 17, 2026 (replacement `gemini-nano-banana-2.1`); `imagen-3.0-generate-002` on Nov 10, 2025. The image docs call Imagen "Google's legacy text-to-image models (shut down)" — [Gemini API Deprecations](https://ai.google.dev/gemini-api/docs/deprecations); [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Vertex: a March 24, 2026 "Imagen generation GA endpoints deprecation" covers `imagegeneration@002`–`@006`, `imagetext@001`, **`imagen-3.0-capability-001`/`-002` (the mask-editing models)**, `imagen-3.0-*` and `imagen-4.0-*`, all mapped to `gemini-2.5-flash-image`. "We recommend updating your model endpoints before June 30, 2026" — [Vertex AI release notes](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/release-notes)
- Still on Vertex/Agent Platform: `imagen-product-recontext-preview-06-30` (product placed in new scenes; Preview, request form, 1:1 at 1024×1024 only, up to 4 outputs, 10 RPM per region) — [Imagen product recontext](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/product-recontext-preview-06-30); `virtual-try-on-001` (GA Jan 20, 2026, discontinuation Jan 20, 2027, English-only prompts) — [Virtual Try-On 001](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/virtual-try-on-001)

**Vertex AI → Agent Platform, regions**
- On April 22, 2026 Vertex AI was renamed Gemini Enterprise Agent Platform ("Agent Platform (formerly Vertex AI)"). `gemini-3.1-flash-image` is on the `us` and `eu` multi-region endpoints (Aug 31, 2026) — [Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes). Vertex docs are "no longer being updated" [Vertex deprecations page last updated 2026-10-09] — [Vertex deprecations](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/deprecations)
- The Gemini API / AI Studio region list includes Uzbekistan, Kazakhstan, Kyrgyzstan, Tajikistan and Turkmenistan, with no image-specific restriction noted [page last updated 2026-04-28] — [Gemini API available regions](https://ai.google.dev/gemini-api/docs/available-regions)
- Prices "may differ on Gemini Enterprise Agent Platform" — [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)

### Inferences
- `gemini-nano-banana-2.1` is the best value default: half the price of 3.1 Flash at every resolution, GA, 10 object and 4 character references, Image Search grounding. Use `gemini-3-pro-image` when text/typography or style references matter, and Flash Lite for cheap 1K thumbnails.
- HOOKKADR's Gemini request shape (`generateContent` + `imageConfig.aspectRatio`) is the legacy surface. Migrating to the Interactions API (`response_format.aspect_ratio` / `image_size`) aligns with current docs. If the app stays on `generateContent`, it should send `responseModalities: ["IMAGE"]` to avoid the reported 1K cap.
- Google's product-specific editing (`imagen-3.0-capability-001` mask editing, Imagen 4) is going away. The remaining product-specific option, product recontext, is preview/allowlisted and 1024² square, which is a poor fit for 9:16 video.
- Uzbekistan's presence on the Gemini API list means direct server-side use from an Uzbek company or account is permitted. Google's "account age verification / 18+" requirements apply.

### Gaps
- No complete, per-model aspect-ratio list or pixel-dimension table was retrieved for 2.1, 3.1 Flash or 3 Pro (the docs page truncated).
- The documented limitations on people/children images and best-supported prompt languages for Gemini 3.x image models were not found in the retrieved text.
- Whether `generateContent` will be retired for image models, and on what date, is unknown.
- Agent Platform regional availability beyond `us`/`eu` for the Gemini image models was not found; no Central-Asia-specific Vertex region info.
- `gemini-3-pro-image` has no recommended replacement listed and no shutdown date.

## Other providers with official APIs: BFL FLUX, Ideogram, Recraft, Stability AI, ByteDance Seedream, fal.ai, Replicate

### Takeaway
BFL (FLUX.2 GA; FLUX 3 Image newly listed), Ideogram (4.0/4.5, now also reselling GPT-Image and Nano Banana) and Recraft (V4.1, OpenAI-SDK compatible) all have first-party REST APIs with clear pricing. Seedream 5.0 is easiest to reach via fal or BytePlus ModelArk. fal and Replicate are the aggregators with queue and webhook patterns. Stability AI's official 2026 docs could not be read, and its secondary pricing info looks stale.

### Cited Findings
**Black Forest Labs (FLUX)**
- Families: FLUX 3 (Video, Image, Audio, Action), FLUX.2 ("remains fully supported for production image generation and editing"), FLUX.1 Kontext, FLUX Tools (outpainting, erase, deblur, virtual try-on) — [BFL docs home](https://docs.bfl.ai/)
- FLUX 3 Image: endpoint `/v1/flux-3-image` for generation and editing; "add up to ten reference images to edit, restyle, or combine them"; "Output goes up to 4K"; "Bounding boxes in the prompt place each element" — [FLUX 3 overview](https://docs.bfl.ai/flux_3/flux3_overview)
- FLUX 3 was announced July 23, 2026. At launch, Video/Action were in gated early access and FLUX 3 Image was "expected in the coming weeks" (secondary) — [DataNorth](https://datanorth.ai/news/black-forest-labs-releases-flux-3); [LetsDataScience](https://letsdatascience.com/news/black-forest-labs-releases-multimodal-flux-3-56455df8). BFL's pricing page now lists FLUX 3 Image per-image prices: `768sq` $0.041, `1k` $0.048, `2k` (~4MP) $0.100, `4k` (~16MP) $0.607 — [BFL pricing](https://docs.bfl.ai/quick_start/pricing)
- FLUX.2 endpoints: `/flux-2-max`, `/flux-2-pro`, `/flux-2-pro-preview`, `/flux-2-flex`, `/flux-2-klein-4b`, `/flux-2-klein-9b`, `/flux-2-klein-9b-preview`. FLUX.1: `/flux-kontext-max`, `/flux-kontext-pro`, `/flux-pro-1.1-ultra`, `/flux-pro-1.1`, `/flux-pro`, `/flux-dev`. `/flux-2-pro` is the "recommended default model". Other titles: FLUX.1 Fill [pro] (mask inpaint), FLUX.1 Expand [pro], Erase, Deblur, Virtual try-on v2 (`/vto-v1`) — [BFL generating images](https://docs.bfl.ai/quick_start/generating_images); [BFL llms.txt](https://docs.bfl.ai/llms.txt)
- FLUX.2 references: [max]/[pro]/[flex] take up to 8 via API (10 in the playground); [klein] takes up to 4. Output is "up to 4MP". Hex-code colour control, JSON structured prompts, "Reliable text rendering"; [flex] is "Specialized for typography" — [FLUX.2 overview](https://docs.bfl.ai/flux_2/flux2_overview)
- FLUX.2 pricing (per megapixel; "from" = 1MP): klein 4B $0.014, klein 9B $0.015, pro $0.03 for text-to-image and $0.045 for edit, max $0.07, flex $0.05. FLUX.1 Kontext [pro] $0.04, Kontext [max] $0.08, FLUX1.1 [pro] $0.04, Ultra/Raw $0.06, Fill [pro] $0.05. 1 credit = $0.01 — [BFL pricing](https://docs.bfl.ai/quick_start/pricing)
- Async pattern: POST `https://api.bfl.ai/v1/<endpoint>` with header `x-key`, which returns `id` and `polling_url`. Poll with GET (about 0.5s apart) until `status` is `"Ready"` (or `"Error"`/`"Failed"`), then read `result.sample`. Regional bases: `api.bfl.ai` (global, recommended, failover), `api.eu.bfl.ai` (EU/GDPR), `api.us.bfl.ai`. "Our signed URLs are only valid for 10 minutes", and CORS is not enabled on them. Limit is 24 active tasks (429 when exceeded); `flux-kontext-max` allows 6 — [BFL generating images](https://docs.bfl.ai/quick_start/generating_images). The FLUX 3 docs say result URLs "expire about 2 hours after the job finishes" — [FLUX 3 overview](https://docs.bfl.ai/flux_3/flux3_overview)
- Terms (from search snippets of official pages; not fully read): BFL "claims no ownership rights" in outputs, and outputs may be used commercially. The API Service Terms grant BFL a license to use Inputs and Outputs, including "to train and improve our artificial intelligence models" (terms revised May 29, 2025 per snippet) — [BFL Terms of Service](https://bfl.ai/terms-of-service); [FLUX API Service Terms](https://bfl.ai/legal/flux-api-service-terms). Self-hosted FLUX.2 [klein] is "Apache 2.0 / FLUX Non-Commercial" — [BFL docs home](https://docs.bfl.ai/)

**Ideogram**
- Docs v2 index: Generate `ideogram-4-5`, `ideogram-4`, `ideogram-4-transparent`, `ideogram-3`, `ideogram-3-character`, `ideogram-3-transparent`, `auto`. **Precise Edit `ideogram-4-5`**; Inpaint `ideogram-3`; Remix; Reframe; Replace Background (`ideogram-3`, `gpt-image-2`, and an Ideogram 4.5 tool); Remove Background; Remove Object; Describe; **Layerize text `ideogram-3`**; Upscale (Topaz models). Ideogram also proxies `gpt-image-2-5-flare`, `gpt-image-2-5-sunburst`, `gpt-image-2`, `nano-banana-2`, `nano-banana-2-1`, `nano-banana-pro`, plus video (Kling 3, MiniMax H3, Seedance 2/2.5) and ad tools (ad-localizer, ad-resizer, material-swap, colorways) — [Ideogram docs v2 index](https://developer.ideogram.ai/v2/llms.txt)
- Precise Edit 4.5: `POST https://api.ideogram.ai/v2/image/precise-edit/ideogram-4-5`, header `Api-Key`, multipart. `mask` uses black for the edit area and white to keep. Up to 4 `reference_images` (3 with a mask). `context_window` region. Output "always matches this image's width and height" and **unchanged pixels are copied from the source image**. Optional `async` (poll `GET /v2/generations/{generation_id}`) and `webhook_url` with Ed25519-signed POSTs verified via `https://api.ideogram.ai/v1/.well-known/jwks.json`. `dry_run` returns a price quote. Also `enable_copyright_detection`; 422 on safety failure; `is_image_safe=false` gives an empty url — [Ideogram Precise Edit 4.5](https://developer.ideogram.ai/v2/api-reference/images/precise-edit/ideogram-4-5.md)
- Ideogram 3.0 generate (`POST https://api.ideogram.ai/v1/ideogram-v3/generate`): `style_type` AUTO/GENERAL/REALISTIC/DESIGN/FICTION, `style_reference_images`, `character_reference_images` ("currently supports only 1 image"), `color_palette`. Image links are temporary — [Ideogram generate v3](https://developer.ideogram.ai/api-reference/api-reference/generate-v3)
- "Default rate limit is 10 in-flight requests." API prices did not render ("Loading current prices.") — [Ideogram API pricing](https://ideogram.ai/pricing/?pricing_tab=api)
- Secondary: Ideogram 4.0 was released June 3, 2026 as an open-weight model (non-commercial weights license); 4.5 focuses on precise editing — [gradually.ai Ideogram 4.5](https://www.gradually.ai/en/ai-models/ideogram-4-5/); [Wikipedia: Ideogram](https://en.wikipedia.org/wiki/Ideogram_(text-to-image_model))

**Recraft**
- Base URL `https://external.api.recraft.ai/v1`; `POST /images/generations`. Works with the OpenAI Python SDK by setting `base_url`. The default model is V4.1 at $0.035/image; V4.1 Flash is about 1.3s at $0.007; `_vector` models give editable SVG. Files are kept "about 24 hours" — [Recraft getting started](https://www.recraft.ai/docs/api-reference/getting-started)
- Prices (1,000 units = $1). V4.1 raster $0.035, vector $0.08, Pro raster (2K) $0.21. V4 $0.04. V3 (`recraftv3`/`recraftv3_vector`) edits — image-to-image, inpainting, outpainting, replace background, generate background — cost $0.04 raster / $0.08 vector. Tools: erase region $0.002, crisp upscale $0.004, remove background $0.01, vectorize $0.01, creative upscale $0.25 — [Recraft pricing](https://www.recraft.ai/docs/api-reference/pricing)

**Stability AI**
- The official docs and pricing (`platform.stability.ai`) are JavaScript-rendered and could not be read. The v2beta OpenAPI URL returned 404 — [Stability platform](https://platform.stability.ai/docs/api-reference)
- Secondary (June 2026): 1 credit = $0.01; Stable Image Core $0.03, Stable Image Ultra about $0.08, SD 3.5 Large 6.5 credits, SD 3.5 Medium 3.5 credits; edit and upscale cost about 3–25 credits — [Puter: Stability pricing](https://developer.puter.com/tutorials/stability-ai-api-pricing/). Secondary reviews found no new 2026 Stability image model — [NeuronFeed review](https://neuronfeed.com/reviews/stability-ai-review)

**ByteDance Seedream**
- fal launched Seedream 5.0 Pro (press release July 9, 2026; available July 8). It renders up to 2K, aspect ratios from 1:16 to 16:1, "up to 10 reference images", "native text in 14 languages", up to 6 images per request. Endpoints `bytedance/seedream/v5/pro/text-to-image` and `bytedance/seedream/v5/pro/edit`. Price: $0.0675 per image up to 1536² and $0.135 up to 2048²; extra reference images cost $0.0045 each (the first is free) — [fal Seedream 5.0 Pro press release](https://natlawreview.com/press-releases/fal-launches-seedream-50-pro-api-bringing-bytedances-new-image-model)
- BytePlus ModelArk (the first-party route) has a "Seedream 5.0 pro / flash tutorial" page [last updated Oct 10, 2026], but its body did not render — [BytePlus ModelArk](https://docs.byteplus.com/en/docs/ModelArk/2582774). Secondary: the ModelArk ID is `seedream-5-0-pro-260628`, Lite is `seedream-5-0-260128`, and the endpoint is `POST https://ark.ap-southeast.bytepluses.com/api/v3/images/generations`; Pro takes up to 10 references and Lite up to 14 — [mer.vin](https://mer.vin/2026/07/seedream-5-0-pro-api-on-byteplus-precision-image-generation-and-multi-reference-editing/); [kie.ai guide](https://kie.ai/es/blog/how-to-use-seedream-5)

**fal.ai (aggregator)**
- Queue: `POST https://queue.fal.run/{model_id}` returns `request_id`, `status_url`, `response_url` and `cancel_url`. Status: `GET .../requests/{id}/status` (with an SSE stream variant); result: `GET .../requests/{id}`; cancel: `PUT .../cancel`. Auth header is `Authorization: Key $FAL_KEY`. Webhook via the `?fal_webhook=` query param (JS `webhookUrl`), with payload `request_id`, `gateway_request_id`, `status` "OK"/"ERROR", `payload`. JS client is `@fal-ai/client`. "No queue size limit" — [fal queue docs](https://fal.ai/docs/model-apis/model-endpoints/queue)
- Image endpoints include `openai/gpt-image-2.5/{flare|sunburst}/{text-to-image|edit}` (billed through fal, no OpenAI key needed), `fal-ai/nano-banana-pro/edit`, `fal-ai/flux-2-flex`, Seedream 5.0 — [fal GPT Image 2.5](https://fal.ai/gpt-image-2.5)

**Replicate (aggregator)**
- Official models via `models.predictions.create` and community models via `predictions.create`. Sync mode uses the header `Prefer: wait` (default 60s; `Prefer: wait=5` sets the wait). Async takes `webhook` plus `webhook_events_filter` (e.g. `["completed"]`) — [Replicate create a prediction](https://replicate.com/docs/topics/predictions/create-a-prediction)
- "Input and output (including any files) are automatically deleted after an hour for any predictions created through the API." Webhooks fire on created, updated and finished — [Replicate webhooks](https://replicate.com/docs/topics/webhooks)

### Inferences
- **Result URLs expire quickly everywhere** (BFL 10 min, Replicate 1 h, Recraft about 24 h, Ideogram "limited"). The HOOKKADR server must download each result immediately and re-host it in its own storage before handing a URL to the Flutter app.
- For a single adapter interface on the Node server, model it as `submit → (poll | webhook) → fetch bytes`. BFL (polling), fal (queue and webhook), Replicate (webhook or `Prefer: wait`) and Ideogram (sync, async and webhook) all fit. OpenAI and Gemini are synchronous and can be wrapped in the server's own job queue.
- fal is the fastest way to reach Seedream, FLUX, Nano Banana and GPT-Image through one key and bill. The trade-off is a reseller layer: no first-party SLA and possible markups. Ideogram's v2 API is now also a multi-model gateway.
- FLUX 3 Image status (preview vs GA) is not explicit. Treat it as new and verify availability before depending on it; FLUX.2 [pro] is the documented "recommended default".

### Gaps
- Stability AI: current official model list, endpoints, credit prices and any 2026 changes could not be verified from primary sources.
- Seedream: official BytePlus model IDs, pricing and regional availability (incl. Central Asia) are not verified first-hand.
- Ideogram per-image API prices (the page rendered no prices) and official 4.0/4.5 release dates.
- BFL webhook support (`webhook_url`/`webhook_secret`) is not shown in the pages read. Whether FLUX 3 Image is GA is unclear.
- Commercial-use terms for fal-hosted and Replicate-hosted outputs (they depend on each upstream model license) were not reviewed.
- Recraft: exact API model ID strings for V4/V4.1 (only doc slugs `recraft-v4-1`, `recraft-v4-1-flash` were seen), sizes and rate limits.

## Best providers for: (a) exact product preservation, (b) text rendering, (c) consistency across images, (d) background replacement / object removal

### Takeaway
No provider guarantees pixel-exact preservation of a product (such as a tile pattern) through generative editing, except where only a masked region is regenerated and the rest is copied (Ideogram 4.5 Precise Edit states this). For HOOKKADR, the honest and robust design is: segment the product → generate or replace only the background (or scene) → composite the original product pixels back. Use multi-reference models (gpt-image-2.5-sunburst, Nano Banana 2.1/Pro, FLUX.2/3, Seedream 5.0 Pro) when the product must be re-posed or relit.

### Cited Findings
**Capability matrix (current IDs, October 2026)**

| Provider / model ID | Edit / mask | Max refs | Max res | Transparent BG | Text rendering note | Price (approx, 1K-ish) | Async / webhook |
|---|---|---|---|---|---|---|---|
| OpenAI `gpt-image-2.5-sunburst` / `-flare` | edits + prompt-based mask (first image) | not stated (4 in example) | 3840 edge, ≤8.29MP | yes (png/webp) | doc lists "weaker text rendering" | token-billed; fal: $0.006–0.053 at 1024² | sync (≈2 min max); Batch |
| Google `gemini-nano-banana-2.1` | conversational edit, no mask | 10 object + 4 character | 4K | not documented | — | $0.0336 (1K) / $0.113 (4K) | sync; Batch |
| Google `gemini-3-pro-image` | conversational edit, no mask | 6 object + 5 character + 3 style | 4K | not documented | recommended for accurate text | $0.134 (1K/2K) | sync; Batch |
| Google `gemini-3.1-flash-lite-image` | basic edit; not for multi-ref | 14 object | 1K | not documented | — | $0.0336 | sync; Batch |
| BFL `/flux-2-pro` (`max`, `flex`) | edit; Fill [pro] for mask | 8 (API) | 4MP | — | flex "Specialized for typography" | $0.03 / $0.045 edit | poll `polling_url` |
| BFL `/v1/flux-3-image` | edit + bounding boxes | 10 | 4K | — | — | $0.048 (1k) | poll |
| Ideogram `ideogram-4-5` Precise Edit | mask; unchanged pixels copied | 4 (3 w/ mask) | = input | `ideogram-4-transparent` gen | Ideogram's core strength; Layerize text | not published | sync / async / signed webhook |
| Recraft V4.1 / `recraftv3` edits | inpaint, replace/generate BG, erase | style refs | Pro 2K | remove BG tool | vector/SVG output | $0.035 gen; $0.04 edit; $0.01 remove BG | sync |
| Seedream 5.0 Pro (fal `bytedance/seedream/v5/pro/edit`) | edit one element, layer separation | 10 | 2K | — | "native text in 14 languages" | $0.0675 (≤1536²) | fal queue + webhook |

Sources for the matrix: [OpenAI guide](https://developers.openai.com/api/docs/guides/image-generation), [fal GPT Image 2.5](https://fal.ai/gpt-image-2.5), [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing), [FLUX.2 overview](https://docs.bfl.ai/flux_2/flux2_overview), [FLUX 3 overview](https://docs.bfl.ai/flux_3/flux3_overview), [BFL pricing](https://docs.bfl.ai/quick_start/pricing), [Ideogram Precise Edit 4.5](https://developer.ideogram.ai/v2/api-reference/images/precise-edit/ideogram-4-5.md), [Ideogram docs index](https://developer.ideogram.ai/v2/llms.txt), [Recraft pricing](https://www.recraft.ai/docs/api-reference/pricing), [fal Seedream press release](https://natlawreview.com/press-releases/fal-launches-seedream-50-pro-api-bringing-bytedances-new-image-model)

**Evidence per use case**
- (a) Preservation: OpenAI masks "may not follow its exact shape with complete precision", and its documented limitations include "imperfect character or brand consistency" — [OpenAI guide](https://developers.openai.com/api/docs/guides/image-generation). Ideogram 4.5 Precise Edit: output equals input size and "unchanged pixels are copied from the source image" — [Ideogram Precise Edit 4.5](https://developer.ideogram.ai/v2/api-reference/images/precise-edit/ideogram-4-5.md). Gemini edits "match the original image's style, lighting, and perspective" but have no mask — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation). Google's product recontext model is preview-only, 1024² square — [Imagen product recontext](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/product-recontext-preview-06-30). FLUX.2 offers hex-exact colour prompting — [FLUX.2 overview](https://docs.bfl.ai/flux_2/flux2_overview)
- (b) Text: Gemini docs say "Use Gemini 3 Pro Image for professional asset production" — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation). FLUX.2 [flex] is "Specialized for typography" — [FLUX.2 overview](https://docs.bfl.ai/flux_2/flux2_overview). Ideogram exposes text-specific tooling ("Layerize text with Ideogram 3.0", ad-localizer) — [Ideogram docs index](https://developer.ideogram.ai/v2/llms.txt). Seedream 5.0 Pro claims "native text in 14 languages" — [fal press release](https://natlawreview.com/press-releases/fal-launches-seedream-50-pro-api-bringing-bytedances-new-image-model). OpenAI lists "weaker text rendering" as a limitation — [OpenAI guide](https://developers.openai.com/api/docs/guides/image-generation)
- (c) Consistency: Gemini 2.1/3.1 Flash take 4 and Pro 5 character references, plus Pro's 3 style references — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation). FLUX 3 Image takes 10 references and FLUX.2 takes 8 — [FLUX 3 overview](https://docs.bfl.ai/flux_3/flux3_overview); [FLUX.2 overview](https://docs.bfl.ai/flux_2/flux2_overview). Ideogram 3 accepts 1 character reference — [Ideogram generate v3](https://developer.ideogram.ai/api-reference/api-reference/generate-v3). Secondary: Sunburst is "better at preserving earlier edits and reference subjects across turns" — [fal GPT Image 2.5](https://fal.ai/gpt-image-2.5)
- (d) Background/object tools: Ideogram has Remove Background, Remove Object and Replace Background endpoints — [Ideogram docs index](https://developer.ideogram.ai/v2/llms.txt). Recraft has remove background ($0.01), replace or generate background ($0.04) and erase region ($0.002) — [Recraft pricing](https://www.recraft.ai/docs/api-reference/pricing). BFL Tools offer Erase, Expand and Fill [pro] — [BFL llms.txt](https://docs.bfl.ai/llms.txt). OpenAI supports `background: "transparent"` on 2.5 — [OpenAI guide](https://developers.openai.com/api/docs/guides/image-generation)

### Inferences
- **(a) Ceramic tile / exact product:** first choice is a deterministic pipeline: background removal (Recraft $0.01 or Ideogram remove-background) → scene generation around the cut-out (Ideogram 4.5 Precise Edit with an inverted mask, Recraft "generate background", or FLUX Fill [pro]) → re-composite the original product pixels in the server or FFmpeg (`render_plan.dart`) so the pattern is untouched. Fallback, when the product must be re-angled or relit: `gpt-image-2.5-sunburst` (high-fidelity inputs) or `gemini-3-pro-image` (6 object references). Tell the user the pattern may drift; this follows the project's honesty rule.
- **(b) Text (including Uzbek Latin captions):** Ideogram 4.x and `gemini-3-pro-image` are the strongest documented options, with FLUX.2 [flex] and Seedream 5.0 Pro as alternatives. For HOOKKADR, rendering on-screen text in FFmpeg instead of baking it into AI images is more reliable and editable. AI text rendering is better reserved for stylised titles.
- **(c) Consistency across a series:** Nano Banana 2.1 (cheap, 4 character + 10 object references) is the default. Use Nano Banana Pro or FLUX 3 Image (10 references, box placement) for harder cases, and Sunburst multi-turn via the Responses API with `previous_response_id`. Always resend the same reference set on every call.
- **(d) Background replacement / object removal:** use dedicated, cheap, deterministic-ish endpoints (Recraft, Ideogram, BFL Erase) rather than general LLM-image editing.

### Gaps
- No independent, current benchmark comparing product-fidelity across these providers was found. The recommendations above rest on documented features, not measured accuracy.
- No provider documents Uzbek-language (Latin or Cyrillic) text-rendering quality.
- Ideogram per-call prices are unknown (use `dry_run` to quote).

## Content-policy constraints: real people, celebrities, logos

### Takeaway
All providers moderate inputs and outputs and return structured refusals: OpenAI `moderation_blocked`, Ideogram 422 or `is_image_safe=false`, and Gemini returning no image. Google's policy forbids deceptive impersonation and IP infringement, and every Gemini image carries SynthID. No primary API-specific rule on generating celebrity likenesses or third-party logos was retrievable, so the app must assume such requests can be refused and must not claim success when they are.

### Cited Findings
- OpenAI image API: `moderation` takes `auto` (default) or `low`. Blocks return `moderation_blocked` with `moderation_stage` (`input`/`output`) and coarse `categories`. The sample hint for harassment says "Remove abusive or targeting language and focus on neutral visual details" — [OpenAI image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- OpenAI's usage-policies page returned HTTP 403 to the fetcher, so it was not read — [OpenAI usage policies](https://openai.com/policies/usage-policies/). Secondary, March 2025, about ChatGPT and not necessarily the API: OpenAI moved public figures from blanket blocking to an **opt-out** model, and still blocks prompts naming individual living artists while allowing studio styles — [CO/AI](https://getcoai.com/news/chatgpts-image-generator-now-creates-public-figures-and-controversial-content); [The Decoder](https://the-decoder.com/openai-outlines-new-image-generation-rules-for-chatgpt/)
- Google Generative AI Prohibited Use Policy [last modified Dec 17, 2024] prohibits "Impersonating an individual (living or dead) without explicit disclosure, in order to deceive", "Facilitates non-consensual intimate imagery", "Violates the rights of others, including privacy and intellectual property rights", and "Misrepresenting the provenance of generated content…" — [Google GenAI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy)
- Gemini: "All generated images include a SynthID watermark." — [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)
- Ideogram: the `enable_copyright_detection` flag is on generate and edit, 422 means "prompt failed safety checks", and an unsafe image is returned with an empty `url` — [Ideogram Precise Edit 4.5](https://developer.ideogram.ai/v2/api-reference/images/precise-edit/ideogram-4-5.md); [Ideogram generate v3](https://developer.ideogram.ai/api-reference/api-reference/generate-v3)
- BFL: outputs may be used commercially (no ownership claimed), but BFL may use API inputs and outputs to train its models (from search snippets of the official terms) — [BFL Terms](https://bfl.ai/terms-of-service); [FLUX API Service Terms](https://bfl.ai/legal/flux-api-service-terms)
- Google Virtual Try-On (person + product) is GA but English-only prompts — [Virtual Try-On 001](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/virtual-try-on-001)

### Inferences
- HOOKKADR should surface provider refusals as explicit Uzbek messages (the app already has "so'rov rad etilgan bo'lishi mumkin" for Gemini). It should map OpenAI's `moderation_stage` and `categories` and Ideogram's 422 / `is_image_safe` to clear user-facing reasons, rather than silently retrying another provider with the same prompt.
- For user-uploaded logos (a seller's own brand), compositing the original logo file in FFmpeg avoids both IP-filter refusals and logo distortion. Do not ask models to reproduce third-party trademarks.
- Because BFL's terms allow training on API inputs, uploading customers' unreleased product photos to BFL needs disclosure or an enterprise agreement. Check the equivalent data-use terms for OpenAI and Google before choosing a default.

### Gaps
- Current OpenAI API-specific policy text on public-figure likeness, minors and trademarks, which could not be fetched (403).
- Gemini 3.x image-specific restrictions on real people and children (e.g., any EEA/UK rules) were not found in the retrieved pages.
- Data-retention and training-use terms for OpenAI and Gemini image inputs were not reviewed in this pass.
