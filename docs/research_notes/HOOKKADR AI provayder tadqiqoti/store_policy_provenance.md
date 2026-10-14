# Store, legal and provenance requirements for HOOKKADR (consumer AI image/video app) — as of 14 October 2026

Scope: HOOKKADR is a Flutter iOS/Android AI video studio. Most users are in Uzbekistan, but it is published worldwide on the App Store and Google Play. A backend proxies the AI providers, and the app sells credits for AI usage.

Dating convention: every source was accessed on 2026-10-14. A page's own date is given when the page shows one. **[OLDER]** marks information from before 2026 that is still the latest found. **[SECONDARY]** marks claims that come from news, blogs or aggregators rather than the official text. **[LAWYER]** marks points that need confirmation by counsel. These notes are not legal advice.

---

## 1. Google Play: AI-Generated Content policy, User Data / Data safety, deepfakes, payments for credits, 2025–2026 updates

### Takeaway
HOOKKADR is clearly in scope of Play's AI-Generated Content policy, since it generates images and video and may create video or voice of real people. The policy requires an **in-app report/flag control for offensive AI output that works without leaving the app**. It also requires prevention of restricted content: NCII/"nudify" output, scam deepfakes of real people, deceptive election content, CSAE and similar. Google's August 2026 blog adds that reviewers must get **full, un-paywalled, non-geo-fenced access** to the AI features, plus documentation of safety testing. Credits are virtual currency and must go through Play Billing, apart from the regional alternative-billing programs.

