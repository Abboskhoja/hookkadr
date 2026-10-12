# HOOKKADR server

Sign-in, credits and the AI proxy. The mobile app never holds provider keys:
it sends the user's Firebase ID token, the server checks credits, calls
Claude / Gemini with **its own** keys, and charges real token usage
(1 credit = $0.01, prices in `src/pricing.ts`).

## Endpoints
| Method | Path | Purpose |
|---|---|---|
| GET | `/healthz` | liveness |
| GET | `/v1/me` | uid + credit balance (creates account, 50 free credits) |
| GET | `/v1/usage` | last 50 ledger entries |
| POST | `/v1/complete` | `{system, messages[], maxTokens}` → Claude text |
| POST | `/v1/video/analyze` | multipart `video` (mp4/mov/webm, ≤18 MB) → Gemini analysis |
| POST | `/v1/images` | `{prompt, aspectRatio}` → Gemini image (5 credits) |

Errors: `401` sign in, `402` no credits (provider not called), `413/415`
video size/type, `429` rate limit, `502/503` provider down (nothing charged).

## Local development
```bash
npm install
npm test                       # 12 tests, no network
DEV_AUTH=1 PROVIDERS=fake PORT=8787 npm start
# app: flutter run --dart-define=HOOKKADR_API_URL=http://127.0.0.1:8787 --dart-define=HOOKKADR_DEV_UID=me
```
`DEV_AUTH` accepts `dev:<uid>` tokens and `PROVIDERS=fake` returns output
marked `[DEV FAKE]`. Both are refused when `NODE_ENV=production`.

## Production checklist (owner actions)
1. **Firebase project**: enable Authentication → Google and Apple providers.
   Then in the app folder run `flutterfire configure` (creates the iOS/Android
   config files) — the app's Google/Apple sign-in is wired after this.
2. **Provider keys** (company accounts): `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`.
   Store them as secrets (e.g. Google Secret Manager), never in the repo.
3. **Deploy** (e.g. Cloud Run in the same Google project, so `firebase-admin`
   uses the default credentials):
   `gcloud run deploy hookkadr-api --source server --set-secrets ...`
4. **Database**: SQLite is fine for one instance with a mounted volume; move
   `CreditStore` to Postgres before scaling to several instances.
5. **Billing**: App Store / Google Play subscriptions or credit packs →
   a `/v1/billing/verify` endpoint that validates receipts and adds credits
   (not built yet).
6. Verify model ids and prices (`CLAUDE_MODEL`, `GEMINI_TEXT_MODEL`,
   `GEMINI_IMAGE_MODEL`, `src/pricing.ts`) against the providers' current docs.
