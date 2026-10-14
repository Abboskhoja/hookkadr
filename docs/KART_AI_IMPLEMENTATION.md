# KART AI — executable foundation and next contracts

Status: 2026-10-14. This document reconciles both supplied KART briefs with the
existing HOOKKADR code. It records a first working slice and explicitly marks
unimplemented research and production infrastructure. It does not declare all
28 professions or ten proposed models complete.

## First working slice

In a project's editor, open KART AI and use “Reklama storyboardini tuz” or
“Menga 30 soniyalik premium avtomobil reklamasi yarat”.

1. `KadrDirector` recognizes the production request and measures attached video.
2. `KartProduction` compiles a deterministic structured brief and storyboard.
   Camera, lens and light directions are proposals, not claims that footage was
   understood or generated. Subjects come from the request or project title.
3. Available source ranges become a real `EditPlan`; grade, motion, captions and
   supplied-music fades are executable renderer parameters. Without footage,
   the output is explicitly an unfilled storyboard. Insufficient duration is
   measured and reported rather than filled with invented footage.
4. Every stage reports `verified`, `planned` or `blocked` with an artifact-specific
   description. Plan validation and deterministic QC produce measurable evidence.
5. The editor persists the resulting timeline through its existing undo/history
   path. Expand “Storyboard” to review shot directions and copy its JSON. A plan
   signature identifies stale storyboard evidence after manual edits.
6. Export runs the existing FFmpeg engine, then probes the actual MP4 for video,
   dimensions, duration and FPS. Only verified output returns to the caller.
7. “Sifatni tekshir” also runs the bundled original scene-quality model on sampled
   decoded frames. Scores refer to technical defects in those samples only.

The initial creative planner is deterministic, not an LLM or an original trained
creative model. This slice makes no image/video-generation calls. Existing
provider adapters are separate and were not live-tested or extended here.
No GPU infrastructure, public service or paid job was provisioned.

## Contracts and evidence

`kart.production/1` is an additive document stored in `plan.production`:

| Field | Contract |
|---|---|
| `brief` | subject, requested 5–120-second duration, aspect ratio, style |
| `storyboard[]` | shotId, timeline interval, purpose, optional sourceClipId, proposed composition/lens/light/movement, unexecuted generation instruction |
| `evidence[]` | executable skill identifier, state, precise human-readable result |
| `metrics` | requested/planned duration, shortfall, source coverage, shot count, maximum caption reading speed, QC problem count |
| `planSignature` | signature of the producing EditPlan excluding this document; stale after plan edits |
| `mediaGenerated`, `renderVerified` | false for this planning artifact; never changed merely because planning succeeded |

The existing `EditPlan` v1 remains canonical; the second brief's unrelated JSON
example is not silently substituted. Shots must be in contiguous timeline order;
numeric values must be finite; FPS must be an allowed integer. Raw shell commands
are never accepted from a model. `RenderMeasurements` is populated from FFprobe,
not inferred from the prompt. Stored project duration/FPS remain the requested
values after tolerance-based output verification, rather than exact probe metadata.

Failure behavior: no media → unfilled storyboard; analyzer failure → explicitly
excluded source; insufficient usable footage → shortfall and blocked final-output
stage; invalid plan → reject and preserve current project; encoder/probe failure →
no successful export record. Missing model or failed decode → no invented score.
The general editor still permits explicitly labelled storyboard-card previews;
those previews are not completed generated scenes.
Command evidence is also transactional: no-op edits do not create success
claims, and a plan-validation rollback removes the failed operation's success
messages along with the plan change.

## Professional capability contracts

“Working” below is bounded to the stated operation. “Planned” identifies future
contracts, not enabled tools or pretend agents. A profession may share an
implementation with another profession; it is the input/output operation that
must be testable, not the role name.

