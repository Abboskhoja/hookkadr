# Uzbek (Latin) speech-to-text, text-to-speech, music and audio processing for HOOKKADR (as of 2026-10-14)

All official pages and pricing were accessed on 2026-10-14 unless a different date is given. "Vendor-reported" means the number comes from the provider's own marketing or model card and was not independently checked. HOOKKADR constraints that matter here (from repo `CLAUDE.md`): AI keys stay on the server (`server/`), user-facing text is in Uzbek Latin, and the app must not present a feature as working when it does not.

## 1. Speech-to-text for Uzbek: who supports it, with word-level timestamps, diarization, accuracy, price, on-device

### Takeaway
For word-timed Uzbek subtitles, three hosted options are documented. ElevenLabs Scribe v2 lists Uzbek in its "Good, 10-20% WER" tier, returns word timestamps and diarization, and costs $0.22/h. Azure AI Speech supports `uz-UZ` (labelled "Latin") in fast transcription with word offsets and diarization, at $0.36/h or a $0.10/h promo meter. Google Chirp 3 lists `uz-UZ` only as Preview, its word-timestamp support is unclear, and Uzbek is not in its diarization list. OpenAI, Deepgram and AssemblyAI are weak or unsupported for Uzbek. For self-hosting or on-device use, open Uzbek fine-tunes now report 7-14% WER: Whisper-medium under Apache-2.0, and Parakeet under CC-BY-4.0.

### Cited Findings

**Matrix: hosted STT (all rows checked against official docs unless marked)**

| Provider / model | Uzbek? | Word-level timestamps | Diarization | Accuracy for Uzbek | Price |
|---|---|---|---|---|---|
| ElevenLabs Scribe v2 | Yes, code `uzb`, "Good (>10% to ≤20% WER)" tier | Yes | Yes, up to 32 speakers | Tier 10-20% WER; vendor claims 15.9% FLEURS, 16.6% Common Voice | $0.22/h batch, $0.39/h realtime |
| Azure AI Speech, `uz-UZ` "Uzbek (Latin, Uzbekistan)" | Yes; Fast transcription ✅; Custom Speech plain text only | Yes in fast transcription (`words[]` with `offsetMilliseconds`) | Yes in fast transcription (mono only, 2-35 speakers); no locale limit stated | No published Uzbek WER | Real-time $1.00/h, batch $0.18/h, fast $0.36/h, fast promo meter $0.10/h (effective 2026-09-01) |
| Google Cloud STT v2, Chirp 3 | `uz-UZ` Preview (listed for `eu`) | Docs inconsistent; when enabled, batch limited to 20 min and "some transcription degradation is expected" | Uzbek not in Chirp 3 diarization language list | None published | ~$0.016/min (third-party, unverified) |
| Google Chirp 2 / Chirp | `uz-UZ` in asia-southeast1, europe-west4 | Chirp 2 lists "Word-level confidence" | Not listed | None published | Same caveat |
| Gemini API (audio understanding) | No language list published | No; segment `MM:SS` timestamps only | Yes, by prompting | None published | 32 tokens per second of audio |
| OpenAI `gpt-transcribe` (new recommended), `gpt-4o-(mini-)transcribe`, `gpt-4o-transcribe-diarize`, `whisper-1` | Uzbek not on OpenAI's documented language list (the <50%-WER Whisper list) | Only `whisper-1` (`timestamp_granularities[]`) | Only `gpt-4o-transcribe-diarize` | Not on list, which implies Whisper WER above 50% | gpt-transcribe $0.0045/min; 4o $0.006; 4o-mini $0.003; diarize $0.006; Whisper $0.006 |
| Deepgram (Nova-3, Nova-2, Flux) | No | n/a | n/a | n/a | n/a |
| AssemblyAI | Universal-2 only, "Fair accuracy (>50% WER)"; not Universal-3.5 Pro | Not documented per language | Not documented per language | >50% WER band | — |
| Yandex SpeechKit | `uz-UZ` "Uzbek (Latin script)" | Not stated on models page | Not stated | None published | — |
| Aisha (aisha.group, Uzbek startup) | Yes (uz default, plus en, ru) | API docs: `has_offset` gives "segment offsets", not word-level (marketing claims word-level) | Yes, `has_diarization` (audio ≥15 s) | Vendor claims 90%+ in one place, >95% in another | Not on API page; see /en/pricing |
| Uzbekvoice.ai | Company does Uzbek STT/TTS/LLM | Unknown | Unknown | Unknown | Unknown |
| Gladia | Uzbek page claims realtime + async and Uzbek-Russian code-switching | Product page lists word timestamps | — | — | — |

