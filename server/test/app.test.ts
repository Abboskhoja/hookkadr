import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildApp } from '../src/app.ts';
import { DevVerifier } from '../src/auth.ts';
import { loadConfig } from '../src/config.ts';
import { CreditStore } from '../src/credits.ts';
import { creditsFor } from '../src/pricing.ts';
import { FakeProviders, ProviderError, RealProviders, type Providers } from '../src/providers.ts';

function make(opts: { free?: number; providers?: Providers; rate?: number } = {}) {
  const credits = new CreditStore(':memory:', opts.free ?? 50);
  const app = buildApp({
    verifier: new DevVerifier(),
    credits,
    providers: opts.providers ?? new FakeProviders(),
    rateLimitPerMinute: opts.rate ?? 100,
    maxVideoBytes: 1024 * 1024,
  });
  return { app, credits };
}

const auth = (uid = 'u1') => ({ authorization: `Bearer dev:${uid}` });

test('requests without a valid session are rejected', async () => {
  const { app } = make();
  assert.equal((await app.inject({ method: 'GET', url: '/v1/me' })).statusCode, 401);
  const bad = await app.inject({ method: 'GET', url: '/v1/me', headers: { authorization: 'Bearer nope' } });
  assert.equal(bad.statusCode, 401);
  assert.equal((await app.inject({ method: 'GET', url: '/healthz' })).statusCode, 200);
});

test('a new account receives the free starter credits once', async () => {
  const { app } = make({ free: 50 });
  const a = (await app.inject({ method: 'GET', url: '/v1/me', headers: auth() })).json();
  const b = (await app.inject({ method: 'GET', url: '/v1/me', headers: auth() })).json();
  assert.deepEqual([a.credits, b.credits], [50, 50]);
});

test('completion charges credits from real token usage and records it', async () => {
  const { app, credits } = make({ free: 50 });
  const res = await app.inject({
    method: 'POST',
    url: '/v1/complete',
    headers: auth(),
    payload: { system: 's', messages: [{ role: 'user', content: 'salom' }] },
  });
  assert.equal(res.statusCode, 200);
  const body = res.json();
  assert.match(body.text, /DEV FAKE/);
  assert.equal(body.cost, creditsFor('fake', 120, 40));
  assert.equal(body.credits, 50 - body.cost);
  assert.equal((credits.history('u1')[0] as any).reason, 'complete');
});

test('no credits → 402 and the provider is not called', async () => {
  let called = false;
  const providers = new (class extends FakeProviders {
    override async complete(i: any) {
      called = true;
      return super.complete(i);
    }
  })();
  const { app } = make({ free: 0, providers });
  const res = await app.inject({
    method: 'POST',
    url: '/v1/complete',
    headers: auth(),
    payload: { system: 's', messages: [{ role: 'user', content: 'x' }] },
  });
  assert.equal(res.statusCode, 402);
  assert.equal(res.json().error.code, 'insufficient_credits');
  assert.equal(called, false);
});

test('invalid bodies are rejected with 400', async () => {
  const { app } = make();
  const res = await app.inject({ method: 'POST', url: '/v1/complete', headers: auth(), payload: { messages: [] } });
  assert.equal(res.statusCode, 400);
});

test('per-user rate limit returns 429', async () => {
  const { app } = make({ rate: 2 });
  const codes = [];
  for (let i = 0; i < 3; i++) codes.push((await app.inject({ method: 'GET', url: '/v1/me', headers: auth() })).statusCode);
  assert.deepEqual(codes, [200, 200, 429]);
  // other users are not affected
  assert.equal((await app.inject({ method: 'GET', url: '/v1/me', headers: auth('u2') })).statusCode, 200);
});

test('provider failure → 502, nothing is charged, provider text not leaked', async () => {
  const providers = new (class extends FakeProviders {
    override async complete(): Promise<never> {
      throw new ProviderError('Claude error 500', 502);
    }
  })();
  const { app } = make({ free: 50, providers });
  const res = await app.inject({
    method: 'POST',
    url: '/v1/complete',
    headers: auth(),
    payload: { system: 's', messages: [{ role: 'user', content: 'x' }] },
  });
  assert.equal(res.statusCode, 502);
  assert.equal(res.json().error.code, 'provider_unavailable');
  assert.equal((await app.inject({ method: 'GET', url: '/v1/me', headers: auth() })).json().credits, 50);
});