### Cited Findings
- **Scope.** The AI-Generated Content policy covers "text-to-image, voice-to-image, and image-to-image apps that use AI to generate images" and "apps that create voice or video recordings of real-life individuals using AI". It excludes apps that only host AI content (those fall under the UGC policy), apps that only summarize, and productivity apps that use AI to improve an existing feature. Page undated (©2026). — [Google Play Console Help: AI-Generated Content policy (answer/14094294)](https://support.google.com/googleplay/android-developer/answer/14094294)
- **Violative examples** listed in the policy:
  - AI-generated "non-consensual deepfake sexual material"
  - voice or video recordings of real-life individuals that facilitate scams
  - content encouraging harmful behaviour or self-harm
  - demonstrably deceptive election content
  - bullying or harassment content
  - generative AI apps "primarily intended to be sexually gratifying"
  - AI-generated official documentation that enables dishonest behaviour
  - malicious code creation

  — [Google Play Console Help (answer/14094294)](https://support.google.com/googleplay/android-developer/answer/14094294)
- **In-app reporting (mandatory).** "Apps that generate content using AI must contain in-app user reporting or flagging features" that "allow users to report or flag offensive content to developers without needing to exit the app". Separately, "Developers should utilize user reports to inform content filtering and moderation", which is phrased as a recommendation. AI apps must also prevent generation of Restricted Content (e.g. CSAE) and content that enables Deceptive Behavior. — [Google Play Console Help: AI-Generated Content (answer/13985936)](https://support.google.com/googleplay/android-developer/answer/13985936)
- **August 2026 update.** On 25 Aug 2026, Google's Trust & Safety director restated that "Google Play's policies prohibit the facilitation, creation, or distribution of non-consensual sexual content".
  - Reviewers need full access to AI features that "are not blocked by subscription requirements or paywalls (this includes features that are geo-fenced)".
  - Developers should document the safety prompts and edge cases they tested, including evidence that models reject explicit-edit, deepfake, "nudify" and "undress" requests.
  - Google recommends custom input **and** output moderation rather than relying only on model filters, plus adversarial testing.
  - Apps removed for NCII are "blocked from monetization and advertising across our platforms".
  - Reviews may take longer for GenAI apps.
  - The post is framed as reiterated requirements and gives no new deadline.

  — [Android Developers Blog, 25 Aug 2026](https://android-developers.googleblog.com/2026/08/ensuring-safety-genai-preventing-non-consensual-intimate-content.html)
- **Testing documentation [SECONDARY].** Secondary coverage says Google may request documentation of testing processes, that apps marketing inappropriate uses can be removed, and that the reporting requirement dates from the original announcement (formalised in 2025 per a law-firm summary). — [TechCrunch (original announcement)](https://techcrunch.com/?p=2619733); [Revera legal summary](https://revera.legal/en/info-centr/news-and-analytical-materials/2114-ii-v-mobilnyx-prilozheniyax-trebovaniya-google-play/amp/)
- **Unverified enforcement claim [SECONDARY, low confidence].** One blog says enforcement against "thin wrapper"/low-value AI apps escalated in mid-2026, including retroactive removals. It cites only unnamed developer reports. — [appsops.store](https://appsops.store/news/google-play-ai-content-policy-low-value-apps-2026)
- **Photo & Video Permissions policy.** Only apps with a core need for broad access may keep `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`. Apps with one-time or infrequent needs should use the system **Android photo picker**. Compliance started 22 Jan 2025, and the extension window closed 28 May 2025 **[OLDER]**. — [Play Console Help: Photo and Video Permissions (answer/14115180)](https://support.google.com/googleplay/android-developer/answer/14115180); [Policy Deadlines](https://support.google.com/googleplay/android-developer/answer/9876714)
- **Data safety form.**
  - "Collect" means transmitting data off the device, including via SDKs.
  - "Sharing" means transferring it to a third party. Transfers to a **service provider** processing data on the developer's behalf and under its instructions generally need not be disclosed as sharing.
  - Data types include "Photos", "Videos", "Voice or sound recordings", "Music files" and "Other audio files".
  - Ephemeral, in-memory-only processing can be left out of the public label but must still be declared in the form.
  - Data should be encrypted in transit (TLS/HTTPS).
  - The form asks whether users can request deletion. The deletion badge is available if a mechanism exists or data is deleted or anonymised within 90 days.

  — [Play Console Help: Data safety section (answer/10787469)](https://support.google.com/googleplay/android-developer/answer/10787469)
- **Payments.**
  - Apps that accept payment for in-app features or services must use Google Play's billing system. Listed examples include "Items (such as virtual currencies, extra lives, additional playtime…".
  - "In-app virtual currencies must only be used within the app or game title for which they were purchased."
  - Apps may not lead users to another payment method, except under the exceptions in Sections 3, 8 and 9. Section 3 covers physical goods and similar. Sections 8 and 9 are enrolment-based alternative billing and external-link programs in eligible countries.
  - The page does not mention AI credits specifically and shows no effective dates.

  — [Play Console Help: Payments policy (answer/9858738)](https://support.google.com/googleplay/android-developer/answer/9858738)

### Inferences
- **Checklist (Play):**
  - (a) A "Report / Xabar berish" control on every AI result (image, clip, final export and AI chat reply) that sends a report to the backend in-app, with no email or web redirect.
  - (b) Server-side prompt **and** output moderation, logging blocked attempts as tuning signals.
  - (c) A written safety-test dossier: an adversarial prompt list (nudify, undress, minors, celebrity deepfake, scam voice, election), results, and model refusal evidence, kept ready for reviewers.
  - (d) A reviewer account with free credits and all premium AI features unlocked, without geo-fence. This matters because the backend may restrict regions.
  - (e) Use the Android photo picker. Do not request `READ_MEDIA_*` unless there is a strong broad-access case.
  - (f) Credits sold only via Play Billing as consumables, usable only inside HOOKKADR.
  - (g) Store listing and ads must not market undress, face-swap-anyone or similar uses.
- **Data safety classification.** The backend proxies AI providers that process uploads under HOOKKADR's instructions. Those transfers can probably be classed as service-provider transfers rather than "sharing", but only if provider contracts actually restrict use to HOOKKADR's purposes. Google's unpaid Gemini API tier uses content for training (see section 5), which would undermine the service-provider classification. **[LAWYER]**
- **Declare in the form:** Photos, Videos and Audio (voice) collected for app functionality. Ephemeral exclusion is only valid if the server never persists media. Generated outputs stored in the cloud are "collected".
- **Policy uptake.** The reiterated August 2026 requirements suggest generative-video apps with real-person features will get closer review. A face-swap or "make anyone say X" feature carries a disproportionate rejection risk.

### Gaps
- I did not fetch the linked "Best Practices to Safeguard AI-Generated Content" Help Center article. Any additional specifics there (red-teaming expectations, age-gating) are unverified.
- The Play policy pages show no "last updated" dates, so the exact effective date of the in-app reporting requirement in current form could not be confirmed from the primary page.
- **Account deletion (not re-verified in this session).** The Play account-deletion requirement (in-app path plus a web link in Data safety) is from prior knowledge, so a lawyer or engineer should check the current User Data policy text.
- I did not verify whether Google Play Billing supports buyer payment methods for users located in Uzbekistan (e.g., local cards or carrier billing). This is commercially critical for a credit model aimed at Uzbek users.
- No primary source was found for the US external-offers program terms post-Epic, or for EEA alternative billing eligibility as of Oct 2026.

---

## 2. Apple App Store Review Guidelines: 1.2 UGC, objectionable content, 5.1.2(i) third-party AI, 3.1.1 credits, age rating, privacy labels, Sign in with Apple

### Takeaway
Apple has no standalone "generative AI" guideline. The binding AI-specific text is **5.1.2(i)**, amended Nov 2025: apps "must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so". HOOKKADR therefore needs an explicit in-app consent step before sending a user's photos, video, voice or prompts to OpenAI, Google and other providers. Other relevant rules:
- **3.1.1**: credits must be sold via IAP and must not expire.
- **4.8**: Google Sign-In requires an additional privacy-preserving login option. Sign in with Apple qualifies.
- **1.2**: applies if users can share or see others' content.
- **2.1**: requires a working demo account.

### Cited Findings
- **5.1.2(i), quoted verbatim:** "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." The surrounding text also requires that people be told "how and where the data will be used", and says apps that share data without consent "may be removed from sale". Page undated. — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Date of the 5.1.2(i) change.** It was added in the 13 Nov 2025 guideline revision, and the earlier text did not name third-party AI. — [TechCrunch, 13 Nov 2025](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai) **[OLDER, SECONDARY for date]**
- **Interpretation and enforcement [SECONDARY].**
  - A vendor guide (6 May 2026) says a generic privacy-policy line is not enough and that a contextual in-app disclosure is expected. This is an interpretation, not Apple's text. — [stora.sh guide, 6 May 2026](https://stora.sh/blog/2026-05-06-apple-ai-consent-rule-5-1-2-i-implementation-guide)
  - Apple developer forum posts show rejections citing 5.1.1(i) and 5.1.2(i) when an app sends personal data to a third-party AI service without clearly explaining what is sent. — [Apple Developer Forums (profile thread)](https://origin-devforums.apple.com/forums/profile/MideOluyi)
- **5.1.1 data collection.**
  - (i) A privacy policy link is required both in App Store Connect and in-app. It must identify data collected, its uses, retention and deletion, and how to revoke consent.
  - (ii) Consent is required for collection, and a withdrawal path must be offered. "Paid functionality must not be dependent on or require a user to grant access to this data."
  - (iii) Data minimisation applies: use the out-of-process picker where possible rather than full Photos access.
  - (v) Apps that support account creation must offer in-app account deletion.

  — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **1.2 User-Generated Content.** UGC and social apps must include:
  - a method for filtering objectionable material
  - a mechanism to report offensive content, with timely responses
  - the ability to block abusive users
  - published contact information

  Apps used primarily for pornography or "objectification of real people" do not belong on the store. — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **1.1 / 1.1.1 / 1.1.4 objectionable content.** Defamatory, discriminatory or mean-spirited content is not allowed (professional political satirists are generally exempt). Nor is "overtly sexual or pornographic material". — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **No explicit AI terms.** The fetched guideline text contains no explicit "AI", "generative", "deepfake" or "likeness" guideline apart from 5.1.2(i), within the portion read (first 100k of 112k characters). — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.1 In-App Purchase.**
  - Unlocking features or functionality "(by way of example: subscriptions, in-game currencies…)" must use IAP.
  - "Any credits or in-game currencies purchased via in-app purchase may not expire, and you should make sure you have a restore mechanism for any restorable in-app purchases."
  - Under 3.1.3(b) Multiplatform Services, consumables bought elsewhere may be usable in the app only if they are also offered as IAP.

  — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **4.8 Login Services.** An app that uses Google Sign-In (or similar) for the primary account "must also offer as an equivalent option another login service". That service must limit collection to name and email, allow keeping the email private, and not collect interactions for advertising without consent. The section does not name Sign in with Apple. — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **2.1(a) App Completeness.** "Include demo account info (and turn on your back-end service!) if your app includes a login". — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **5.2 Intellectual Property.**
  - 5.2.1: no protected third-party material without permission.
  - 5.2.2: the developer must be permitted under third-party service terms, with authorisation provided on request.
  - 5.2.3: no saving, converting or downloading media from third-party sources (YouTube, Apple Music, etc.) without authorisation.

  — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Age ratings.**
  - Apple added 13+, 16+ and 18+ tiers and new questionnaire items covering in-app controls, capabilities, medical/wellness and violent themes.
  - The deadline to answer was **31 Jan 2026**. After that, updates are blocked in App Store Connect until the questions are answered. — [9to5Mac, 24 Jul 2025](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/) **[OLDER]**
  - Apple's developer email said apps must account for all features "including AI assistants and chatbot functionality" when rating sensitive-content frequency. — [Business Today, 28 Jul 2025](https://www.businesstoday.in/amp/technology/news/story/apple-overhauls-app-store-age-ratings-adds-new-13-16-and-18-categories-486587-2025-07-28) **[OLDER, SECONDARY]**

### Inferences
- **Checklist (Apple):**
  - (a) Before the first AI call, a consent screen in Uzbek that names the providers by category or name (e.g., "OpenAI, Google"), says what is sent (photos, video frames, audio, prompt text) and why, and requires explicit opt-in. Store the consent and allow withdrawal in settings.
  - (b) Paid credits must not be conditioned on extra data consent beyond what the AI processing itself needs. Users who decline should still reach non-AI editing.
  - (c) Credits as consumable IAP, with no expiry on purchased credits. Promotional or free credits are a grey area **[LAWYER]**. Server-side balance tied to the account, plus restore.
  - (d) If Google Sign-In is offered, add Sign in with Apple, which meets all three 4.8 criteria.
  - (e) In-app account deletion.
  - (f) A demo account with credits for App Review, with the backend live.
  - (g) Use PHPicker or the out-of-process picker.
  - (h) Answer the age-rating questionnaire, counting AI output. See section 5: Gemini API terms push toward 18+.
  - (i) If HOOKKADR has any community feed, template sharing or public links, apply the full 1.2 kit: filter, report, block, contact.
- **Privacy nutrition label.** It will likely need Photos or Videos, Audio Data, Other User Content, Purchase History, User ID, Email (if login) and Product Interaction. These are "linked to user" if tied to the account. I could not verify this against Apple's label definitions in this session.
- **App Review vs. AI provider names.** Apple's text says "where personal data will be shared". Naming the actual providers is the safer interpretation. **[LAWYER]**

### Gaps
- The exact Apple developer-news wording for the Nov 2025 revision was not fetched. The date relies on TechCrunch.
- Apple's privacy nutrition label definitions (App Privacy Details page) were not fetched.
- The exact wording of any AI-specific question in the new age-rating questionnaire was not found.
- There is no Apple statement on whether a single-user AI generator with no sharing feature is treated as "UGC" under 1.2. In practice reviewers sometimes apply 1.2 to AI apps, but I found no primary source.
- The final ~12k characters of the Guidelines page (part of section 5) were not read.

---

## 3. Content provenance: C2PA / Content Credentials, provider watermarks, FFmpeg survival, adding C2PA in-app, EU AI Act Article 50, platform labeling

### Takeaway
- **What providers embed.** Major providers mark their output. OpenAI adds C2PA to images and Sora, and per OpenAI is now layering Google's SynthID onto images. Google adds SynthID across image, video and audio, plus C2PA on Nano Banana Pro images.
- **FFmpeg.** A normal FFmpeg decode and re-encode **destroys C2PA manifests**. Invisible SynthID watermarks are designed to survive.
- **Adding C2PA.** HOOKKADR can sign its own exported MP4/JPEG using c2pa-rs, which supports MP4/MOV/JPEG. This is best done server-side or as the final step after FFmpeg. A Flutter plugin exists but lists only image formats.
- **EU AI Act.** Article 50 transparency duties apply from **2 Aug 2026**. The 50(2) machine-readable marking duty is reportedly deferred to **2 Dec 2026** only for systems already on the market before 2 Aug 2026.
- **YouTube.** YouTube auto-labels C2PA-marked content, and those labels are locked.

### Cited Findings
- **OpenAI.**
  - OpenAI began adding C2PA to DALL·E 3 images in 2024 and extended it to ImageGen and Sora. A newer OpenAI post says it is layering **SynthID** watermarking onto images from ChatGPT, Codex and the **OpenAI API**, framing metadata and watermark as complementary.
  - OpenAI acknowledges metadata "can be stripped… lost through uploads and downloads, or broken by transformations like file format changes, resizing, or screenshots".
  - Sora uses visible watermarks.
  - The page returned HTTP 403 on direct fetch, so this content comes via search-result extraction. — [OpenAI: Understanding the source of what we see and hear online](https://openai.com/index/understanding-the-source-of-what-we-see-and-hear-online); [OpenAI: Advancing content provenance](https://openai.com/index/advancing-content-provenance) **[2024 post is OLDER]**
  - A secondary report says OpenAI launched an openai.com/verify tool on 19 May 2026 that checks C2PA and SynthID. **Unconfirmed on OpenAI's site.** — [aiweekly](https://aiweekly.co/alerts/openai-adds-synthid-watermarks-to-all-generated-images) **[SECONDARY]**
- **Google.**
  - SynthID verification covers image, video and audio in the Gemini app. — [Google blog: Making it easier to understand how content was created and edited](https://blog.google/innovation-and-ai/products/making-it-easier-to-understand-how-content-was-created-and-edited/)
  - Nano Banana Pro images carry C2PA metadata in the Gemini app, Vertex AI and Google Ads. — [Google blog: AI image verification in the Gemini app](https://blog.google/technology/ai/ai-image-verification-gemini-app/)
  - I found no source confirming C2PA on Veo video output via the API.
- **ElevenLabs** forbids removing, altering or concealing its watermarks: "You must not remove, alter, or conceal ElevenLabs watermarks". — [ElevenLabs Use Policy, updated 9 Oct 2026](https://elevenlabs.io/use-policy)
- **FFmpeg strips C2PA.**
  - A 2026 test of 34 operations on signed JPEG, PNG, WebP and MP4 included FFmpeg 7.0.2. Any decode-to-pixels and re-encode writes a new file, and the credential is not in the pixels. MP4 manifests live in a `uuid` box. Keeping EXIF does not keep C2PA. — [Creative AI News: Content credentials export survival test 2026](https://www.creativeainews.com/articles/content-credentials-export-survival-test-2026/) **[SECONDARY; table partly garbled in extraction]**
  - Encoders that are not C2PA-aware strip manifests when rewrapping into MP4. The recommendation is C2PA-aware pass-through or re-signing. — [SSL.com: Preserving C2PA manifests across the media production workflow](https://www.ssl.com/article/preserving-c2pa-manifests-across-the-media-production-workflow/)
  - C2PA manifests are usually stripped by screenshots and re-encoding, while SynthID is designed to survive them. — [c2paviewer guide](https://c2paviewer.com/articles/verify-ai-generated-image-c2pa-synthid) **[SECONDARY]**
- **Tooling to add C2PA.**
  - c2pa-rs (the Rust library, which also backs c2pa-node and c2pa-c) lists supported formats including **mp4 (video/mp4), mov (video/quicktime), jpg/jpeg**, plus PNG, WebP, HEIC, AVIF, M4A, WAV and others. Fragmented MP4 is supported only for file-based operations. — [CAI open-source docs: c2pa-c supported formats](https://opensource.contentauthenticity.org/docs/c2pa-c/docs/supported-formats/); [c2pa-node v2 supported formats](https://opensource.contentauthenticity.org/docs/c2pa-node-v2/supported-formats)
  - **c2pa_flutter 0.1.0** wraps c2pa-rs v0.75 via FFI, with iOS Keychain and Android Keystore signing. Its listed read formats are JPEG, PNG, TIFF, WebP and DNG, so **MP4 is not listed**. — [pub.dev c2pa_flutter](https://pub.dev/packages/c2pa_flutter)
  - Other options include a c2pa-ios Swift wrapper over the c2pa-rs C API (the doc URL returned 404 on fetch) and Guardian Project's simple-c2pa (alpha, Android via Maven and iOS via SPM). Truepic sells commercial native SDKs and a CA. — [search results incl. Truepic](https://truepic.com/c2pa-signing); [simple-c2pa README mirror](https://archive.git.mtrnord.blog/mtrnords-photography-manager/simple-c2pa/file/README.md.html)
  - A test certificate yields an "untrusted signer" result in validators. — [Creative AI News](https://www.creativeainews.com/articles/content-credentials-export-survival-test-2026/)
- **EU AI Act Article 50 (primary text via a mirror).**
  - **50(2):** providers of systems generating synthetic audio, image, video or text must ensure outputs "are marked in a machine-readable format and detectable as artificially generated or manipulated", with solutions that are "effective, interoperable, robust and reliable" as far as technically feasible.
  - **50(4):** deployers of deepfakes "shall disclose that the content has been artificially generated or manipulated". For "evidently artistic, creative, satirical, fictional or analogous" works, disclosure may be done "in an appropriate manner that does not hamper the display or enjoyment of the work".
  - **50(5):** information must be given "at the latest at the time of the first interaction or exposure".
  - Applies from 2 Aug 2026 per Art. 113.

  — [AI Act Explorer, Article 50](https://artificialintelligenceact.eu/article/50/) (mirror of Regulation (EU) 2024/1689; EUR-Lex not fetched)
- **Digital Omnibus deferral [SECONDARY].**
  - The 50(2) watermarking duty is reportedly deferred to **2 Dec 2026** for systems already on the market before 2 Aug 2026. New systems must comply when placed on the market. Other Article 50 duties (50(1) and the 50(4) deepfake disclosure) were not delayed.
  - The provisional agreement was reached on 7 May 2026 and needed formal adoption.
  - A 21 Sep 2026 CSA note says the AI Board's 17 Sep 2026 meeting granted no further relief.
  - Fines for Article 50 breaches reach up to €15M or 3% of worldwide turnover.

  — [CSA research note, 29 Jul 2026](https://labs.cloudsecurityalliance.org/research/csa-research-note-eu-ai-act-article-50-transparency-20260729/); [CSA research note, 21 Sep 2026](https://labs.cloudsecurityalliance.org/research/csa-research-note-eu-ai-act-article50-watermarking-deadline/); [Pillitteri on Digital Omnibus](https://pasqualepillitteri.it/en/news/5190/digital-omnibus-ai-act-eu-parliament)
- **Code of Practice [SECONDARY].** The Commission published the final Code of Practice on marking and labelling AI-generated content on **10 Jun 2026**. It has a provider section (marking and detection) and a deployer section (labelling deepfakes and AI text), and comes with an EU icon set. Adherence is voluntary, while Article 50 itself is binding. It states that no single marking technique currently meets all four criteria, which implies a layered approach. — [Jones Day, Jun 2026](https://www.jonesday.com/en/insights/2026/06/european-commission-publishes-final-code-of-practice-on-marking-and-labelling-aigenerated-content); [Freevacy](https://www.freevacy.com/news/european-commission/eu-publishes-final-code-of-practice-on-transparency-of-ai-generated-content/7453)
- **YouTube (primary help page, undated ©2026).**
  - **What to disclose:** realistic AI content in which a real person appears to say or do something they didn't, altered footage of real events or places, realistic scenes that never occurred, and AI music that is the main focus.
  - **Exemptions:** clearly unrealistic content, beauty filters, colour and lighting changes, AI-assisted scripts, captions or upscaling, and cloning your own voice for voiceovers.
  - YouTube may auto-label content "carrying C2PA metadata". Labels **cannot be changed** for content made with YouTube's own AI tools, content with C2PA metadata, or content labelled after manual review.
  - Persistent non-disclosure can lead to removal or YPP suspension.

  — [YouTube Help: Disclosing altered or synthetic content (answer/14328491)](https://support.google.com/youtube/answer/14328491)
  - The 27 May 2026 update made labels more prominent and automatic, and labels do not affect monetisation. — [TechWyse, May 2026](https://www.techwyse.com/news/platform-updates/youtube-automatic-ai-labels-disclosure-may-2026) **[SECONDARY]**
- **TikTok [OLDER, 2024].** TikTok requires creators to label realistic AIGC, and it auto-labels content carrying C2PA Content Credentials from other platforms (images and video first). — [Tubefilter, 9 May 2024](https://tubefilter.com/2024/05/09/tiktok-transparency-labels-for-generative-ai-content/)
  - A 2026 secondary source claims TikTok has labelled over 1.3 billion videos. — [Storrito](https://storrito.com/resources/tiktoks-2026-ai-labeling-rules-and-what-they-signal-for-platform-governance) **[SECONDARY]**
- **Meta [SECONDARY].** Meta (Facebook, Instagram, Threads) labelling using C2PA and IPTC is described as live since 2024, but no primary Meta page was fetched. — [billo.app blog](https://billo.app/blog/ai-labeling/)

### Inferences
- **Pipeline consequence.** HOOKKADR assembles video with FFmpeg (`render_plan.dart`), so provider C2PA manifests on generated clips will **not** survive into the final MP4. SynthID-type invisible watermarks probably will survive partly, depending on crops, overlays and re-encode strength, but HOOKKADR cannot rely on or verify them.
- **Provenance checklist:**
  - (a) Before re-encoding, read each provider asset's manifest and keep it as an *ingredient* reference in the export manifest.
  - (b) After the final FFmpeg export, sign the MP4 or JPEG with a HOOKKADR C2PA manifest. It should include a `digitalSourceType` reflecting the mix (e.g., `trainedAlgorithmicMedia` for fully generated clips vs. `compositeWithTrainedAlgorithmicMedia` for user footage plus AI b-roll) and actions such as `c2pa.created`/`c2pa.edited`.
  - (c) Sign on the server using c2pa-rs, c2patool or c2pa-node in the Node 26 backend, with a key held in KMS. This fits the "keys only on server" rule, and c2pa_flutter does not list MP4.
  - (d) Get a certificate from a CA on the C2PA trust list, or validators will show "untrusted".
  - (e) Add an optional visible "AI" badge or end-card at export (Uzbek: "AI yordamida yaratilgan"). This also serves EU 50(4) deployer disclosure for users.
  - (f) Never strip or crop provider watermarks. ElevenLabs forbids it, and it would break "honesty" design rules.
- **YouTube labels.** Embedding C2PA that declares AI generation will cause YouTube to lock an AI label on uploads. This is honest and compliant, but the manifest should distinguish AI-assisted editing (colour, captions, auto-cuts, which YouTube exempts) from generative content. Otherwise, purely AI-*edited* real footage may get an unwarranted permanent label. Only emit "AI-generated" source types when generative media is actually in the output.
- **EU role.** If HOOKKADR offers generation to EU users under its own brand, it is plausibly a "provider" of a generative system for Art. 50(2), not merely a deployer. That would make machine-readable marking HOOKKADR's legal duty for EU-distributed output, from 2 Aug 2026 for a new system, or 2 Dec 2026 if the deferral applies and the app was on the market before 2 Aug 2026. **[LAWYER]**

### Gaps
- Official EUR-Lex / Official Journal text of the Digital Omnibus amendment was not fetched, and the adoption status of the 2 Dec 2026 deferral is unconfirmed beyond secondary sources.
- I found no primary source on whether Veo, Runway or Luma video outputs carry C2PA via API.
- The OpenAI provenance page returned 403. Details of SynthID on API images are from search extraction only.
- C2PA trust-list or conformance-program requirements for signing certificates, and their cost, were not researched.
- There are no primary TikTok or Meta policy pages for 2026.
- I did not test whether c2pa_flutter can write MP4. Its pub.dev listing shows image formats only.

---

## 4. Uzbekistan: personal data law (ZRU-547), localisation, AI regulation, foreign cloud storage

### Takeaway
ZRU-547 "On Personal Data" (2019) was amended by **ZRU-1125 of 26 Mar 2026**. Under the amended Article 27-1, only **biometric data, genetic data, and data of users of telecom operators in Uzbekistan** must be stored in Uzbekistan, with registration in the State Register. Other personal data of citizens may be stored abroad if one of three conditions is met:
- the destination is an "adequate" country on the Cabinet of Ministers list,
- approved standard contractual clauses or binding corporate rules are used, or
- listed international standards are followed.

Uzbekistan's AI law **ZRU-1115 (21 Jan 2026)** created a fine of 50–100 BCU plus confiscation for unlawful AI processing of personal data. **Its final text, as published on lex.uz, contains no AI-content labelling duty**, contrary to draft-stage press reports.

### Cited Findings
- **Article 27-1 (ZRU-547).** Per the official lex.uz text, the latest edition dated 12 Sep 2026 requires the following to be stored in Uzbekistan:
  - biometric data
  - genetic data
  - data of telecom operators' users in Uzbekistan

  Other personal data may be stored or processed abroad if one of three conditions is met:
  - (1) the country is recognised as ensuring equal protection, with the list set by the Cabinet of Ministers
  - (2) the operator adopts standard contractual terms or binding corporate rules approved by the authorised body
  - (3) the operator complies with international standards listed by the authorised body

  The note under Art. 27-1 says it was amended by **ZRU-1125 of 26 Mar 2026** (published 27 Mar 2026). — [lex.uz: ZRU-547 On Personal Data](https://lex.uz/docs/4396419)
- **Article 20.** Databases that must be stored in Uzbekistan under Art. 27-1 must be registered in the State Register of Personal Data Databases by notification, and changes must be reported within 10 calendar days. — [lex.uz ZRU-547](https://lex.uz/docs/4396419)
- **Article 26 (biometric).** Biometric data are personal data describing a person's anatomical and physiological features. Biometric and genetic data used to identify a person may be processed only with the subject's consent, subject to narrow exceptions. — [lex.uz ZRU-547](https://lex.uz/docs/4396419)
- **Articles 21 and 25 (consent).** Consent may be in any provable form. **Special** personal data require written consent, which may be electronic. The latest revision, **ZRU-1174 of 11 Sep 2026**, amended Article 25, but the content of that amendment was not extracted. — [lex.uz ZRU-547](https://lex.uz/docs/4396419)
- **Article 15 (cross-border).** Transfers are permitted to countries ensuring equal protection. Transfers elsewhere are allowed in listed cases, including the subject's consent. Transfers may be banned or restricted for constitutional-order, defence or security reasons. — [lex.uz ZRU-547](https://lex.uz/docs/4396419)
- **History of Article 27-1 [OLDER].**
  - The original Art. 27-1 (added by ZRU-666, 14 Jan 2021, in force 15 Apr 2021) required **all** citizens' personal data to be stored on servers in Uzbekistan. — [Mondaq summary](https://mondaq.com/data-protection/1197754/the-law-on-personal-data-has-been-amended)
  - Enforcement was selective after the Nov 2021 social-network blocking. The rule was cited as deterring Apple Pay and Google Pay entry. — [Kun.uz, 26 Dec 2024](https://kun.uz/en/news/2024/12/26/uzbekistans-data-localization-law-hinders-entry-of-apple-pay-and-google-pay)
  - The March 2026 amendment was presented as facilitating global payment systems. — [Kun.uz, 27 Mar 2026 (headline; body not extractable)](https://kun.uz/en/news/2026/03/27/uzbekistan-amends-personal-data-law-to-facilitate-global-payment-systems); [DTI EUI database entry](https://dti.eui.eu/database/page/184)
- **AI law ZRU-1115 (21 Jan 2026), per the lex.uz text.**
  - New Article 7-1 in the Law "On Informatization": AI-created information resources and systems must not harm a person's life, health, freedom, honour or dignity, and legally significant decisions affecting rights may not rest solely on AI conclusions.
  - Administrative Code Art. 462 gains a part 2: "unlawful processing of personal data using AI technologies, and its dissemination" is fined **50–100 base calculation units (BCU)**, with confiscation of the items used.
  - The law entered into force on official publication (21 Jan 2026).
  - **No labelling or marking provision was found in the text.**

  — [lex.uz: ZRU-1115](https://lex.uz/docs/8011377); [gov.uz Ministry of Digital Technologies news](https://gov.uz/en/digital/news/view/122739); [Spot.uz, 21 Jan 2026](https://www.spot.uz/ru/2026/01/21/ai-amendments/)
- **Draft vs. enacted labelling (conflict).** Draft-stage reports said AI-generated information resources and products shared online "must be labeled", with penalties up to 15 days' arrest. — [Kun.uz, 16 Apr 2025](https://kun.uz/en/news/2025/04/16/uzbekistan-takes-steps-to-regulate-ai-with-new-legislation); [Orda.kz](https://en.orda.kz/uzbekistan-to-impose-fines-for-misuse-of-artificial-intelligence-9096). **This conflicts with** the enacted text on lex.uz, which shows no labelling article and fine plus confiscation only. — [lex.uz ZRU-1115](https://lex.uz/docs/8011377)

### Inferences
- **Are face photos and voice clips "biometric data"?** This is the key question for HOOKKADR. Under Art. 26, biometric data are anatomical and physiological features used to identify a person. Ordinary photos and videos of a user are arguably not biometric unless processed to identify or model the person. However, features like face-swap, face-embedding "consistent character", "put me in the video" or voice cloning plausibly create biometric templates. If so, those templates must be stored in Uzbekistan (Art. 27-1), registered (Art. 20), and processed only with consent (Art. 26). **[LAWYER — highest priority Uzbek question]**
- **Uzbekistan checklist:**
  - (a) Keep user media processing **ephemeral** on foreign providers and servers: no persistent storage of face or voice templates outside Uzbekistan.
  - (b) If HOOKKADR stores accounts, media libraries or exports on foreign cloud (e.g., EU or US), document which Art. 27-1 condition applies. The EU/EEA may qualify only if the Cabinet of Ministers adequacy list includes it, which is unverified. Otherwise use approved SCCs or BCRs.
  - (c) Obtain explicit electronic consent (Uzbek-language) for processing and cross-border transfer. Art. 15 allows transfer with consent, and this aligns with Apple 5.1.2(i).
  - (d) If any database must be local (e.g., biometric), register it in the State Register.
  - (e) Prohibit and filter AI misuse of other people's personal data (e.g., uploading someone else's photo to make content). Art. 462(2) targets the person doing the unlawful processing, but HOOKKADR's terms should allocate responsibility and the product should require likeness consent.
- **Labelling.** There is no statutory AI-label requirement in Uzbekistan as of the lex.uz text, but voluntary "AI" disclosure on exports remains advisable given the draft history and possible future bylaws.

### Gaps
- The current Cabinet of Ministers "adequate countries" list, and the approved SCC or BCR templates under amended Art. 27-1, were not found.
- The content of the ZRU-1174 (11 Sep 2026) amendment to Art. 25 (consent) is unknown.
- I found no official guidance on whether ordinary face photos or voice recordings are "biometric data", or on who is the "operator" when a foreign backend processes data.
- The current BCU value in UZS was not verified, so the fine range in UZS is not computed.
- Any implementing regulation on AI-content labelling after ZRU-1115 was not found.
- The lex.uz content was extracted by a summarising fetch tool. Exact wording should be re-read by an Uzbek-speaking lawyer.

---

## 5. Likeness and voice: consent for real people's faces and voices; provider policies (OpenAI, Google, ElevenLabs)

### Takeaway
Every relevant provider and both app stores prohibit deceptive or non-consensual use of real people's likeness and voice. ElevenLabs requires "explicit and informed consent" to clone any living person's voice and bans voice models from recordings of minors. OpenAI bars using someone's likeness, including photorealistic images and voices, without consent in ways that could confuse authenticity. Google bars impersonation intended to deceive and non-consensual intimate imagery. Google Play names scam deepfakes and non-consensual sexual deepfakes as violations. Separately, Gemini API terms bar apps likely to be used by under-18s.

### Cited Findings
- **ElevenLabs Use Policy (updated 9 Oct 2026).**
  - Consent: "cloning, synthesizing, or impersonating the voice, identity, or likeness of any living individual" requires "explicit and informed consent or other valid authorization". Deceased persons are covered where use is "reasonably likely to cause harm".
  - Minors: "You may not submit voice recordings of anyone under 18 to create or train a voice model". The policy also bars creating content using a real minor's likeness.
  - Politics: "Impersonating political candidates or elected officials without authorization" is prohibited, and political campaigning needs prior written consent.
  - For apps built on ElevenLabs: no "client, wrapper, or proxy that gives anyone else access to our Services" outside the terms, no making output available "on terms more permissive" than ElevenLabs' own, disclose AI interaction where required, and never remove ElevenLabs watermarks.

  — [ElevenLabs Use Policy](https://elevenlabs.io/use-policy)
- **OpenAI Usage Policies (effective 29 Oct 2025)** prohibit using someone's likeness without consent, including photorealistic images and voices, in ways that could confuse authenticity. They also bar facial-recognition databases built without consent. The page was not directly fetched; this is from search-result extraction of openai.com. — [OpenAI Usage Policies](https://openai.com/policies/usage-policies/) **[OLDER]**
- **Sora guardrails [SECONDARY, OLDER].** OpenAI tightened Sora to prevent videos with celebrities' voices or likenesses without permission, and estates can opt out of historical-figure likeness. — [Consequence, Oct 2025](https://concerts.consequence.net/articles/openai-guardrails-sora-backlash-mlk-jr); [Mezha.ua](https://mezha.ua/en/news/openai-posilyuye-kontrol-nad-dipfeykami-u-sora-305715/amp/)
- **Google Generative AI Prohibited Use Policy (last modified 17 Dec 2024)** prohibits:
  - "Impersonating an individual (living or dead) without explicit disclosure, in order to deceive" (§4.2)
  - "Facilitates non-consensual intimate imagery" (§1.3)
  - "Misrepresenting the provenance of generated content by claiming it was created solely by a human, in order to deceive" (§4.5)
  - "Sexually explicit content" (§3.4)

  — [Google Generative AI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy) **[OLDER]**
- **Gemini API Additional Terms (effective 23 Mar 2026; page updated 28 Apr 2026).**
  - "You must be 18 years of age or older to use the APIs."
  - The API may not be used in an app "directed towards or is likely to be accessed by individuals under the age of 18".
  - Only **Paid Services** may be used when making API clients available to users in the EEA, Switzerland or UK.
  - Unpaid services use content for training and human review: "Do not submit sensitive, confidential, or personal information to the Unpaid Services". Paid services don't use prompts or responses to improve products.
  - The Services are for developers building "for professional or business purposes, not for consumer use".

  — [Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms)
- **Google Play** lists voice or video recordings of real-life individuals that facilitate scams, and non-consensual deepfake sexual material, as violations. — [Play Console Help (answer/14094294)](https://support.google.com/googleplay/android-developer/answer/14094294)
- **EU AI Act 50(4)** requires deployers to disclose deepfakes, with a lighter-touch duty for evidently artistic or satirical works. — [AI Act Explorer, Art. 50](https://artificialintelligenceact.eu/article/50/)

### Inferences
- **Likeness checklist:**
  - (a) No feature that animates, face-swaps or voice-clones a person other than the account holder without a recorded consent step. At minimum, an affirmation such as "Men bu shaxsning roziligini oldim / bu menman", ideally with liveness or self-capture for "self" features.
  - (b) Block known public-figure and politician likeness requests via prompt filters and provider refusals. Election-period caution is warranted.
  - (c) Voice cloning is limited to the user's own voice from a live in-app recording, never uploaded third-party audio. No minors.
  - (d) Block any sexual or "undress" edits of uploaded real-person images outright, at both prompt and output stages.
  - (e) Terms of Service must be no more permissive than each upstream provider's policy, as ElevenLabs §12 requires, and must pass through provider prohibited-use lists.
- **Gemini API age restriction.** This is a material constraint. If HOOKKADR uses Gemini, Veo or Imagen through the Gemini API, the app must not be directed to or likely accessed by minors. That points to an **18+ App Store age rating** (or 16+/18+ with age gating) and an "adults" target audience in Play Console. **[LAWYER]** Vertex AI is governed by Google Cloud terms instead, which may differ (not checked).
- **"Not for consumer use."** The Gemini API wording appears to describe HOOKKADR's own capacity as a business developer, not a ban on serving consumers. This needs confirmation. **[LAWYER]**
- **BYOK vs. proxy.** Under ElevenLabs' anti-"proxy" clause, the server-proxy model is fine if HOOKKADR is building an application. It is not fine if it merely resells raw API access, for example a passthrough endpoint for arbitrary TTS.

### Gaps
- Primary text of OpenAI's usage policies was not fetched (likely 403). The likeness clause wording is from search extraction.
- Jurisdiction-specific likeness laws were not researched (e.g., the US TAKE IT DOWN Act, state right-of-publicity and ELVIS-type voice laws, Denmark's proposed likeness copyright, and Uzbek civil-code image rights).
- Runway, Luma and Kling likeness policies were not fetched.
- Vertex AI (Google Cloud) terms on under-18 users were not checked.

---

## 6. Copyright: music in user videos, AI output ownership per provider terms, commercial use

### Takeaway
OpenAI assigns users whatever rights it has in outputs ("if any"). Google says it "won't claim ownership" of Gemini API outputs. Runway says users own their generations and may use them commercially. Luma reportedly ties commercial rights to paid tiers (secondary sources only). None of these guarantees that copyright exists in purely AI output, and outputs may resemble other users' outputs. For music, the app stores require licensed content (Apple 5.2.1, 5.2.3), and YouTube requires disclosure when AI music is the main focus. HOOKKADR should ship only licensed or royalty-free music and not pull audio from YouTube or Spotify.

### Cited Findings
- **OpenAI Terms.** "As between you and us, and to the extent permitted by applicable law, you (a) retain your ownership rights in Input and (b) own the Output. We hereby assign to you all our right, title, and interest, if any, in and to Output." Output may not be unique, and similar output may be given to others. OpenAI may use Content to provide and improve its services. This was extracted via search because direct fetch returned 403. — [OpenAI Terms of Use](https://openai.com/en-GB/policies/terms-of-use/); [ConductAtlas annotation (third party)](https://conductatlas.com/platform/openai/terms-of-use-row/ai-generated-output-ownership-and-assignment/)
- **Gemini API terms.** "Google won't claim ownership over that content", and Google may generate the same or similar content for others. The page has no Veo or Imagen copyright-indemnity provisions. — [Gemini API Additional Terms (updated 28 Apr 2026)](https://ai.google.dev/gemini-api/terms)
- **Runway.**
  - Runway's help center says users own their generations and may use them commercially. — [Runway Help: commercial use](https://help.runwayml.com/hc/en-us/articles/21668707517587-Can-I-use-the-content-I-made-in-Runway-for-commercial-purposes)
  - Third-party summaries say standard terms allow Runway to use inputs and outputs for training (Enterprise excluded), and that free-tier output is watermarked. — [terms.law](https://terms.law/ai-output-rights/runway/) **[SECONDARY]**
  - A claim that free-tier output is non-commercial is contradicted by Runway's help page.
- **Luma [SECONDARY, low confidence].** Luma's terms reportedly assign output to the customer "to the greatest extent permitted by law", but commercial use requires a paid subscription. Free users grant Luma a broad licence. — [ConductAtlas: Luma](https://conductatlas.com/platform/luma-ai/luma-ai-terms-of-service/provision/CA-P-045417/customer-owns-output-subject-to-paid-subscription/); [LicenseOrg](https://licenseorg.com/guide/ai-content/luma-dream-machine)
- **Apple.** 5.2.1: "Don't use protected third-party material such as… copyrighted works… without permission". 5.2.3: no saving, converting or downloading media from third-party sources such as Apple Music, YouTube or SoundCloud without authorisation. — [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **YouTube** requires disclosure when "music is created [with AI] and is the main focus of the video". — [YouTube Help (answer/14328491)](https://support.google.com/youtube/answer/14328491)

### Inferences
- **Copyright checklist:**
  - (a) Bundled music library must be fully licensed for in-app use and for user export to social platforms, including Content ID clearance. Prefer royalty-free libraries with sync rights.
  - (b) No "import from YouTube/TikTok/Spotify" audio feature.
  - (c) Users who import their own music get a ToS warranty that they have rights, plus a warning that platforms may mute or claim.
  - (d) ToS should state that HOOKKADR passes through whatever rights upstream providers grant. HOOKKADR should not promise users "copyright" in AI output.
  - (e) Avoid any provider tier where commercial use is restricted (e.g., unpaid or free tiers). Use paid API tiers only, which also satisfies the Gemini EEA rule and the Play Data safety service-provider logic.
- **Mixed-provider pipelines.** When outputs from multiple providers are combined, the most restrictive provider term governs the final export. Track which provider produced each clip in `EditPlan`, which also feeds the C2PA ingredient list.

### Gaps
- Primary Luma and Runway terms pages were not fetched. Kling, Pika and MiniMax terms were not researched.
- No research was done on the US Copyright Office's 2025 copyrightability report or on Uzbek copyright law treatment of AI works.
- Music-licensing specifics (e.g., Epidemic Sound or Artlist app SDK licences, or Content ID allow-listing) were not researched.

---

## 7. Safety tooling: moderation APIs for prompt and output screening

### Takeaway
OpenAI's `omni-moderation-latest` is **free** and classifies text and images. For images, only sexual, violence and self-harm categories score; `sexual/minors`, hate, harassment and illicit are text-only. It is not a CSAM detector. Google Cloud Vision SafeSearch returns adult, spoof, medical, violence and racy likelihoods for images. Neither endpoint takes video directly, so video outputs need frame sampling or a dedicated video moderation service. Google Play now explicitly expects custom input **and** output moderation beyond model filters.

### Cited Findings
- **OpenAI Moderation.**
  - Model `omni-moderation-latest` takes text and images and does not classify audio. Video is not listed as an input.
  - The endpoint is **free**. Images can be up to 20 MB.
  - Image-capable categories: self-harm (incl. intent and instructions), sexual, and violence (incl. graphic). Text-only categories: harassment, hate, illicit, and sexual/minors. Image-only inputs score 0 on text-only categories.
  - "Don't send known or suspected CSAM to the API". It is not designed for CSAM detection.
  - Scores can shift with model upgrades, so thresholds need recalibration.

  — [OpenAI API docs: Moderation](https://developers.openai.com/api/docs/guides/moderation)
- **Google Cloud Vision SafeSearch.**
  - Categories: `adult`, `spoof`, `medical`, `violence` and `racy`.
  - Likelihoods: UNKNOWN, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY.
  - Inputs: base64 images, GCS URIs, or web URLs (web fetch not guaranteed). Async batch supports up to 2,000 images.
  - The page covers images only.

  — [Google Cloud Vision: Detect explicit content (SafeSearch)](https://docs.cloud.google.com/vision/docs/detecting-safe-search)
- **Google Play guidance.** Don't rely only on built-in model safety filters. Add custom input and output moderation, validate outputs before display, red-team with adversarial prompts (e.g., removing clothing from uploaded images), and treat failed prompt attempts and user reports as tuning signals. — [Android Developers Blog, 25 Aug 2026](https://android-developers.googleblog.com/2026/08/ensuring-safety-genai-preventing-non-consensual-intimate-content.html)
- **Provider-side filters.** Providers retain their own filters, and bypassing them is prohibited: "You may not attempt to bypass these protective measures". — [Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms)

### Inferences
- **Recommended HOOKKADR moderation stack (all server-side, keys on server):**
  1. Prompt screen: translate or normalise Uzbek and Russian prompts, then run OpenAI omni-moderation (text) plus a custom blocklist for undress/nudify terms, minors, celebrity and politician names, and election terms.
  2. Input-image screen: run omni-moderation (image) and/or SafeSearch on user uploads. Refuse sexual edits of any real-person photo.
  3. Output screen: run every generated image, and sampled frames of every generated clip (e.g., 1 fps plus first and last frames), through the image classifier before returning it to the client.
  4. Log blocked attempts, without storing the media, for the Play testing dossier.
  5. Wire in-app reports into a review queue with a response SLA (Apple 1.2 "timely responses").
- **CSAM.** omni-moderation explicitly excludes CSAM detection. A hash-matching service (e.g., PhotoDNA or Google's child-safety tools) and a legal reporting process should be evaluated if any user uploads are stored. **[LAWYER]** (reporting duties vary by jurisdiction)
- **Uzbek-language coverage.** Classifier accuracy for Uzbek-language prompts was not established, so translating prompts before moderation is a prudent inference, not a sourced fact.

### Gaps
- Dedicated video moderation services (Google Video Intelligence explicit content detection, AWS Rekognition video moderation, Hive) were not researched.
- Moderation accuracy for Uzbek (Latin and Cyrillic) text is unknown.
- CSAM hash-matching options and access requirements were not researched.
- I did not fetch Google Play's "Best Practices to Safeguard AI-Generated Content" article, which may name specific tooling expectations.
