import { DevVerifier, FirebaseVerifier, type TokenVerifier } from './auth.ts';
import { buildApp } from './app.ts';
import { loadConfig } from './config.ts';
import { CreditStore } from './credits.ts';
import { FakeProviders, RealProviders, type Providers } from './providers.ts';

const config = loadConfig();

let verifier: TokenVerifier;
if (config.devAuth) {
  verifier = new DevVerifier();
} else {
  const { initializeApp, applicationDefault } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  initializeApp({ credential: applicationDefault() });
  verifier = new FirebaseVerifier(getAuth());
}

const providers: Providers =
  config.providers === 'fake'
    ? new FakeProviders()
    : new RealProviders({
        anthropicKey: config.anthropicKey!,
        geminiKey: config.geminiKey!,
        claudeModel: config.claudeModel,
        geminiTextModel: config.geminiTextModel,
        geminiImageModel: config.geminiImageModel,
      });

const app = buildApp({
  verifier,
  credits: new CreditStore(config.dbPath, config.freeCredits),
  providers,
  rateLimitPerMinute: config.rateLimitPerMinute,
  maxVideoBytes: config.maxVideoBytes,
  logger: true,
});

if (config.devAuth || config.providers === 'fake') {
  app.log.warn('DEVELOPMENT MODE: dev auth=%s, providers=%s', config.devAuth, config.providers);
}

await app.listen({ port: config.port, host: '0.0.0.0' });