test('images cost a flat price and need enough credits', async () => {
  const { app } = make({ free: 7 });
  const ok = await app.inject({ method: 'POST', url: '/v1/images', headers: auth(), payload: { prompt: 'kofe', aspectRatio: '9:16' } });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.json().credits, 2);
  const no = await app.inject({ method: 'POST', url: '/v1/images', headers: auth(), payload: { prompt: 'kofe' } });
  assert.equal(no.statusCode, 402);
});

function multipartBody(mime: string, bytes: Buffer) {
  const boundary = '----hk';
  const head = `--${boundary}\r\nContent-Disposition: form-data; name="video"; filename="a.mp4"\r\nContent-Type: ${mime}\r\n\r\n`;
  const payload = Buffer.concat([Buffer.from(head), bytes, Buffer.from(`\r\n--${boundary}--\r\n`)]);
  return { payload, headers: { 'content-type': `multipart/form-data; boundary=${boundary}` } };
}

test('video upload: analysed and charged; wrong type and oversize rejected', async () => {
  const { app } = make();
  const ok = multipartBody('video/mp4', Buffer.alloc(2048, 1));
  const res = await app.inject({ method: 'POST', url: '/v1/video/analyze', headers: { ...auth(), ...ok.headers }, payload: ok.payload });
  assert.equal(res.statusCode, 200);
  assert.match(res.json().text, /2048 bytes/);

  const bad = multipartBody('image/png', Buffer.alloc(10));
  const r415 = await app.inject({ method: 'POST', url: '/v1/video/analyze', headers: { ...auth(), ...bad.headers }, payload: bad.payload });
  assert.equal(r415.statusCode, 415);

  const big = multipartBody('video/mp4', Buffer.alloc(2 * 1024 * 1024, 1));
  const r413 = await app.inject({ method: 'POST', url: '/v1/video/analyze', headers: { ...auth(), ...big.headers }, payload: big.payload });
  assert.equal(r413.statusCode, 413);
});

test('config refuses dev auth or fake providers in production, and needs keys', () => {
  assert.throws(() => loadConfig({ NODE_ENV: 'production', DEV_AUTH: '1', PROVIDERS: 'fake' }));
  assert.throws(() => loadConfig({ NODE_ENV: 'production' }), /API_KEY/);
  assert.doesNotThrow(() => loadConfig({ DEV_AUTH: '1', PROVIDERS: 'fake' }));
});

test('real providers parse Anthropic and Gemini responses', async () => {
  const calls: string[] = [];
  const fakeFetch = (async (url: string) => {
    calls.push(String(url));
    if (String(url).includes('anthropic')) {
      return new Response(JSON.stringify({ content: [{ type: 'text', text: 'reja' }], usage: { input_tokens: 10, output_tokens: 5 } }));
    }
    return new Response(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: 'tahlil' }, { inlineData: { mimeType: 'image/png', data: 'AAA' } }] } }],
        usageMetadata: { promptTokenCount: 7, candidatesTokenCount: 3 },
      }),
    );
  }) as typeof fetch;
  const p = new RealProviders(
    { anthropicKey: 'a', geminiKey: 'g', claudeModel: 'claude-sonnet-5-5', geminiTextModel: 'gm', geminiImageModel: 'gi' },
    fakeFetch,
  );
  assert.deepEqual(await p.complete({ system: 's', messages: [{ role: 'user', content: 'x' }], maxTokens: 10 }), {
    text: 'reja', inputTokens: 10, outputTokens: 5, model: 'claude-sonnet-5-5',
  });
  assert.equal((await p.analyzeVideo({ bytes: Buffer.from('v'), mime: 'video/mp4', prompt: 'p' })).text, 'tahlil');
  assert.equal((await p.generateImage({ prompt: 'p', aspectRatio: '1:1' })).b64, 'AAA');
  assert.ok(calls[1].endsWith('/models/gm:generateContent'));
});

test('provider HTTP errors become ProviderError without the body', async () => {
  const p = new RealProviders(
    { anthropicKey: 'a', geminiKey: 'g', claudeModel: 'c', geminiTextModel: 'gm', geminiImageModel: 'gi' },
    (async () => new Response('secret echo', { status: 500 })) as typeof fetch,
  );
  await assert.rejects(p.complete({ system: 's', messages: [{ role: 'user', content: 'x' }], maxTokens: 10 }), (e: any) => {
    assert.ok(e instanceof ProviderError);
    assert.ok(!String(e.message).includes('secret'));
    return true;
  });
});