| # / profession | Input → output | Mechanism and current scope | Quality / failure / test evidence |
|---|---|---|---|
| 1 Film director | brief → ordered shot list | Working: `KartProduction` narrative template | timeline coverage, shot IDs; absent media disclosed; `kart_production_test` |
| 2 Cinematographer | shot purpose → capture instructions; style → motion | Working: proposed composition/lens/light; actual `slowZoom`/`punchIn` filters | proposal vs rendered motion separated; graph tests and simulator |
| 3 Screenwriter | subject/duration → timed hook/detail/demo/ending plan | Working: deterministic short-form template | no freeform semantic understanding; bounded duration tests |
| 4 Storyboard artist | shot list → structured storyboard | Working: JSON and editor view; visual thumbnail generation planned | every shot linked by ID; missing sources visible; production tests |
| 5 Video editor | measured scene/silence ranges → EditPlan | Working: `AutoEditor`, `PlanOps` | bounded source ranges, no invented duration, undo; plan/editor tests |
| 6 Motion designer | motion enum/caption → pixel operation | Working: camera-style zoom and static captions; kinetic type/logo animation planned | renderer filters and actual MP4; unsupported animation must remain unavailable |
| 7 VFX supervisor | masks/track points → composite layers | Planned: versioned masks with alpha and timestamps | alpha-edge IoU, tracking error, missing masks; future fixture tests |
| 8 Colorist | named look → bounded grade → pixels | Working: `ColorGrade` plus lutyuv/hue/colorbalance | finite/range validation and actual render; exposure/white-balance estimation planned |
| 9 Sound designer | supplied music + clip audio → mix parameters | Working: gain/fades/ducking; generative sound and measured loudness mastering planned | no music means no generated audio claim; renderer tests |
| 10 Music editor | waveform → beats → timeline snaps | Existing `BeatDetector`/`PlanOps.snapToBeats` | snap distance and duration constraints; not a trained audio-intelligence model |
| 11 Graphic designer | design brief/assets → layered poster | Planned: layout contract and deterministic text/logo composition | safe-area/text-overflow/pixel export checks; no enabled poster workflow here |
| 12 Product photographer | reference/mask/background → composited image | Planned: original product layer + generated background | mask alignment and reference-region comparison; generative fidelity not guaranteed |
| 13 Advertising director | subject/format → advertising structure | Working: deterministic local template | no unprovided benefit claims; relevance testing requires labelled briefs |
| 14 Copywriter | subject/CTA → timed captions | Working: short claim-free opening/CTA | reading speed, overlap and duration; production/QC tests |
| 15 Social strategist | ratio/duration → constrained output plan | Working: format and pacing controls; campaign analytics planned | output ratio/length verified; no engagement prediction |
| 16 Hook specialist | topic → hook variants/opening motion | Existing template `HookEngine`; trained ranker planned | distinct variants and readable captions; no CTR guarantee |
| 17 Multimodal researcher | versioned multimodal samples → evaluation report | Partial: reproducible image-quality experiment only | held-out source split/hash; text/audio/video-semantic benchmarks planned |
| 18 Image research engineer | prompt/reference → generated image | Existing provider adapter code; own adapted model planned | checkpoint/licence/revision, reference tests; no local generation executed here |
| 19 Video research engineer | prompt/keyframes → generated clip | Existing provider adapter code; own GPU model planned | temporal and duration checks, hardware benchmark; no video diffusion executed here |
| 20 Vision engineer | sampled RGB frames → defect probabilities | Working: original scene-quality MLP + Dart/Python inference | numerical parity, incompatible-model rejection; vision tests |
| 21 ML engineer | dataset/config → checkpoints/eval/selected artifact | Working: PyTorch training + promotion gate | held-out AUC/F1/Spearman, baseline and hashes; Python tests and recorded run |
| 22 Audio AI engineer | audio → word-timed Uzbek transcript/voice | Planned: provider/model adapter and language evaluation | Uzbek WER/CER, speaker/time alignment, MOS; silence detection is not ASR |
| 23 Systems architect | request → concrete stages → evidence | Working: local Director + production compiler; distributed jobs planned | explicit success/failure boundaries; director tests |
| 24 Video-engine engineer | validated plan/media → verified MP4 | Working: FFmpeg device engine + FFprobe gate | dimensions, video/container duration, FPS; render verification and simulator tests |
| 25 Flutter engineer | project/commands → editable history + results | Working: editor integration and bundled inference | widget tests, undo path; actual Android hardware verification still required |
| 26 MLOps engineer | candidate/eval → promote/rollback | Working: local registry; GPU scheduling/autoscaling planned | immutable released versions, nonregression gate; deployment not claimed |
| 27 UI/UX designer | stages/storyboard/QC → reviewable mobile UI | Working: editor panel, expandable storyboard, JSON copy | stale-plan notice and blocked states; full image/video studios remain separate work |
| 28 Quality/safety engineer | plan/artifact/model → measured findings | Working: deterministic QC, numeric validation, export and model gates | missing assets and invalid results fail; robust content moderation/abuse tooling planned |

## Ten KART model directions

