# AI video generation APIs, capability matrix as of 14 October 2026

Research date: 2026-10-14. Every page was fetched on that date. A page's own "last updated" date is given wherever it shows one. "3P" marks a third-party or reseller source. Treat 3P figures as unverified.

## Q1. Is `veo-3.1-generate-preview` (Gemini API, predictLongRunning + operation polling) still current?

### Takeaway
Yes, with caveats. `veo-3.1-generate-preview` is still a live, priced model on the Gemini API, but it is still labeled Preview. The Gemini API has no GA `-001` Veo 3.1 ID. A GA ID, `veo-3.1-generate-001`, exists only on Vertex AI (renamed "Gemini Enterprise Agent Platform"). Google's video docs now name **Gemini Omni Flash** (`gemini-omni-1.1-flash`, stable) as the default video model, and that model uses a different API (Interactions). The predictLongRunning + `operations` polling pattern is still the documented one for Veo.

### Cited Findings
- Gemini API Veo model table: `veo-3.1-generate-preview` is Preview, last updated January 2026. `veo-3.1-fast-generate-preview` is Preview, January 2026. `veo-3.1-lite-generate-preview` is Preview, March 2026. `veo-3.0-generate-001` and `veo-3.0-fast-generate-001` are marked Deprecated. No `veo-3.1-*-001` and no `veo-2.0-*` IDs are listed. — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo) (fetched 2026-10-14)
- The Gemini pricing page lists all three Veo 3.1 preview IDs as billable, and none of them is marked for deprecation. It lists no `veo-3-*` or `veo-2` models. — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing) (last updated 2026-10-13)
- Google's video overview says: "Use Gemini Omni Flash as your default model for video generation." It describes Veo 3.1 as supporting "video extension, frame-specific generation". — [Gemini API video overview](https://ai.google.dev/gemini-api/docs/video) (last updated 2026-06-30)
- Gemini Omni Flash IDs: stable `gemini-omni-1.1-flash`, preview `gemini-omni-flash-preview`, latest update August 2026. Output is "3s-10s (360p/720p/1080p/4K, 24 FPS)". Inputs are text, image, and video ("up to 10s for editing and extension"). — [Gemini Omni Flash model page](https://ai.google.dev/gemini-api/docs/models/gemini-omni-flash) (last updated 2026-08-27)
- The Spanish-language video docs call Omni Flash the default and recommend Veo 3.1 for specific needs: scene extension, last-frame control, and legacy pipelines (search-result summary only, page not fetched). — [Gemini video docs (es)](https://ai.google.dev/gemini-api/docs/video?hl=es)
- Veo REST pattern: `POST .../models/{model}:predictLongRunning` returns an operation `name`. Poll `GET` on that name until `done` is true, then read `response.generateVideoResponse.generatedSamples[0].video.uri`. The SDK examples poll every 10 s. — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- On Vertex AI / Gemini Enterprise Agent Platform:
  - `veo-3.1-generate-001` and `veo-3.1-fast-generate-001` are **GA**, released November 17, 2025, with retirement "November 17, 2026 or later".
  - `veo-3.1-lite-generate-001` is Preview, released April 2, 2026.
  - All three run in region `us-central1` only, with a quota of "50 … requests per base model per minute", and support Content Credentials (C2PA).
  - The page also lists "Pay-as-you-go: Not supported", which looks odd and needs checking in the console.
  — [Vertex Veo 3.1 model page](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate) (undated, fetched 2026-10-14)
- HOOKKADR code: `lib/features/ai/ai_clients.dart:441` sets `videoModel = 'veo-3.1-generate-preview'`. Line 497 calls `.../v1beta/models/$videoModel:predictLongRunning` from the Flutter client and sends only `prompt` and `aspectRatio`. Polling runs every 8 s with an 8-minute timeout. (Local repo, read 2026-10-14.)
- Related finding: the same file (line 437) uses `gemini-2.5-flash-image`, and the Gemini pricing page says that model was "scheduled to shut down on October 2, 2026". That date has already passed. — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)

### Inferences
- The ID is still current, but it is a preview model with stricter rate limits. The rate-limits page says limits "are more restricted for experimental and preview models" ([Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), 2026-10-13). For GA/SLA-grade Veo, Vertex `veo-3.1-generate-001` (us-central1) is the path.
- HOOKKADR could add a second Google adapter for `gemini-omni-1.1-flash`: it is stable, about $0.10/s at 720p, and supports multi-turn editing. Veo 3.1 would remain for extension and first/last-frame control.
- The Veo call runs from the Flutter client with a user key. CLAUDE.md says "AI kalitlari faqat serverda" (AI keys only on the server), so this conflicts with project policy. A server-side adapter in `server/` would fix it.
- The `gemini-2.5-flash-image` dependency is probably broken now and needs to move to a current image model. This is outside this research scope; verify separately.

### Gaps
- The Gemini API pages do not say whether `veo-3.1-generate-preview` will get a GA alias, or when it will be retired.
- The exact Gemini API Veo RPM/RPD per tier is not published in the docs. It is shown only in AI Studio (aistudio.google.com/rate-limit).

## Q2. Model IDs, durations, resolutions, aspect ratios, fps and inputs per provider

### Takeaway
By October 2026 the market has moved on from the providers named in the brief:
- The OpenAI Sora 2 API is gone (shut down September 24, 2026).
- Runway's API has become a multi-vendor catalog (Gen-4.5, Aleph 2.0, plus resold Veo, Seedance, MiniMax, Wan, and others).
- Luma moved to an Agents API with `ray-3.2`.
- MiniMax replaced Hailuo with H3.
- Seedance 2.0 and 2.5 are the most input-rich models.
- Kling 3.0 / 3.0 Omni is live, but its official docs could not be machine-read.

### Matrix (sourced detail follows below)

| Provider / model ID | Durations | Resolution | Aspect | fps | Inputs |
|---|---|---|---|---|---|
| Google `veo-3.1-generate-preview` / `-fast-` (Gemini API) | 4, 6, 8 s (8 s required for 1080p, 4K, ref images, extension) | 720p, 1080p, 4K (Fast: 4K yes on Gemini) | 16:9, 9:16 | 24 | text, image (first frame), lastFrame, up to 3 referenceImages, video extension |
| Google `veo-3.1-lite-generate-preview` | 4, 6, 8 s | 720p, 1080p (no 4K) | 16:9, 9:16 | 24 | text, image, lastFrame (no refs, no extension) |
| Google `veo-3.1-generate-001` (Vertex GA) | 4, 6, 8 s | 720p, 1080p, 4K | 16:9, 9:16 | 24 | text, image, refs; up to 4 videos per prompt |
| Google `gemini-omni-1.1-flash` | 3–10 s; extension up to 40 s total (docs conflict) | 360p, 720p, 1080p (upscaled), 4K (upscaled) | 16:9, 9:16 | 24 | text, multiple ref images, first/last frame, up to 3 video refs, video edit and extend (input ≤10 s) |
| OpenAI `sora-2`, `sora-2-pro` | SHUT DOWN 2026-09-24 | — | — | — | — |
| Runway `gen4.5` | 2–10 s (3P); 5/8/10 s (3P) | 720p (3P) | 1280:720, 720:1280, 960:960, 1104:832, 832:1104 (3P) | ? | text or image |
| Runway `gen4_turbo` | ? | ? | ? | ? | image to video |
| Runway `aleph2` | ? | ? | ? | ? | video to video editing, keyframe-guided |
| Luma `ray-3.2` (Agents API) | 5 s, 10 s | 540p, 720p, 1080p; HDR at 720p/1080p; EXR | 9:16, 3:4, 1:1, 4:3, 16:9, 21:9 | ? | text, start/end frame, up to 64 keyframes, extend, video_edit, video_reframe, loop |
| Luma `ray-2`, `ray-flash-2` (legacy Dream Machine API) | "5s", "9s" | 540p, 720p, 1080p, 4K | 1:1, 16:9, 9:16, 4:3, 3:4, 21:9, 9:21 | ? | text, frame0/frame1, extend, concepts (e.g. dolly_zoom), modify_video, add_audio |
| MiniMax `MiniMax-H3` | 4–15 s (integers) | 768P, 2K | ? | ? | text, first_frame, last_frame, up to 9 ref images, 3 ref videos, 3 ref audio |
| MiniMax `MiniMax-H3-Max` | 5–15 s | 480P, 768P | ? | ? | same roles |
| ByteDance `dreamina-seedance-2-0-260128` / `-fast-` | 4–15 s or auto | 480p, 720p, 1080p, 4K | 7 ratios incl. auto | 24 (in token formula) | text, image, up to 9 ref images, 3 ref videos, 3 ref audio (12 files total), edit and extend |
| ByteDance Seedance 2.5 (fal: `bytedance/seedance-2.5/*`) | 4–30 s | 480p, 720p (fal); 480p–1080p (Runway) | 7 | ? | up to 30 images, 10 videos, 10 audio (50 total) |
| Kling 3.0 / 3.0 Omni (fal: `fal-ai/kling-video/v3/pro/text-to-video`) | 3–15 s (3P) | 720p, 1080p (3P); 4K claimed (3P) | 16:9, 1:1, 9:16 (3P) | ? | text, image, multi-shot `multi_prompt`, elements/character refs (Omni) |
| Pika 2.2 (fal: `fal-ai/pika/v2.2/text-to-video`) | ? | up to 1080p | ? | ? | Pikaframes keyframes, Pikascenes refs |

### Cited Findings
**Google Veo (Gemini API)**
- Durations, resolution, aspect ratio and frame rate:
  - Veo 3.1 and 3.1 Fast: 4, 6 or 8 s, with "8s required for extension, reference images, 1080p, 4k". Resolutions are 720p (default), 1080p and 4K; extension output is 720p only. Aspect ratios are 16:9 (default) and 9:16. Frame rate is 24 fps.
  - One video per request. Text input is limited to 1,024 tokens.
  - Lite: no 4K, no referenceImages, no video extension.
  — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- Inputs: `image` (first frame), `lastFrame` (requires `image`), `referenceImages` (up to 3, Veo 3.1 and Fast only), and `video` (extension). — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- Extension rules:
  - The input must be a Veo-generated video, 720p, 16:9 or 9:16, and 141 s or shorter.
  - Each extension adds 7 s, up to 20 times, for a maximum output of 148 s.
  - Only videos generated in the last 2 days can be extended.
  — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- `seed` is mentioned only for Veo 3 models ("doesn't guarantee determinism, but slightly improves it"). The fetched page did not mention `negativePrompt`. — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- Replicate's `google/veo-3.1` page lists 4/6/8 s, 720p or 1080p at 24 fps, 16:9 and 9:16, "up to 3 reference images", and start/end frames. — [Replicate google/veo-3.1](https://replicate.com/google/veo-3.1) ("updated 6 months, 2 weeks ago")

**Google Vertex AI**
- For `veo-3.1-generate-001`, `veo-3.1-fast-generate-001` and `veo-3.1-lite-generate-001`:
  - Durations are 4, 6 or 8 s; reference-image-to-video is 8 s only.
  - Up to 4 output videos per prompt. Aspect ratios are 9:16 and 16:9. Frame rate is 24 fps.
  - Output resolution: 720p, 1080p and 4K for Generate; 720p and 1080p for Fast.
  - Image input is limited to 20 MB. The Lite row says image input is "Not supported", but the same page lists a 20 MB image limit for it, so the page contradicts itself.
  — [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate)

**Gemini Omni Flash**
- Resolutions are 360p, 720p (default), 1080p ("upscaled") and 4K ("upscaled"). Aspect ratios are 16:9 and 9:16.
- Image inputs work as numbered reference images (`<IMAGE_REF_N>`; the docs example uses 6), `<FIRST_FRAME>` and `<LAST_FRAME>`.
- Up to 3 video references are allowed, each up to 3 s. Uploaded videos for editing or extension must be 10 s or shorter.
- Negative prompts are not a parameter; put them in the prompt text instead.
- Extension length conflicts within the page: it says both "3–10 second continuation" and "by 10s, up to a total length of 40s".
— [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)

**OpenAI Sora 2**
- "The Sora 2 models and Videos API were shut down on September 24, 2026 and are no longer available … No one-to-one replacement API is available." — [OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)
- The deprecation was announced 2026-03-24. It removed the Videos API, `sora-2`, `sora-2-pro`, `sora-2-2025-10-06`, `sora-2-2025-12-08` and `sora-2-pro-2025-10-06`. No replacement is listed. — [OpenAI deprecations](https://developers.openai.com/api/docs/deprecations)
- Historical specs, for reference only:
  - 16 and 20 s generations; extensions of up to 20 s each, up to 6 times, for 120 s in total.
  - 1080p (`1920x1080`, `1080x1920`) required `sora-2-pro`.
  - `input_reference` served as the first frame, and images with human faces were rejected.
  — [OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)

**Runway**
- The API model catalog (47 models) includes:
  - Runway's own models: `gen4.5` (image_to_video, $0.12/s, text and image to video) and `gen4_turbo` ($0.05/s, "fastest image to video").
  - `aleph2`: video_to_video, $0.28/s, "in-context video editing with keyframe-guided control".
  - `act_two` (character performance).
  - Resold models: `veo3.1`, `veo3.1_fast`, `seedance2`, `seedance2_5`, `seedance2_fast`, `seedance2_mini`, `hailuo3`, `h3_max`, `wan3`, `wan3_prime`, `grok_imagine_1_5`, `happyhorse_1_0`, `gemini_omni_flash`, `gemini_omni_flash_1.1`.
  - `gen4_aleph` and `veo3` no longer appear.
  — [Runway API models](https://docs.dev.runwayml.com/guides/models/) (undated, fetched 2026-10-14)
- Gen-4.5 does text-to-video: "Simply omit the `promptImage` parameter to use text-to-video mode". The examples use `duration: 5` and `ratio: '1280:720'`. — [Runway API getting started](https://docs.dev.runwayml.com/guides/using-the-api/)
- 3P sources give Gen-4.5 durations as either 2–10 s or 5/8/10 s, capped at 720p, with ratios 1280:720, 720:1280, 1104:832, 960:960 and 832:1104. — [Wiro Gen-4.5 (3P)](https://wiro.ai/models/runway/gen-4-5); [Magnific proxy docs (3P)](https://docs.magnific.com/api-reference/video/runway-gen-4-5/generate-t2v.md)

**Luma**
- The legacy Dream Machine API v1.1.0 spec, last updated 2026-07-10:
  - Video model enum: `"ray-2"`, `"ray-flash-2"`. Duration: `"5s"`, `"9s"`. Resolution: `"540p"`, `"720p"`, `"1080p"`, `"4k"`.
  - Aspect ratios: `"1:1"`, `"16:9"`, `"9:16"`, `"4:3"`, `"3:4"`, `"21:9"`, `"9:21"`.
  - Keyframes `frame0`/`frame1`, each an image URL or a generation ID.
  - Generation types: `modify_video`, `reframe_video`, `upscale_video`, `add_audio`.
  - The page says that for current guides, developers should use the Luma Agents API.
  — [Luma create generation](https://docs.lumalabs.ai/reference/creategeneration.md); [Luma video generation guide](https://docs.lumalabs.ai/docs/video-generation)
- Camera "concepts" are passed as `"concepts": [{"key": "dolly_zoom"}]`, and camera motions are added to the prompt text. Both lists are available from list endpoints. Extend works only on generated videos. — [Luma video generation guide](https://docs.lumalabs.ai/docs/video-generation)
- The Luma Agents API exposes `ray-3.2`:
  - Durations: 5 s and 10 s. Resolutions: 540p, 720p and 1080p.
  - Aspect ratios: 9:16, 3:4, 1:1, 4:3, 16:9 and 21:9.
  - Image-to-video via `start_frame` and `end_frame`; multi-keyframe input "up to 64 anchors".
  - Extend from a prior generation, plus `video_edit` (`auto_controls`, or `strength` with per-signal controls) and `video_reframe`.
  - HDR at 720p and 1080p, and EXR in ACES2065-1, plus loop.
  - The page lists no 4K for Ray 3.2.
  — [Luma Agents models guide](https://docs.agents.lumalabs.ai/guides/model/) (undated); [Luma Agents API](https://docs.agents.lumalabs.ai/)
- 3P profiles mention "Ray3.14" with native 1080p. That name does not appear in Luma's current docs. — [each::labs (3P)](https://www.eachlabs.ai/luma/luma-ray)

**MiniMax (Hailuo, now H3)**
- `MiniMax-H3` ("an open, general-purpose multimodal video model") runs 4–15 s at 768P or 2K. `MiniMax-H3-Max` (jointly released with fal.ai) runs 5–15 s at 480P or 768P.
- First/last frame uses the roles `first_frame` and `last_frame`. Input images must be 256–5760 px per side, with aspect ratio between 2:5 and 5:2.
- Reference roles: `reference_image` (up to 9), `reference_video` (up to 3, combined length ≤15 s) and audio (up to 3), with at most 12 mixed files.
- For text-to-video, camera commands such as `[pan]`, `[zoom]` and `[static]` go inline in the prompt.
- Hailuo-02 and Hailuo-2.3 are now listed as legacy.
— [MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation); [MiniMax pricing](https://platform.minimax.io/docs/guides/pricing-paygo)

**ByteDance Seedance (BytePlus ModelArk)**
- The official model IDs are `dreamina-seedance-2-0-260128` and `dreamina-seedance-2-0-fast-260128`. Both take images, videos and audio as references and support video editing and extension (search-result summary of the official model list). The base URL in ap-southeast-1 is `https://ark.ap-southeast.bytepluses.com/api/v3`. — [BytePlus ModelArk model list](https://docs.byteplus.com/api/docs/ModelArk/1159178); [BytePlus model list index](https://docs.byteplus.com/en/docs/ModelArk/1330310?lang=en) (last updated 2026-10-13; the body was JS-rendered and not readable)
- 3P sources mention `dreamina-seedance-2-0-mini-260615` and say Seedance 2.5 was announced on July 31, 2026. The BytePlus sidebar now has a "Dreamina Seedance 2.5 tutorial". — [Vorp Labs (3P)](https://vorplabs.com/models/releases/seedance-2-5); [BytePlus index](https://docs.byteplus.com/en/docs/ModelArk/1330310?lang=en)
- fal specs, as of August 2026:
  - Seedance 2.0: 4–15 s or auto, at 480p/720p/1080p/4K, with ≤9 images, ≤3 videos and ≤3 audio (12 references in total).
  - Seedance 2.5: 4–30 s, at 480p/720p, with ≤30 images, ≤10 videos and ≤10 audio (50 in total).
  - Endpoints: `bytedance/seedance-2.0/{text-to-video|image-to-video|reference-to-video}` (each with a fast variant) and `bytedance/seedance-2.5/...`.
  — [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0) (2026-08-13)
- Conflict: Runway's catalog lists `seedance2_5` as "Up to 30s; 480p, 720p, 1080p", while fal lists only 480p and 720p. — [Runway API models](https://docs.dev.runwayml.com/guides/models/)

**Kling (Kuaishou)**
- The official docs (kling.ai/document-api) are rendered with JavaScript, so their text could not be extracted. The facts below come from search snippets and 3P sources.
- A search snippet of Kling's official model list shows `Kling-V3-Omni`, `Kling-Video-O1`, `Kling-V3` and `Kling-V2-6`. The official API changelog says the earlier default video `model_name` was `kling-v2-6`. — [Kling dev model list (snippet)](https://klingai.com/global/dev/model/tryon); [Kling API updates (snippet)](https://kling.ai/document-api/updates/api)
- 3P sources report that Kling 3.0 launched on February 4, 2026, with API access from February 5. They say clips run up to 15 s (3/5/8/10/15 s on Omni), with native audio and multi-shot. Kling 3.0 Omni (O3) is said to add subject and voice cloning. — [gaga.art (3P)](https://gaga.art/blog/kling-3-0/); [apiframe kling-3.0-omni (3P)](https://apiframe.ai/kr/models/kling-3.0-omni); [Atlas Cloud (3P)](https://atlascloud.ai/collections/kling-v3)
- On fal, `fal-ai/kling-video/v3/pro/text-to-video` is "Kling 3.0 Pro … native audio generation, with multi-shot support". It has `Multi Prompt` and `Shot Type` fields, with duration defaulting to 5. The related image-to-video endpoint is `fal-ai/kling-video/o3/standard/image-to-video`. — [fal Kling v3 Pro](https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video)

**Pika**
- Pika does not run a first-party developer API. Programmatic access goes through fal ("Pika API is now powered by fal"). Pika 2.2 is offered with Pikaframes (keyframe interpolation), Pikascenes and Pikaffects at up to 1080p. — [fal blog: Pika API powered by fal](https://blog.fal.ai/pika-api-is-now-powered-by-fal/); [fal blog: Pika models on fal](https://blog.fal.ai/pika-models-now-available-on-fal)

**Alibaba Wan (hosted)**
- `wan3` and `wan3_prime` are offered through Runway: "Native audio; 2–30s; 480p, 720p, 1080p; image, video, audio references". — [Runway API models](https://docs.dev.runwayml.com/guides/models/)

### Inferences
- For fps normalization in the FFmpeg timeline, Veo, Omni Flash and HunyuanVideo are documented at 24 fps. The other providers do not document fps, so HOOKKADR should always re-encode to a common fps and SAR rather than stream-copy.
- Sora should be removed from any provider list.

### Gaps
- The official Kling `model_name` strings for video, along with their durations, modes (std/pro) and `camera_control`, could not be confirmed from a primary source because the docs are JS-only.
- Runway's official per-model duration and ratio enums were not readable (API reference truncated).
- Luma Ray 3.2 fps and audio are not documented. Whether "Ray3/Ray3.14" exist as API IDs is unverified.
- The full BytePlus Seedance parameter list (seed, `camera_fixed`, watermark flag) could not be read from primary docs.

## Q3. Native audio generation and controls

### Takeaway
Native audio is now standard on the premium models: Veo 3.1 (always on), Omni Flash, Seedance 2.x (with lip-sync), Kling 3.0 (on/off toggle plus voice control), Wan 3.0, MiniMax H3-Max and LTX-2 (open). Luma Ray 3.2 has no documented audio, and Runway Gen-4.5 / Gen-4 Turbo list none. Controls are mostly prompt-based. Kling and Runway's Veo resale are the only places with an explicit on/off switch.

### Cited Findings
- Veo 3.1 (all variants) on the Gemini API: "Audio: Always on". — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- Gemini pricing covers only video with audio (the default). Charges apply only on success, and "an audio processing issue can occasionally prevent generation". — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Omni Flash audio is driven by the prompt (music, SFX, negatives such as "No dialogue"). Voice editing is not supported, but multi-turn voice extension with dialogue works for model-generated videos. Audio in video references is ignored. — [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)
- Runway prices `veo3.1` at 40 credits/s with audio and 20 without, so audio can be toggled through Runway. — [Runway API pricing](https://docs.dev.runwayml.com/guides/pricing/)
- Seedance 2.0 and 2.5 generate native audio "jointly with the picture; no extra charge", with lip-sync: "dialogue in double quotes is voiced and synced". — [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0)
- Kling 3.0 Pro on fal has a "Generate Audio" toggle and three price tiers: audio off, audio on, and audio on with voice control. — [fal Kling v3 Pro](https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video)
- Runway's catalog describes `h3_max` as having "native audio" and `wan3` as having "Native audio". MiniMax's own guide accepts audio as a reference input but does not say whether H3 outputs audio. — [Runway API models](https://docs.dev.runwayml.com/guides/models/); [MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation)
- The legacy Luma API has a separate `add_audio` generation type ("Add audio to a generation by its ID"). — [Luma create generation](https://docs.lumalabs.ai/reference/creategeneration.md); [Luma docs index](https://docs.lumalabs.ai/)
- LTX-2 (open weights) generates "synchronized video and audio within a single model". — [LTX-2 model card](https://huggingface.co/Lightricks/LTX-2)

### Inferences
- HOOKKADR builds the timeline in FFmpeg, so it should treat generated audio as a separate stem: extract it, duck it under the voice-over, or mute it. Veo audio cannot be disabled through the Gemini API, which matters if the app adds its own music or VO.

### Gaps
- No provider documents per-track control (separate dialogue, SFX and music stems).
- Uzbek-language dialogue quality is undocumented everywhere. Omni Flash says "English is fully supported. Other languages are untested" ([Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)).

## Q4. Async pattern, latency, result delivery and retention

### Takeaway
Every provider uses the same create-job, poll-or-webhook, download pattern, but retention windows are short and differ: Veo keeps files for 2 days, Luma presigned URLs last 1 hour, and the MiniMax task list covers 7 days. The backend must download each result to its own storage right away. Webhooks are documented for Luma (legacy) and Kling/fal. Veo and Luma Agents are polling-only in their docs.

### Cited Findings
- **Veo (Gemini API):**
  - predictLongRunning, then poll the operation every 10 s (SDK examples).
  - Latency is "Min: 11 seconds; Max: 6 minutes (during peak hours)".
  - "Videos are stored for 2 days." Referencing a video for extension resets its timer.
  — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- **Gemini Omni Flash:**
  - `interactions.create` is synchronous by default and returns base64 in `output_video.data`. Unary mode is `background=false, store=false, stream=false`.
  - For outputs over 4 MB, use `delivery: "uri"` and poll the file until it is ACTIVE.
  - `GET /v1beta/interactions/{id}` returns base64 even for URI-delivered results.
  - `store=false` means the video "won't be editable in subsequent turns". No retention period is stated.
  — [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)
- **Vertex Veo:** output goes to GCS. Batch inference is not supported; Provisioned Throughput is. — [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate)
- **Runway:**
  - A create call returns a task ID. The SDK's `waitForTaskOutput()` handles polling, and the result is `task.output[0]`. Failures raise `TaskFailedError`.
  - Webhooks are not mentioned.
  — [Runway API getting started](https://docs.dev.runwayml.com/guides/using-the-api/)
- **Luma (legacy):**
  - Poll `GET /dream-machine/v1/generations/{id}`, or pass `callback_url`. Callbacks fire for dreaming, completed and failed, and "the endpoint is expected to be called multiple times for a status".
  - Non-200 responses are retried 3 times; each callback times out after 5 s.
  — [Luma video generation guide](https://docs.lumalabs.ai/docs/video-generation)
- **Luma Agents:**
  - `POST /v1/generations`, then poll `GET /v1/generations/{id}`. Suggested timing: an initial wait of about 30 s and a 10-minute hard timeout.
  - Results come as presigned URLs that "expire after 1 hour". Rate-limit headers are `X-RateLimit-*`.
  — [Luma Agents API](https://docs.agents.lumalabs.ai/); [Luma Agents models guide](https://docs.agents.lumalabs.ai/guides/model/)
- **MiniMax:**
  - `POST /v2/video_generation` returns `task_id`. Poll `GET /v2/query/video_generation/{task_id}` ("recommended polling interval is 10 seconds").
  - On success, the URL is in `content.url`. List Tasks covers the last 7 days, and there is a cancel/delete endpoint.
  — [MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation)
- **OpenAI (historical):** `video.completed` and `video.failed` webhooks; download URLs were valid for 1 hour. — [OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)
- **Kling and fal (3P):** results come back via task ID with polling or webhook. EvoLink says links stay valid for 24 hours. — [Kling search summary: Magnific (3P)](https://docs.magnific.com/api-reference/video/kling-v3/overview); [EvoLink (3P)](https://evolink.ai/blog/how-to-access-kling-ai-api-complete-tutorial)

### Inferences
- The HOOKKADR server needs a job table with provider, external ID, status and an expiry deadline. It should poll with backoff starting at about 10 s (about 30 s for Luma), time out at 10–12 minutes, download to its own bucket immediately (Luma URLs last 1 hour), and then push the result to the device. A webhook receiver would be an optimization only for Luma legacy, Kling and fal.

### Gaps
- Runway output URL lifetime and webhook support are not documented on the pages read.
- Typical latency is not documented for Runway, Luma Ray 3.2, Seedance, Kling or MiniMax.

## Q5. Pricing, rate limits, regional availability (incl. Uzbekistan), commercial rights, watermarking

### Takeaway
Typical cost per second at 720p, with audio where the model has it:
- Veo 3.1 Lite: $0.05. Veo 3.1 Fast: $0.10. Veo 3.1 Standard: $0.40.
- Omni Flash: about $0.10.
- Runway Gen-4 Turbo: $0.05. Gen-4.5: $0.12.
- Kling 3.0 Pro via fal: $0.168.
- MiniMax H3: $0.08 at 768P.
- Seedance 2.0 via fal: about $0.30.

The Gemini API is officially available in Uzbekistan and the rest of Central Asia. Vertex Veo runs in us-central1 only. Google marks output with SynthID (Gemini API) and C2PA (Vertex). Commercial-use and watermark terms for the other providers were not found in primary sources.

### Cited Findings
- **Gemini API Veo 3.1, per second with audio:**

  | Model | 720p | 1080p | 4K |
  |---|---|---|---|
  | `veo-3.1-generate-preview` | $0.40 | $0.40 | $0.60 |
  | `veo-3.1-fast-generate-preview` | $0.10 | $0.12 | $0.30 |
  | `veo-3.1-lite-generate-preview` | $0.05 | $0.08 | — |

  There is no free tier, and charges apply only on success. — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing) (2026-10-13)
- **Gemini Omni Flash:** `gemini-omni-1.1-flash` (GA) and `gemini-omni-flash-preview` cost $1.50 per 1M input tokens and $17.50 per 1M video output tokens. That is "about 5,792 tokens per second of 720p video", or roughly $0.10/s. — [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- **Runway API credits:** $0.01 per credit. Rates per second:

  | Model | Credits/s | USD/s |
  |---|---|---|
  | `gen4.5` | 12 | $0.12 |
  | `gen4_turbo` | 5 | $0.05 |
  | `aleph2` (56-credit minimum) | 28 | $0.28 |
  | `veo3.1`, with / without audio | 40 / 20 | $0.40 / $0.20 |
  | `veo3.1_fast`, with / without audio | 15 / 10 | $0.15 / $0.10 |
  | `seedance2`, 480p/720p | 36 | $0.36 |
  | `seedance2`, 1080p | 40 | $0.40 |
  | `seedance2`, 4K | 150 | $1.50 |
  | `seedance2_fast` | 29 | $0.29 |
  | `seedance2_mini` (64-credit minimum) | 16 | $0.16 |

  — [Runway API pricing](https://docs.dev.runwayml.com/guides/pricing/)
- **MiniMax, billed per second:**
  - `MiniMax-H3`: $0.08/s at 768P, $0.13/s at 2K.
  - `MiniMax-H3-Max`: $0.05/s at 480P, $0.08/s at 768P.
  - H3-Regeneration (768P to 2K): $0.05/s.
  - Legacy Hailuo-2.3 is priced per clip: $0.28 for 768P/6 s, $0.56 for 768P/10 s, $0.49 for 1080P/6 s.
  — [MiniMax pricing](https://platform.minimax.io/docs/guides/pricing-paygo)
- **Kling on fal:** 3.0 Pro costs $0.112/s with audio off, $0.168/s with audio on, and $0.196/s with voice control ("a 5s video with audio on and voice control will cost $0.98"). — [fal Kling v3 Pro](https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video)
- **Kling on fal, conflicting figures:** other fal pages list $0.168–$0.392/s, and $0.224/s (audio off) to $0.336/s (audio on). — [fal Kling 3 page](https://fal.ai/kling-3); [fal AI video generators guide](https://fal.ai/learn/tools/ai-video-generators)
- **Kling official (search snippet):** "0.6 Units ($0.084)/s at 720P for no native audio" for Kling 3.0, with a resource package of "$700 for 5000 units" ($0.14 per unit). — [Kling API video pricing (snippet)](https://kling.ai/document-api/pricing/base/video)
- **Kling 3.0 Turbo, 3P:** ¥0.8/s (about $0.11) at 720p on the official API. — [invideo pricing roundup (3P, 2026-08-06)](https://invideo.io/blog/ai-video-model-pricing)
- **Seedance on fal:** billed as tokens = (h × w × duration × 24)/1024.
  - Seedance 2.0 costs $0.014 per 1K tokens up to 1080p ($0.3034/s at 720p; fast $0.2419/s; $0.682/s at 1080p).
  - Seedance 2.5 costs $0.0214 per 1K tokens (about $0.473/s at 720p).
  — [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0)
- **Seedance on Volcano Engine (3P):** ¥28/M tokens with video input, ¥46/M for text-to-video. — [invideo pricing roundup (3P)](https://invideo.io/blog/ai-video-model-pricing)
- **LTX-2.3 hosted API (3P):** Fast $0.06–0.24/s; Pro $0.08–0.32/s. — [invideo pricing roundup (3P)](https://invideo.io/blog/ai-video-model-pricing)
- **Rate limits:**
  - Vertex Veo 3.1: 50 requests per base model per minute (regional).
  - Gemini API: per-model limits are shown only in AI Studio, and preview models are more restricted.
  - Luma Agents: limits are returned in `X-RateLimit-*` headers.
  — [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate); [Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits); [Luma Agents API](https://docs.agents.lumalabs.ai/)
- **Regions:**
  - "The Gemini API and Google AI Studio are available in" Uzbekistan, Kazakhstan, Kyrgyzstan, Tajikistan and Turkmenistan. — [Gemini available regions](https://ai.google.dev/gemini-api/docs/available-regions) (2026-04-28)
  - Vertex Veo 3.1 runs only in `us-central1`. — [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate)
  - BytePlus Seedance has an ap-southeast-1 endpoint. — [BytePlus model list](https://docs.byteplus.com/api/docs/ModelArk/1330310)
- **Watermarking and provenance:**
  - Gemini API Veo videos "are watermarked with SynthID". — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
  - Omni Flash: "All outputs include SynthID". — [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)
  - Vertex Veo 3.1 lists "Content Credentials (C2PA): Supported". — [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate)
- **Commercial use:** fal says Seedance 2.0 and 2.5 are closed weights "listed for commercial use on fal, subject to fal's terms". — [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0)

### Inferences
- For a cost-sensitive Uzbek consumer app, a reasonable tiering is:
  - Drafts and previews: Veo 3.1 Lite ($0.05/s) or Gen-4 Turbo ($0.05/s).
  - Standard output: Veo 3.1 Fast or Omni Flash (about $0.10/s).
  - Hero shots: Veo 3.1 Standard, Kling 3.0 Pro or Seedance 2.0 ($0.17–0.40/s).

  An 8 s Veo 3.1 Standard clip costs $3.20, and the same clip on Lite costs $0.40.
- Runway's API can act as a single adapter that reaches Veo 3.1, Seedance 2, MiniMax H3, Wan 3 and Omni Flash on one credit system. Prices differ by model. Veo 3.1 with audio costs the same on both ($0.40/s), and Runway also sells a no-audio version for $0.20/s, which the Gemini API does not offer. Seedance 2 at 720p is more expensive on Runway: $0.36/s versus about $0.30/s on fal.

### Gaps
- Not found in primary sources:
  - Commercial-use and IP-ownership terms for Veo, Runway, Luma, Kling, MiniMax and BytePlus.
  - Whether non-Google providers add visible watermarks or C2PA.
  - Availability of Runway, Luma, Kling, MiniMax and BytePlus in Uzbekistan, Central Asian billing or card acceptance, and API rate limits for Kling, Runway and BytePlus.
- Luma Ray 3.2 pricing is linked from its docs but was not read.
- Replicate per-second pricing for `google/veo-3.1` is not listed on the model page.

## Q6. Content restrictions: real people, minors, public figures, uploaded faces

### Takeaway
Uploaded real faces are the main point of friction:
- Veo restricts `personGeneration`: image input allows adults only, and the EU/UK/CH/MENA allow adults only for everything.
- Omni Flash blocks "certain recognizable people", and in the EEA/UK/CH it blocks minors and edits to uploaded video.
- Seedance 2.0 hard-blocks realistic faces in references unless they go through an asset-library or liveness route (3P evidence).
- Sora (now shut down) rejected faces outright.

### Cited Findings
- **Veo 3.1 `personGeneration`:** text-to-video and extension allow `"allow_all"` only. Image-to-video, interpolation and reference images allow `"allow_adult"` only. "In EU, UK, CH, and MENA locations, `allow_adult` is the only allowed `personGeneration` value." Outputs also pass safety filters and memorization checks. — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- **Omni Flash:** uploading and editing images with minors is not supported in the EEA, Switzerland and the UK. Uploading and editing images of "certain recognizable people is not supported". Editing or extending uploaded videos is unavailable in the EEA, CH and UK. — [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)
- **Seedance 2.0:**
  - Reference images with realistic faces are rejected by an upstream content-safety filter.
  - The workaround is to upload through an asset-library API to get an `asset://` ID, with a liveness scan for real people.
  - AI-generated faces can also be blocked.
  — [APIYI Seedance face FAQ (3P reseller)](https://docs.apiyi.com/en/faq/seedance2-asset-face-reference)
- An Adobe community thread from July 2026 confirms the error "reference content can't include real human faces" for Seedance 2.0 and 2.0 Fast. — [Adobe community (3P)](https://community.adobe.com/questions-404/reference-content-can-t-include-real-human-faces-when-using-seedance-2-0-and-seedance-2-0-fast-1631867)
- BytePlus documents a page called "Create portrait videos with Dreamina Seedance models" (title only; the body was not readable). — [BytePlus index](https://docs.byteplus.com/en/docs/ModelArk/1330310?lang=en)
- **Sora (historical):** content had to be suitable for under-18 audiences. Real people, including public figures, could not be generated, and input images with human faces were rejected. — [OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)

### Inferences
- If HOOKKADR users upload selfies or influencer faces for "UGC-style" ads, Veo 3.1 image-to-video with `allow_adult` is the most clearly documented path. Seedance requires the asset or liveness flow. The app should show an honest Uzbek message when a provider rejects a face, and should not retry silently on another provider.

### Gaps
- Runway's moderation page (`/guides/moderation/`) returned 404, so its public-figure threshold and refund-on-moderation policy are unverified.
- No primary-source likeness or minor policies were found for Kling, Luma or MiniMax.

## Q7. Best fit by use case (product commercials, camera moves, 9:16 social, multi-shot consistency)

### Takeaway
The recommendations below are inferred from documented features; no head-to-head quality benchmark was verified.
- Product commercials with a consistent product look: the multi-reference models (Veo 3.1 with up to 3 refs, Seedance 2.x with up to 9 or 30 images, MiniMax H3 with up to 9, Omni Flash with numbered refs).
- Cinematic camera control: Luma (concepts, up to 64 keyframes, HDR/EXR) and Kling 3.0 multi-shot.
- Vertical 9:16: every listed model supports it natively.
- Multi-shot consistency: Kling 3.0 `multi_prompt`, Seedance references, and Omni Flash multi-turn editing.

### Cited Findings
- Veo 3.1 referenceImages (up to 3) require 8 s clips; first+last frame interpolation is supported. — [Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)
- Omni Flash multi-turn editing via `previous_interaction_id`: the model "remembers the video context" and preserves elements the prompt doesn't mention. — [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)
- Seedance 2.5 accepts up to 30 reference images, 10 videos and 10 audio clips, and generates clips up to 30 s. — [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0)
- Kling 3.0 Pro advertises "cinematic visuals, fluid motion … multi-shot support" with per-shot prompts. — [fal Kling v3 Pro](https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video)
- Luma has camera concepts such as `dolly_zoom`, a camera-motion list, Ray 3.2 keyframes "up to 64 anchors", and HDR with ACES EXR export. — [Luma video generation guide](https://docs.lumalabs.ai/docs/video-generation); [Luma Agents models guide](https://docs.agents.lumalabs.ai/guides/model/)
- Runway Aleph 2.0 offers "in-context video editing with keyframe-guided control", useful for restyling or editing existing product footage. — [Runway API models](https://docs.dev.runwayml.com/guides/models/)
- MiniMax H3 offers first/last frame plus 9 reference images, 3 reference videos and 3 reference audio clips, with output at up to 2K. — [MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation)

### Inferences
- Product appearance: generate a clean product still (or use the user's own photo), then use it as the first frame and as a reference image (Veo 3.1 or Seedance). Use the same reference set for every shot of the ad.
- Vertical social: Veo 3.1 9:16 at 1080p or 4K (8 s) and Luma (9:16 at 1080p) are native. Wan TI2V-5B outputs 704×1280, so pad or scale it in FFmpeg.
- Long continuous shots: Veo extension (7 s steps up to 148 s at 720p) or Seedance 2.5 (30 s in one pass). Otherwise, short 4–8 s shots cut together in FFmpeg match how HOOKKADR already works.

### Gaps
- No independent, dated quality leaderboard (for example Artificial Analysis Video Arena, October 2026) was fetched, so quality rankings are not evidence-based here.

## Q8. Open-weight options for self-hosted GPU inference

### Takeaway
- Wan 2.2 (Apache 2.0, July 2025) is still the latest open Wan flagship. Wan 2.5 through 3.0 are API-only (3P evidence).
- HunyuanVideo-1.5 (8.3B, November 2025) runs on about 14 GB VRAM with offloading.
- LTX-2 (19B), with LTX-2.3 newer, is the only open model with native audio. Its community license is reportedly free under $10M annual revenue.
- All of them are below the closed premium APIs on the documented specs: 480–720p native, about 5 s clips, minutes per clip on consumer GPUs.

### Cited Findings
- **Wan 2.2:**
  - Licensed under Apache 2.0, with variants T2V-A14B, I2V-A14B (MoE, 480P/720P) and TI2V-5B (720P at 24 fps, "1280*704 or 704*1280").
  - Runs on "a GPU with at least 24GB VRAM (e.g, RTX 4090 GPU)" and makes "a 5-second 720P video in under 9 minutes on a single consumer-grade GPU".
  - Multi-GPU runs through FSDP + DeepSpeed Ulysses. Released July 28, 2025.
  — [Wan2.2-TI2V-5B model card](https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B)
- Wan 3.0 shipped as an API-only beta in August 2026, with no weights on Hugging Face or GitHub. The highest open version is 2.2. Flagships 2.5, 2.6, 2.7 and 3.0 are closed, and claims of Apache-2.0 Wan 3.0 weights trace back to one social media post. Wan-Animate-2 was released August 7, 2026 under Apache 2.0. — [WaveSpeed blog (3P vendor, August 2026)](https://wavespeed.ai/blog/video-model-access/is-wan-3-0-open-source/); [Atlas Cloud (3P vendor)](https://www.atlascloud.ai/blog/tips/is-wan-3.0-open-source)
- **HunyuanVideo-1.5:**
  - License `tencent-hunyuan-community`. 8.3B parameters, with 480P/720P models plus super-resolution to 1080p, 121 frames by default at 24 fps, and image-to-video.
  - Needs at least "14 GB (with model offloading enabled)". The step-distilled model generates "within 75 seconds" on an RTX 4090.
  - Released November 20, 2025.
  — [HunyuanVideo-1.5 model card](https://huggingface.co/tencent/HunyuanVideo-1.5)
- **LTX-2:**
  - 19B checkpoints in bf16, fp8 and nvfp4, a distilled variant (8 steps, CFG=1), and x2 spatial and temporal upscalers.
  - Native synchronized audio, with T2V, I2V, V2V and A2V modes plus LoRA/IC-LoRA.
  - License `ltx-2-community-license-agreement`. The card says "A newer version of this model is available: Lightricks/LTX-2.3".
  — [LTX-2 model card](https://huggingface.co/Lightricks/LTX-2)
- LTX-2 community license: commercial terms must be negotiated with Lightricks above $10M annual revenue, and competing products need a separate license. Some articles wrongly call it Apache 2.0. — [HF LTX-2.3 discussion #8](https://huggingface.co/Lightricks/LTX-2.3/discussions/8); [canirun.ai license summary (3P)](https://canirun.ai/license/ltx-2-community/)

### Inferences
- For HOOKKADR, self-hosting means at least one 24–80 GB GPU per concurrent job and multi-minute latency per 5 s clip. At this app's likely scale, hosted Wan (Runway `wan3` from $0.05/s) or Veo 3.1 Lite ($0.05/s) is probably cheaper and better than running GPUs. Open weights make sense mainly for a fake or offline dev provider, or for fine-tuned brand LoRAs (LTX-2 IC-LoRA).
- Quality versus closed APIs is inferred from specs only: native 480–720p and about 5 s clips, against 1080p/4K and 8–30 s on the closed models.

### Gaps
- The HunyuanVideo-1.5 territorial exclusions were not read from the license text; earlier Hunyuan licenses excluded the EU, UK and South Korea, which is unverified here.
- LTX-2.3 specs (maximum resolution, fps, duration, VRAM) were not read from a primary source.
- No benchmark comparing open and closed quality was retrieved.
- VRAM needs for Wan 2.2 A14B (MoE) are not on the TI2V card that was read.