Sources for the matrix:
- ElevenLabs Scribe v2: Uzbek (`uzb`) in "Good (>10% to ≤20% WER)" tier alongside Tajik, Thai, Welsh; "Precise word-level timestamps"; "Speaker diarization, up to 32 speakers"; keyterm prompting (up to 1000 batch); max 3 GB / 10 h — [ElevenLabs STT docs](https://elevenlabs.io/docs/capabilities/speech-to-text)
- Scribe v2 / v2 Realtime / v2 Medical support "90+ languages"; v2 Realtime has word timestamps but diarization not mentioned — [ElevenLabs models](https://elevenlabs.io/docs/overview/models)
- Vendor claim: 15.9% WER on FLEURS and 16.6% on Common Voice for Uzbek, character-level timestamps — [ElevenLabs Uzbek STT page](https://elevenlabs.io/speech-to-text/uzbek)
- Scribe v2 $0.22/h, Scribe v2 Realtime $0.39/h — [ElevenLabs API pricing](https://elevenlabs.io/pricing/api)
- Azure: `uz-UZ` row "Uzbek (Latin, Uzbekistan)", fast transcription ✅; Custom Speech "Plain text" only; Uzbek not in LLM speech translation or MAI-Transcribe lists — [Azure language support (STT)](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=stt)
- Azure fast transcription: word-level timestamps ✅, `words` array with `offsetMilliseconds`/`durationMilliseconds`; diarization ✅ (mono only, 2-35 speakers); file "less than 5 hours long and less than 500 MB" — [Azure fast transcription](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/fast-transcription-create)
- Azure eastus pay-as-you-go meters: "S1 Speech To Text" $1.00/h; "S1 Speech to Text Batch" $0.18/h (since 2024-05-01); "Fast Transcription Speech To Text" $0.36/h; "Fast Transcription Promo Speech To Text" $0.10/h (effective 2026-09-01); "S1 Neural Text To Speech Characters" $15/1M — [Azure Retail Prices API](https://prices.azure.com/api/retail/prices) (queried 2026-10-14). Free tier is 5 audio hours/month STT and 0.5M characters/month neural TTS — [Azure Speech pricing](https://azure.microsoft.com/en-us/pricing/details/speech/)
- Google: "Uzbek (Uzbekistan)" `uz-UZ` rows for `chirp_3` (eu: punctuation, model adaptation, profanity filter), `chirp_2` (asia-southeast1, europe-west4: punctuation, adaptation, word-level confidence), `chirp` (punctuation). The page has no word-time-offset column, and only the first 100k characters could be read — [Google STT supported languages](https://docs.cloud.google.com/speech-to-text/docs/speech-to-text-supported-languages)
- Chirp 3: `uz-UZ` status "Preview". Word-level timestamps "can be optionally enabled, which some transcription degradation is expected" (Recognize/BatchRecognize only; batch limit drops to 20 min), yet the same page also lists them as unsupported. Diarization is GA, but Uzbek is not in the diarization language list. `auto` language detection is available — [Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3)
- Google pricing is third-party only: $0.016/min standard, falling with volume; dynamic batch about $0.003/min; 60 free min/month — [convertaudiototext.com](https://convertaudiototext.com/blog/google-cloud-speech-to-text-pricing-2026). OpenRouter lists Chirp 3 at $0.016/min with a release date of 2026-05-05 — [OpenRouter](https://openrouter.ai/models/google/chirp-3)
- Gemini audio: timestamps in `MM:SS` for segments; diarization as a use case; "Max length: 9.5 hours of audio per prompt"; "32 tokens per second of audio"; no language list — [Gemini audio understanding](https://ai.google.dev/gemini-api/docs/audio)
- OpenAI: `gpt-transcribe` is "the recommended model for transcribing recorded speech"; "The `timestamp_granularities[]` parameter is only supported for `whisper-1`"; diarization only via `gpt-4o-transcribe-diarize` (`diarized_json`), "isn't supported in Realtime transcription sessions"; "Files can be up to 25 MB"; "Whisper supports 98 languages, but accuracy varies by language" — [OpenAI STT guide](https://developers.openai.com/api/docs/guides/speech-to-text)
- OpenAI's language list (the Whisper list that TTS also follows) does not include Uzbek — [OpenAI TTS guide](https://developers.openai.com/api/docs/guides/text-to-speech)
- OpenAI prices: gpt-transcribe $0.0045/min, gpt-4o-transcribe $0.006/min, gpt-4o-mini-transcribe $0.003/min, diarize $0.006/min, Whisper $0.006/min — [OpenAI pricing](https://developers.openai.com/api/docs/pricing)
- Deepgram: no Uzbek in Nova-3, Nova-2, Flux (10 languages) or legacy tables; the Whisper Cloud list was not shown — [Deepgram models & languages](https://developers.deepgram.com/docs/models-languages-overview)
- AssemblyAI: Uzbek `uz` only on Universal-2, in "Fair accuracy (>50% WER)" group; Universal-3.5 Pro (18 languages) excludes it. With `language_detection`, unsupported features are "silently omitted" — [AssemblyAI supported languages](https://www.assemblyai.com/docs/pre-recorded-audio/supported-languages)
- Yandex SpeechKit: `uz-UZ` "Uzbek (Latin script)"; docs moved from yandex.cloud to aistudio.yandex.ru — [Yandex STT models](https://aistudio.yandex.ru/docs/en/speechkit/stt/models)
- Aisha API, "Last updated: 2026-08-10": `POST /api/v1/stt/post/` (sync) and `/api/v2/stt/post/` (async, max 500 MB); languages uz/en/ru; `has_diarization` (≥15 s audio); `has_offset` returns "segment offsets"; auth `X-Api-Key`; SDKs `aisha-ai` for pip and npm — [Aisha llms-api.txt](https://aisha.group/llms-api.txt)
- Aisha marketing claims word-level timestamps and diarization, plus 90%+ accuracy; a blog claims >95% — [Aisha Uzbek speech recognition](https://aisha.group/en/uzbek-speech-recognition); [Aisha blog](https://aisha.group/en/blog/aisha-stt-ovozni-matnga)
- UzbekVoiceAI is described as developing Uzbek STT, TTS and LLMs; the site body could not be retrieved — [AI Tinkerers talk page](https://aitinkerers.org/talks/rsvp_7WmwgOqtMgg); [uzbekvoice.ai](https://uzbekvoice.ai)
- Gladia Uzbek page advertises realtime/async and Uzbek-Russian code-switching — [Gladia Uzbek](https://www.gladia.io/product/languages/uzbek)

**Open models (self-reported WER; test sets and normalization differ, so numbers are not directly comparable)**
- `navai-uz/whisper-medium-uzbek` (769M, full fine-tune of whisper-medium, Apache-2.0). Trained on 753 h human-transcribed data (Common Voice 22, FLEURS train, USC, UzbekVoice). WER: FLEURS 14.11, CV22 7.69, USC 9.70, FeruzaSpeech 7.41, macro 9.73. Output is "Latin-script Uzbek (uzn_Latn)" with "every apostrophe variant folded to the Uzbek okina (oʻ/gʻ)". Family macro-WER: tiny 18.13, base 15.13, small 11.57 — [model card](https://huggingface.co/navai-uz/whisper-medium-uzbek)
- `navai-uz/whisper-base-uzbek` recommends forcing `language: "uz"`. Its transcripts were normalized with the `uzbek_text_norm` package (Cyrillic→Latin folding, apostrophe folding) — [Friendli model page](https://friendli.ai/models/navai-uz/whisper-base-uzbek)
- `idrock/piyola-v2` (fine-tune of NVIDIA Parakeet-TDT 0.6B, CC-BY-4.0). WER: FLEURS 10.67 (CER 2.78), FeruzaSpeech 6.08, USC 11.86, Omnilingual (noisy/spontaneous) 25.57. Zero-shot base model scored 105.37% WER. "The model does not output Cyrillic Uzbek"; output is lowercase, no punctuation, no digits (vocab a-z, apostrophe, space) — [model card](https://huggingface.co/idrock/piyola-v2)
- Other cards: BuzzASR/uzbek 25.64% FLEURS, 11.84% CV25 — [HF](https://huggingface.co/BuzzASR/uzbek). Abduqayum whisper-medium-callcenter 14.40% FLEURS, 13.37% CV17 — [Friendli](https://friendli.ai/models/Abduqayum/whisper-uzbek-medium-callcenter). rustam1221 large-v3-turbo fine-tune 19.6% FLEURS, with a GigaAM baseline claimed at 6.7% FLEURS — [HF](https://huggingface.co/rustam1221/uzbek-asr-gigaam). rubaistt_v2_medium ~17% WER, half of its training labels pseudo-labelled by Gemini 2.5 Pro — [HF](https://huggingface.co/islomov/rubaistt_v2_medium/blob/main/README.md)
- Most-downloaded "whisper uzbek" repos on the Hugging Face Hub (2026-10-14): navai-uz/whisper-medium-uzbek (2,226), navai-uz/whisper-small-uzbek, hostmepanda/whisper-large-v3-turbo-uzbek-ct2 (CTranslate2), navai-uz/whisper-base-uzbek, Abduqayum/whisper-uzbek-medium-callcenter — [HF API search](https://huggingface.co/api/models?search=whisper%20uzbek&sort=downloads)

**On-device (iOS 16+/Android 30+)**
- whisper.cpp is MIT-licensed and actively maintained (last push 2026-10-12) — [GitHub](https://github.com/ggml-org/whisper.cpp). sherpa-onnx is Apache-2.0 (last push 2026-10-13) — [GitHub](https://github.com/k2-fsa/sherpa-onnx)
- `flutter_whisper_kit` wraps WhisperKit: iOS 16.0+ fully supported, Android "planned for future release" — [pub.dev](https://pub.dev/documentation/flutter_whisper_kit/latest/). `whisper_edge` is built on whisper.cpp with Metal/Accelerate (iOS 16.4+), offline transcription with timestamps — [pub.dev](https://pub.dev/documentation/whisper_edge/0.1.1/). `whisper_cpp_flutter_plus` had its first Android+iOS release on 2026-07-20 and added SPM support in 0.3.0 — [pub.dev changelog](https://pub.dev/packages/whisper_cpp_flutter_plus/versions/0.3.0/changelog)
- WhisperKit offers CoreML/Metal optimization on Apple only; whisper.cpp runs across iOS, Android and desktop with GGML quantization — [Cactus comparison](https://cactuscompute.com/compare/argmax-vs-whisper-cpp)

### Inferences
- **Recommended path for HOOKKADR subtitles: ElevenLabs Scribe v2 first, Azure fast transcription `uz-UZ` as fallback, both called from `server/`.** Scribe is the only hosted option with an official Uzbek accuracy tier (10-20% WER), and it returns word timestamps and diarization at the lowest price ($0.22/h). Azure is Latin-labelled, returns word offsets and diarization, and its $0.10/h promo meter makes it cheap. Chirp 3 is Preview for Uzbek, with doubtful word timestamps and no Uzbek diarization, so treat it as tertiary.
- **Do not offer OpenAI or Whisper-API, Deepgram or AssemblyAI as "Uzbek subtitles."** OpenAI does not list Uzbek. AssemblyAI puts Uzbek in its >50% WER band. Deepgram has no Uzbek. Showing these as Uzbek-capable would break the project's honesty rule.
- Gemini cannot produce word-level timings. It fits a second pass instead: keep Scribe's word timings and use Gemini (or Claude) only to fix spelling and punctuation, then re-map to the existing word slots.
- Self-hosting on the server: `navai-uz/whisper-medium-uzbek` (Apache-2.0, Latin output, punctuated Whisper decoder) is the safest licence-wise. piyola-v2 has better FLEURS WER, but it is CC-BY-4.0, which requires attribution, and its output has no punctuation, case or digits, which is poor for subtitles without a restoration step.
- On-device: a quantized whisper-small or whisper-medium Uzbek fine-tune converted to GGML could run through whisper.cpp on both platforms (iOS WhisperKit wrappers have no Android support). Expect 11-14% WER (small to medium) on clean speech, per the NavAI card. Word timestamps from whisper.cpp are token-based and must be tested.
- Every vendor WER above is self-reported. Before committing, HOOKKADR should run a 30-60 minute internal benchmark on real user-style audio (phone mic, music under speech, Uzbek-Russian code-switching).

### Gaps
- `gpt-transcribe` (new OpenAI model) has no per-language list; no Uzbek WER found.
- Google's official STT pricing page would not load; Chirp 3 prices are from third parties.
- Google's supported-languages page was truncated after 100k characters, so `us`/`global` Uzbek rows were not seen.
- Uzbekvoice.ai products, API, pricing and accuracy could not be retrieved.
- No independent 2026 benchmark compares commercial APIs on the same Uzbek test set.
- Azure gives no Uzbek WER. Whether Azure real-time/batch (not only fast) transcription covers `uz-UZ` was not explicitly confirmed by the table columns read.
- Yandex word-timestamp support and access/payment from Uzbekistan were not verified.
- Speechmatics and Soniox Uzbek support were not found.
- MMS-1B ASR Uzbek (Latin) support and licence were not checked.

## 2. Text-to-speech / Uzbek voiceover and voice-cloning consent

### Takeaway
Natural-sounding Uzbek TTS is documented for these: ElevenLabs Eleven v3 and v4 (Uzbek listed, $0.08/1K chars); Azure (`uz-UZ-MadinaNeural` F, `uz-UZ-SardorNeural` M, Standard tier only, no HD); Yandex (3 female voices); Gemini 3.8 Flash TTS ("Northern Uzbek"); and the local startup Aisha (voice "Gulnoza"). Google Cloud TTS (Chirp 3 HD and Cloud Gemini-TTS) and OpenAI TTS do not list Uzbek. Meta MMS-TTS Uzbek is Cyrillic-only and non-commercial. Voice cloning in Uzbek is effectively limited to ElevenLabs Professional Voice Cloning, which requires the speaker's own verification. Azure personal voice does not support `uz-UZ`.

### Cited Findings

**Matrix: TTS**

| Provider | Uzbek voices | Notes | Price |
|---|---|---|---|
| ElevenLabs Eleven v4 / v4 Turbo / v3 / v3 Conversational | Uzbek (uz) in language lists | Multilingual v2 and Flash v2.5 do not include Uzbek | v3/v4 $0.08/1K chars; Flash/Turbo $0.04 (no Uzbek) |
| Azure AI Speech | `uz-UZ-MadinaNeural` (Female), `uz-UZ-SardorNeural` (Male), type "Standard" | Footnote 3: phonemes, custom lexicon and visemes not supported. No HD or MAI-Voice variant for uz-UZ. | Neural $15/1M chars; HD $22/1M (not available for Uzbek) |
| Yandex SpeechKit | `nigora` F (API v1, v3); `zamira` F (v3: neutral, strict, friendly); `yulduz` F (v3: neutral, strict, friendly, whisper) | No male Uzbek voice listed | — |
| Gemini API TTS | "Northern Uzbek" supported by `gemini-3.8-flash-tts` and `gemini-3.8-flash-lite-tts` | Auto language detection; 3.8 models offer voice design and voice replication | Pricing on separate page |
| Google Cloud TTS (Chirp 3 HD; Cloud Gemini-TTS) | Not listed | Cloud Gemini-TTS GA and Preview lists contain no Uzbek | — |
| OpenAI (`gpt-4o-mini-tts`, `tts-1`, `tts-1-hd`) | Not on language list | "optimized for English" | gpt-4o-mini-tts $12/1M audio tokens; tts-1 $15/1M chars; tts-1-hd $30/1M chars |
| Aisha | One built-in model "Gulnoza" (moods: Neutral, Cheerful, Happy, Sad; speed 0.5-2.0), uz/en/ru | Up to 1000 chars per request with key; custom `voice_id` supported | /en/pricing (not read) |
| Meta MMS-TTS (`facebook/mms-tts-uzb-script_cyrillic`) | Cyrillic input only | CC-BY-NC 4.0 | Free, non-commercial |

Sources:
- ElevenLabs: Eleven v4, v4 Turbo, v3 and v3 Conversational lists include "Uzbek (uz)". Multilingual v2 (29 languages), Flash v2.5 (32) and Turbo v2.5 (31) do not — [ElevenLabs models](https://elevenlabs.io/docs/overview/models). Pricing v4 and v3 $0.08/1K chars, Flash/Turbo $0.04 — [ElevenLabs API pricing](https://elevenlabs.io/pricing/api)
- Azure rows: "`uz-UZ` | Uzbek (Latin, Uzbekistan) | Standard | `uz-UZ-MadinaNeural`^3^ (Female)" and "`uz-UZ-SardorNeural`^3^ (Male)". Footnote 3: "Phonemes, custom lexicon, and visemes aren't supported." `uz-UZ` is absent from the 65-locale personal voice table and the professional voice table. In video translation, `uz-UZ` is "Standard voice source Yes / target Yes; Personal voice source Yes / target No" — [Azure language support (TTS)](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts)
- Azure TTS price: "S1 Neural Text To Speech Characters" $15/1M; "Neural HD Text to Speech Characters" $22/1M; "Text to Speech - Personal Voice Characters" $24/1M — [Azure Retail Prices API](https://prices.azure.com/api/retail/prices) (eastus, queried 2026-10-14)
- Yandex voices `nigora`, `zamira`, `yulduz`, all F — [Yandex TTS voices](https://aistudio.yandex.ru/docs/en/speechkit/tts/voices)
- Gemini TTS: "Northern Uzbek" supported on both Gemini 3.8 TTS models; Flash "supports over 130 languages", Flash-Lite "over 100"; "The TTS models detect the input language automatically"; `gemini-3.1-flash-tts-preview` and `gemini-2.5-pro-preview-tts` single/multi-speaker only — [Gemini speech generation](https://ai.google.dev/gemini-api/docs/speech-generation)
- Google Cloud: Gemini-TTS GA and Preview lists have no Uzbek; voice design and replication are "not available through the Cloud Text-to-Speech API" — [Cloud Gemini-TTS](https://docs.cloud.google.com/text-to-speech/docs/gemini-tts). Chirp 3 HD languages have no `uz-UZ` — [Chirp 3 HD](https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd)
- OpenAI: "The TTS model generally follows the Whisper model in terms of language support"; Uzbek not in list; voices "optimized for English"; custom voices need "a speaker's consent recording and matching audio sample"; usage policies require "a clear disclosure to end users that the TTS voice they are hearing is AI-generated" — [OpenAI TTS guide](https://developers.openai.com/api/docs/guides/text-to-speech). Prices — [OpenAI pricing](https://developers.openai.com/api/docs/pricing)
- Aisha TTS: "currently one built-in model: `Gulnoza`", moods, speed, 1000-char limit, custom voice = "READY custom voice owned by the user"; no consent rules documented — [Aisha llms-api.txt](https://aisha.group/llms-api.txt). Marketing elsewhere says six voices and three emotion modes, which conflicts with the API doc — [Aisha TTS API page](https://aisha.group/en/text-to-speech-api)
- MMS-TTS: "Uzbek (uzb-script_cyrillic)"; "licensed as CC-BY-NC 4.0" — [HF model card](https://huggingface.co/facebook/mms-tts-uzb-script_cyrillic). Community fine-tunes include MuzaffarSharofitdinov/mms-tts-uzbek* and davron112/mms-tts-uzb-cyrl-onnx (ONNX, Cyrillic) — [HF API search](https://huggingface.co/api/models?search=mms-tts-uzb)

**Voice-cloning consent**
- ElevenLabs PVC: "All Professional Voice Clones require a verification process to confirm that the voice belongs to you" (read verification lines through the mic). "Even with their consent, you cannot clone someone else's voice." Available on "Creator plan or above". PVC "supports all languages available in the Eleven v4 model family — 90+ languages." IVC works "in any language supported by Flash v2.5 and Multilingual v2" (Uzbek not among them); cloning in other languages is possible but "We do not recommend this." — [ElevenLabs voice cloning](https://elevenlabs.io/docs/product-guides/voices/voice-cloning)
- Azure personal voice is limited to 65 locales, and `uz-UZ` is not one of them — [Azure language support (TTS)](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts)
- OpenAI custom voice requires a consent recording, and AI-voice disclosure to end users is mandatory — [OpenAI TTS guide](https://developers.openai.com/api/docs/guides/text-to-speech)

### Inferences
- **Recommended for HOOKKADR voiceover:** ElevenLabs v3/v4 as the premium voice, and Azure Madina/Sardor as the low-cost, predictable, Latin-locale default with one male and one female voice. Gemini 3.8 Flash TTS is a candidate to A/B test because it is listed for Northern Uzbek, but there is no published quality data. Native-speaker listening tests (MOS-style) are needed before marketing any of these as "natural".
- Yandex offers only female Uzbek voices. Aisha ("Gulnoza") is local and Uzbek-first, but has one built-in voice and a 1000-character request limit. Either can be a fallback.
- For "use my own voice": only ElevenLabs PVC is a documented Uzbek-capable path, and it requires the speaker's own verification. HOOKKADR should not offer cloning of third-party voices. It should disclose AI voices in the UI (OpenAI requires disclosure, and it is good practice for all providers).
- MMS-TTS cannot be shipped commercially (CC-BY-NC) and would also need Latin→Cyrillic transliteration first.
- Azure Uzbek voices lack phoneme and custom-lexicon support, so mispronounced brand names cannot be fixed by lexicon. Respelling in text is the workaround.

### Gaps
- No published MOS or quality comparison for Uzbek TTS across providers.
- Gemini TTS pricing and SynthID/watermark status of its TTS output were not on the page read.
- No source checked whether Azure word-boundary events work for `uz-UZ`, which would enable karaoke-style captions synced to TTS.
- Aisha pricing and consent policy were not found. CAMB.AI also advertises Uzbek TTS ([CAMB.AI](https://www.camb.ai/text-to-speech/uzbek)) but was not evaluated.
- Google Chirp 3 Instant Custom Voice consent rules were not read (it does not support Uzbek anyway, per the Chirp 3 HD list).

## 3. Uzbek script issues: Latin vs Cyrillic STT output, apostrophes, normalization, and the 2026 alphabet reform

### Takeaway
Current Uzbek Latin writes oʻ/gʻ with U+02BB (ʻ) and the tutuq belgisi with U+02BC (ʼ). In practice U+2018, U+2019 and ASCII `'` are used interchangeably, so subtitles need a normalization step. Providers differ on script: Azure and Yandex label `uz-UZ` as Latin, and open fine-tunes emit Latin. Base Whisper behaviour is not documented, and a Cyrillic→Latin fold is a cheap safety net. **Major new risk:** a law replacing Oʻ→Ö, Gʻ→Ğ, Sh→Ş, Ch→Ç passed the lower house on 2026-07-07 and was reported approved by the Senate on 2026-09-10. No presidential signature had been reported, and if it comes into force in 2027, schoolbooks switch from 2027 to 2031.

### Cited Findings
- Gʻ is encoded as G/g + U+02BB MODIFIER LETTER TURNED COMMA, and the same mark is used for Oʻ. U+0027 and U+2018 substitutions are "very common" because U+02BB is not typeable on Windows Uzbek layouts (as of 2022) — [Wikipedia: Gʻ](https://en.wikipedia.org/wiki/G%CA%BB)
- oʻ/gʻ are "properly rendered" with U+02BB, a claim tagged citation-needed. The tutuq belgisi (ʼ) maps to U+02BC MODIFIER LETTER APOSTROPHE. Most Uzbek websites use U+2018 or U+0027 for oʻ/gʻ and U+2019 or U+0027 for tutuq belgisi — [Wikipedia: Uzbek alphabet](https://en.wikipedia.org/wiki/Uzbek_alphabet)
- glibc's `uz_UZ` locale treats U+02BB, U+2018 and U+0027 as equivalent for collation because U+02BB is hard to type — [glibc uz_UZ locale](https://git.stg.centos.org/source-git/glibc/blob/c8/f/localedata/locales/uz_UZ)
- Cyrillic remains in use alongside Latin. A 2021 plan targeted official documents fully in Latin by 2023-01-01, but Cyrillic "continued to be used alongside Latin in many areas" — [Wikipedia: Uzbek alphabet](https://en.wikipedia.org/wiki/Uzbek_alphabet)
- Script labels: Azure `uz-UZ` = "Uzbek (Latin, Uzbekistan)" — [Azure](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=stt). Yandex `uz-UZ` = "Uzbek (Latin script)" — [Yandex](https://aistudio.yandex.ru/docs/en/speechkit/stt/models). NavAI Whisper outputs "Latin-script Uzbek (uzn_Latn)" with apostrophes folded to okina — [HF](https://huggingface.co/navai-uz/whisper-medium-uzbek). piyola-v2 "does not output Cyrillic Uzbek" — [HF](https://huggingface.co/idrock/piyola-v2). MMS-TTS Uzbek takes Cyrillic input — [HF](https://huggingface.co/facebook/mms-tts-uzb-script_cyrillic)
- The NavAI training pipeline uses an `uzbek_text_norm` package with "Cyrillic→Latin folding, spelled-out numbers/ordinals, Latin apostrophe folding (oʻ/gʻ)" — [Friendli: navai-uz/whisper-base-uzbek](https://friendli.ai/models/navai-uz/whisper-base-uzbek)
- Published Uzbek Cyrillic→Latin transliteration reaches character-level micro-F1 0.9992 — [Uzbek Cyrillic-Latin-Cyrillic Machine Transliteration](https://paperswithcode.com/paper/uzbek-cyrillic-latin-cyrillic-machine)
- **Reform status:**
  - The Legislative Chamber passed the alphabet bill on 2026-07-07: "28 letters and one apostrophe" replacing 26 letters + 3 digraphs — [Kun.uz](https://kun.uz/en/news/2026/07/07/parliaments-lower-house-passes-bill-to-revise-uzbek-alphabet-848eb2)
  - The Senate approved on 2026-09-10 (article dated 2026-09-11): Oʻ→Ö, Gʻ→Ğ, Sh→Ş, Ch→Ç; "Ng" dropped as a unit; sent to the president. "If the law comes into force in 2027, we will print first-grade textbooks in the new alphabet"; "By 2031, all textbooks..."; old documents remain valid — [Times of Central Asia](https://timesca.com/uzbekistan-latin-alphabet-changes-senate/)
  - Conflicting: Zamin.uz says it could not confirm the Senate approval in official sources — [Zamin.uz](https://zamin.uz/en/uzbekistan/220835-o-va-g-endi-boshqacha-yoziladimi-senat-alifbo-islohotiga-oid-qonunni-maqulladi.html). Wikipedia now also reports the Senate approval on 2026-09-10 — [Wikipedia: Uzbek alphabet](https://en.wikipedia.org/wiki/Uzbek_alphabet)

### Inferences
- **Normalization advice for HOOKKADR subtitles** (implement as one server or shared Dart function with tests):
  1. NFC-normalize the text.
  2. If the text contains Cyrillic letters (U+0400-U+04FF), transliterate Cyrillic→Latin, taking care with ў→oʻ, ғ→gʻ, қ→q, ҳ→h, ш→sh, ч→ch, е/ё/ю/я context rules.
  3. After `o`/`g` (any case), map U+0027, U+2018, U+2019, U+02BC, U+0060 (backtick) and U+00B4 to U+02BB.
  4. Elsewhere, between letters, map those characters to U+02BC (tutuq belgisi).
  5. Make sure the subtitle font has glyphs for U+02BB and U+02BC, since many fonts lack them. If the chosen font lacks them, fall back to U+2018/U+2019 for display only and keep U+02BB in stored data.
  6. Search, matching and AI prompts should compare on a folded form where all apostrophe variants are equal (as glibc does).
- Store transcripts in a script-neutral internal form (current Latin with U+02BB), and design an optional "yangi alifbo" (Ö/Ğ/Ş/Ç) output switch. If the law takes effect in 2027, users will start asking for it. Do not switch the default until official publication.
- Base Whisper (OpenAI API or vanilla large-v3) may emit Cyrillic or mixed script. This is plausible but not documented, so always run the Cyrillic check above.

### Gaps
- No official Uzbek government standard specifying Unicode code points was found. The U+02BB claim on Wikipedia is tagged citation-needed.
- There is no confirmation of presidential signature or official publication of the 2026 alphabet law as of 2026-10-14.
- No source documents which script ElevenLabs Scribe, Google Chirp or Gemini emit for Uzbek, or which apostrophe character they use. This must be tested empirically.

## 4. Background music: AI generation APIs with commercial rights, royalty-free libraries, beat detection, copyright risk

### Takeaway
The safest API options are Eleven Music (commercial use on Starter+ plans, $0.15/min, 3 s-5 min, instrumental option, label-cleared per ElevenLabs) and Google Lyria via the Gemini API: 30 s clips or full songs, SynthID-watermarked, artist/lyric requests filtered, but commercial terms are not stated on the docs page. Stable Audio is commercially usable under the Community License only below $1M revenue. Suno has no official self-serve API and is moving to licensed models with download caps after the November 2025 WMG settlement. Udio became a "walled garden" after its UMG settlement. Neither is a safe in-app API. For beat detection, librosa (ISC) is licence-safe for the server; aubio (GPL-3.0), essentia (AGPL-3.0) and madmom models carry copyleft or unclear licences.

### Cited Findings
- **Eleven Music:**
  - "Created in collaboration with labels, publishers, and artists" and "cleared for nearly all commercial uses"; model `music_v2_5`; tracks 3 s to 5 min; vocals or instrumental-only; Finetunes only on user-owned tracks screened for copyright — [ElevenLabs Music docs](https://elevenlabs.io/docs/capabilities/music)
  - $0.15/min; "Commercial use licensing on Starter+ plans" — [ElevenLabs API pricing](https://elevenlabs.io/pricing/api)
- **Google Lyria (Gemini API):**
  - `lyria-3-clip-preview` "always generates a 30-second clip" (MP3); `lyria-3.5` makes full songs of "A couple of minutes", MP3 or WAV; 44.1 kHz stereo; "All generated audio includes a SynthID audio watermark"; prompts requesting "specific artist voices or the generation of copyrighted lyrics" are filtered; instrumental by prompting "Instrumental only, no vocals"; no commercial-rights statement on page — [Gemini music generation](https://ai.google.dev/gemini-api/docs/music-generation)
  - Vertex lists `lyria-002` as GA for instrumental music, per search snippet; the page body was not readable — [Vertex Lyria](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-reference/lyria-music-generation)
  - Third-party price table: $0.04 per 30 s clip, $0.08 per full song (unverified) — [CometAPI](https://www.cometapi.com/fr/ai-music-api-pricing/)
- **Stable Audio:**
  - Outputs are owned under the Community License, and businesses under $1M revenue can use them commercially for free — [Stability explainer](https://stability.ai/explainers/stable-audio-vs-competitors-licensing-export-rights-and-self-hosting-compared)
  - Stable Audio 3.0 released (May 2026); above $1M annual revenue an Enterprise license is needed, which includes indemnification — [Digital Music News](https://www.digitalmusicnews.com/2026/05/21/stability-ai-3-0-release/)
  - API providers are listed in the Enterprise tier — [Stability membership](https://stability.ai/membership)
  - An older review site claims free-tier output is non-commercial, which conflicts with Stability's own framing — [listir.is](https://listir.is/tools/stable-audio)
- **Suno:**
  - No publicly available self-serve developer API with formal docs; enterprise access is sales-led (secondary) — [Sonilo guide](https://sonilo.com/blog/guides/official-suno-api-saas-builders-2026)
  - WMG settlement (Nov 2025): Suno to launch licensed models in 2026, retire current ones, require a paid account to download, and impose monthly download caps — [Billboard](https://billboard.com/pro/suno-warner-music-sign-ai-licensing-deal-settle-lawsuit/); [Music Business Worldwide](https://www.musicbusinessworldwide.com/warner-music-group-settles-with-suno-strikes-first-of-its-kind-deal-with-ai-song-generator/)
  - GEMA and Koda claims continue (secondary) — [Campos Thomaz](https://camposthomaz.com/en/conhecimento-ct/warner-music-ends-u-s-lawsuit-and-reaches-deal-with-suno-for-licensed-ai-models-starting-in-2026/)
- **Udio:** after the UMG settlement it moved to a "walled garden" where creations stay in-app, and sources disagree on whether downloads are fully disabled — [Sonilo: Udio licensing](https://sonilo.com/blog/comparisons/udio-v4-warner-music-licensing-explained); [Dubspot](https://blog.dubspot.com/ai-music-licensing-explained-2026)
- **Other AI music APIs:** Loudly claims commercial clearance and indemnification on all plans (vendor claim) — [Loudly](https://www.loudly.com/?p=6808)
- **Beat detection licences** (GitHub API, 2026-10-14):
  - librosa: ISC — [GitHub](https://github.com/librosa/librosa)
  - aubio: GPL-3.0 — [GitHub](https://github.com/aubio/aubio)
  - essentia: AGPL-3.0 — [GitHub](https://github.com/MTG/essentia)
  - madmom: no SPDX licence detected; the code is BSD "unless indicated otherwise" and model/data files have a separate licence — [GitHub](https://github.com/CPJKU/madmom); [madmom paper](https://arxiv.org/pdf/1605.07008)

### Inferences
- **Recommended for HOOKKADR:** generate background beds server-side with Eleven Music (instrumental, shortest length that fits the clip) or Lyria 3 Clip (30 s, watermarked). Record provider, model, prompt, timestamp and plan per generated track in the `EditPlan`/project metadata as provenance, in case a platform Content ID dispute arises. Default to instrumental-only, because vocals add lyric/likeness risk and clash with Uzbek voiceover.
- Do not integrate unofficial "Suno API" wrappers. There is no official self-serve API, and terms and downloads are tied to paid consumer accounts, which is a ToS and licensing risk. Udio is not usable for export workflows.
- Stable Audio is fine only while HOOKKADR's company revenue is under $1M. Plan for an Enterprise licence beyond that.
- Never let users pick "popular song" tracks from streaming catalogs. Spotify and Apple Music APIs are for playback, not sync licensing (search summary). Copyrighted tracks get Instagram, TikTok and YouTube videos muted or claimed.
- Beat detection for cut-to-beat editing: run librosa (ISC) on the server, or a simple onset/energy detector in Dart or native code on-device. Avoid shipping aubio or essentia inside the app binary unless HOOKKADR accepts GPL/AGPL obligations or buys a commercial essentia licence.
- "Royalty-free" stock libraries often exclude redistribution inside an app and use by end users, so read terms for in-app sync, not just the price.

### Gaps
- Epidemic Sound, Artlist, Pixabay and Jamendo API availability and in-app sync terms were not verified.
- Google Lyria commercial-use and indemnity terms were not found on the docs page, and official Lyria pricing was not read.
- The official Stability API terms text was not read; only Stability's explainer and secondary reports were.
- Whether Suno's licensed models launched by October 2026 is unconfirmed.
- madmom model licence specifics were not retrieved.

## 5. Audio processing: loudness targets, FFmpeg loudnorm, noise reduction (RNNoise/arnndn, DeepFilterNet), ducking

### Takeaway
Use FFmpeg's EBU R128 `loudnorm` in two-pass linear mode, targeting about -14 LUFS integrated with a -1 to -1.5 dBTP true-peak ceiling. These are widely cited for YouTube, TikTok and Reels, but no official platform spec was found, and FFmpeg's own defaults are -24 LUFS / -2 dBTP. Set the output sample rate explicitly, because loudnorm upsamples to 192 kHz. For voice cleanup, FFmpeg offers `afftdn` (built in) and `arnndn` (RNNoise, needs a model file). DeepFilterNet (MIT/Apache, 48 kHz) is stronger but has been inactive since 2024. Ducking music under voice is FFmpeg `sidechaincompress`.

### Cited Findings
- `loudnorm`: "EBU R128 loudness normalization. Includes both dynamic and linear normalization modes. Support for both single pass (livestreams, files) and double pass (files) modes"; "In dynamic mode, to accurately detect true peaks, the audio stream will be upsampled to 192 kHz. Use the -ar option or aresample filter to explicitly set an output sample rate." Defaults: I = -24.0 (range -70 to -5), LRA = 7.0, TP = -2.0. `linear` requires `measured_I/LRA/TP/thresh`, and reverts to dynamic if target LRA < source LRA or the TP would be exceeded. `print_format=json` for pass 1 stats — [FFmpeg filters: loudnorm](https://ffmpeg.org/ffmpeg-filters.html)
- `arnndn`: "Reduce noise from speech using Recurrent Neural Networks"; option `model, m` "is always required"; `mix` from -1 to 1 (default 1) — [FFmpeg filters: arnndn](https://ffmpeg.org/ffmpeg-filters.html). RNNoise itself is BSD-3-Clause — [xiph/rnnoise](https://github.com/xiph/rnnoise). The commonly used model collection has no declared licence on GitHub (last push 2018) — [GregorR/rnnoise-models](https://github.com/GregorR/rnnoise-models)
- `afftdn`: "Denoise audio samples with FFT"; `nr` default 12 dB (0.01-97); `nf` default -50 dB; can learn a noise profile from a segment (`sn`) — [FFmpeg filters](https://ffmpeg.org/ffmpeg-filters.html)
- DeepFilterNet: dual MIT / Apache-2.0; "Currently, only wav files with a sampling rate of 48kHz are supported" (CLI); real-time version and LADSPA plugin; Rust `libDF`, Python `deepfilternet` — [GitHub README](https://github.com/Rikorose/DeepFilterNet). Last repo push 2024-10-17 — [GitHub API](https://api.github.com/repos/Rikorose/DeepFilterNet)
- `sidechaincompress`: compresses the first input based on the second input's level (ducking). Defaults: threshold 0.125, ratio 2 (1-20), attack 20 ms, release 250 ms, knee 2.82843, detection rms. Example: `ffmpeg -i main.flac -i sidechain.flac -filter_complex "[1:a]asplit=2[sc][mix];[0:a][sc]sidechaincompress[compr];[compr][mix]amerge"` — [FFmpeg filters: sidechaincompress](https://ffmpeg.org/ffmpeg-filters.html)
- Social-video loudness targets: -14 LUFS integrated, -1 dBTP, LRA 11 in a two-pass loudnorm (secondary, describing an open-source video tool) — [instagit: video-use loudness targets](https://instagit.com/browser-use/video-use/social-media-loudness-normalization-targets/). Another workflow uses -14 LUFS with -1.5 dBTP — [CNAPS Studio audio finish](https://cnapsstudio.notion.site/Tool-Video-Editing-Audio-Finish-3aaf00afbadf805a931fdea750df9a44)

### Inferences
- **Suggested HOOKKADR render chain** (in `lib/features/render/render_plan.dart`, FFmpeg):
  1. Voice: `highpass=f=80` → `afftdn=nr=10` or `arnndn=m=<bundled .rnnn>` (only after confirming the model licence) → light compression.
  2. Music bed pre-attenuated by about -18 to -20 dB relative to voice → `sidechaincompress` keyed by voice (e.g., threshold ≈0.05, ratio 6-8, attack 5-20 ms, release 250-400 ms) → `amix`.
  3. Master: `loudnorm` pass 1 with `print_format=json`, then pass 2 with `linear=true`, `I=-14:TP=-1.5:LRA=11` and measured values, then `-ar 48000`.
  Parameter values are starting points, not sourced standards. Tune them by ear.
- DeepFilterNet is the best-quality option of those found, but it is server-side only. It is a 48 kHz Rust/Python stack, unmaintained since 2024, with no documented mobile build. On-device, keep FFmpeg's `afftdn` or `arnndn`, both available in ffmpeg-kit-style builds if those filters are compiled in. Verify which filters the app's FFmpeg build includes.
- Expose a single "Ovozni tozalash" toggle and a "Musiqa ovozi" slider instead of raw parameters. Measure integrated LUFS after export and show it only if it is real, per the honesty rule.

### Gaps
- No official YouTube, TikTok or Instagram loudness specification was retrieved; the -14 LUFS figure comes from secondary sources.
- The licence of RNNoise model files for `arnndn` is undeclared, so check before bundling.
- Whether HOOKKADR's current FFmpeg mobile build includes `arnndn`, `afftdn`, `loudnorm` and `sidechaincompress` was not checked in this research. That is repository work, not web research.
- No 2026 benchmark comparing DeepFilterNet, RNNoise and commercial APIs (e.g., ElevenLabs voice isolator) on Uzbek speech was found.