| Requested component | Classification now | Trainable target / data / evaluation needed |
|---|---|---|
| Creative Planner | Working deterministic brief compiler | Adapt open-weight instruction model on licensed brief→validated-plan pairs; project-disjoint split, schema pass rate, human brief adherence |
| Shot Ranker | Existing deterministic scene/silence selection | Original pairwise ranker on consented editor preferences with prompt/context; source/creator-disjoint NDCG@k and pairwise accuracy |
| Hook Ranker | Existing deterministic text templates, no trained engagement score | Original pairwise ranker on randomized/comparable openings; CTR alone is confounded by audience/platform/exposure |
| Edit Decision Model | Working deterministic timeline compiler | Adapted open-weight planner or original sequence model on licensed NLE decisions; executable-plan rate, human edit preference, footage coverage |
| Video Quality Evaluator | **Original trained technical-frame MLP v1.0.0** | Current controlled-degradation labels; expand with human-rated real videos, codec/HDR/flicker fixtures; source-disjoint metrics |
| Composition Evaluator | Planned | Adapted open-weight vision embeddings + original supervised head; labelled composition pairs and human agreement |
| Storytelling Intelligence | Planned | Adapted text/video model with consented narrative annotations; ordering/coherence/brief-adherence evaluation |
| Scene Consistency Evaluator | Planned deterministic and learned combination | Optical-flow/embedding comparisons calibrated on annotated identity/temporal changes; false alarms on legitimate cuts |
| Product Fidelity Evaluator | Planned deterministic reference-region comparisons plus adapted vision features | Registered/masked references; colour, geometry, logo/text preservation; labelled defect recall, not generic aesthetic similarity |
| Audio Intelligence | Existing deterministic silence/beat tools; trainable parts planned | Adapted speech models on consented Uzbek audio; language/speaker-disjoint WER/CER, clipping/loudness checks |

Only the technical-frame-quality model has been trained in this milestone.
Its data, best/last checkpoints, inference artifact and evaluation exist. The
other rows are explicit development directions, not fictitious checkpoints.
Local training reproduction and limitations are in [ai/README.md](../ai/README.md).

## Corrections to the supplied executive summary

The supplied summary is a proposal, not a verified dependency lock or completed
roadmap. Its future dates marked “done”, sample script names and cost estimates
are not implementation evidence. Specific corrections checked against primary
sources on 2026-10-14:

- SDXL is a separate model family from SD3. SDXL base 1.0's published licence is
  CreativeML Open RAIL++-M; do not generalize one family's licence to another.
  [Official SDXL model card](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0).
- HunyuanVideo's published licence is Tencent Hunyuan Community License, with
  territory and other conditions; “Apache 2.0?” is not a valid deployment decision.
  [Official licence](https://github.com/Tencent-Hunyuan/HunyuanVideo/blob/main/LICENSE.txt).
- AudioCraft code is MIT; its released MusicGen model weights are CC-BY-NC 4.0.
  Code and weight licences are separate. [Official repository](https://github.com/facebookresearch/audiocraft#license).
- LAION supplies URL/metadata indexes, not a blanket CC0 licence for linked
  images. The current local experiment uses its own retained source manifest.
  [LAION FAQ](https://laion.ai/faq/).
- LTX-2 has an official inference/trainer repository; the summary's “pending
  January 2026” statement is obsolete. Each chosen checkpoint still needs its
  own revision, licence and measured hardware profile.
  [Official repository](https://github.com/Lightricks/LTX-2).
- Wan2.1-T2V-1.3B is a specific text-to-video checkpoint; its inference memory
  estimate cannot be used as a training-memory estimate or a guarantee of I2V
  support. [Official checkpoint card](https://huggingface.co/Wan-AI/Wan2.1-T2V-1.3B).

No unverified dollar totals, “world-class” benchmarks, universal commercial-use
claims, or cross-device binary frame-checksum guarantees are adopted here.
The proposal's budget table also contains arithmetic errors: using its own
assumed rates, 4 × $12/hour × 24 × 7 is $8,064/week, and 8 × $3.50/hour × 24 ×
30 is $20,160 per 30-day month. These are arithmetic corrections, not current
provider quotes.

## Next release gates

1. Calibrate frame quality on real, consented Uzbek/customer footage before
   using it to delete/reorder shots automatically.
2. Add an authenticated asynchronous generation-job contract, persistent asset
   storage, cancellation/idempotency and explicit costs; benchmark one exact
   image/video checkpoint before selecting hardware or buying cloud capacity.
3. Add reference-preserving product composition and real storyboard thumbnails.
4. Evaluate Uzbek word-timed speech and audio mastering with measured outputs.
5. Collect licensed editing preferences for the first original shot/hook ranker.
6. Verify Android devices, long exports, thermal/memory limits and preview/export
   frame tolerances before claiming mobile production readiness.
