import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';
import multipart from '@fastify/multipart';
import { z } from 'zod';

import { AuthError, type TokenVerifier } from './auth.ts';
import type { CreditStore } from './credits.ts';
import { IMAGE_CREDITS, MIN_CREDITS_TO_START, creditsFor } from './pricing.ts';
import { ProviderError, type Providers } from './providers.ts';

export interface AppDeps {
  verifier: TokenVerifier;
  credits: CreditStore;
  providers: Providers;
  rateLimitPerMinute: number;
  maxVideoBytes: number;
  logger?: boolean;
}

/** Same prompt the app used client-side, now kept on the server. */
export const VIDEO_PROMPT =
  'Analyze this video as a professional video editor. Report precisely: total duration; every ' +
  'shot with start/end timestamps in seconds; camera movement and framing per shot; transitions ' +
  'and cut rhythm; on-screen text; speech (transcribe key lines with timestamps); music and sound ' +
  'effects; color grading and visual style; the strongest usable moments. Be factual and only ' +
  'describe what is really in the video.';

const completeBody = z.object({
  system: z.string().max(20_000),
  messages: z
    .array(z.object({ role: z.enum(['user', 'assistant']), content: z.string().max(200_000) }))
    .min(1)
    .max(40),
  maxTokens: z.number().int().min(16).max(8000).default(4000),
});

const imageBody = z.object({
  prompt: z.string().min(1).max(4000),
  aspectRatio: z.enum(['1:1', '9:16', '16:9', '4:5', '3:4']).default('1:1'),
});

const VIDEO_MIME = new Set(['video/mp4', 'video/quicktime', 'video/webm', 'video/mpeg']);

declare module 'fastify' {
  interface FastifyRequest {
    uid?: string;
  }
}

export function buildApp(deps: AppDeps): FastifyInstance {
  const app = Fastify({ logger: deps.logger ?? false, bodyLimit: 1_000_000 });
  app.register(multipart, { limits: { fileSize: deps.maxVideoBytes, files: 1 } });

  // Fixed-window rate limit per user (in-memory; one instance per region is fine for MVP).
  const windows = new Map<string, { start: number; count: number }>();
  const rateLimited = (uid: string): boolean => {
    const now = Date.now();
    const w = windows.get(uid);
    if (!w || now - w.start >= 60_000) {
      windows.set(uid, { start: now, count: 1 });
      return false;
    }
    w.count += 1;
    return w.count > deps.rateLimitPerMinute;
  };

  const fail = (reply: FastifyReply, status: number, code: string, message: string) =>
    reply.code(status).send({ error: { code, message } });

  app.get('/healthz', async () => ({ ok: true }));

  app.addHook('preHandler', async (req: FastifyRequest, reply: FastifyReply) => {
    if (req.url === '/healthz') return;
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) return fail(reply, 401, 'unauthenticated', 'Sign in required');
    try {
      req.uid = (await deps.verifier.verify(token)).uid;
    } catch (e) {
      if (e instanceof AuthError) return fail(reply, 401, 'unauthenticated', 'Invalid session');
      throw e;
    }
    if (rateLimited(req.uid)) return fail(reply, 429, 'rate_limited', 'Too many requests, slow down');
  });

  const requireCredits = (uid: string, reply: FastifyReply, needed = MIN_CREDITS_TO_START): boolean => {
    const balance = deps.credits.balance(uid);
    if (balance < needed) {
      fail(reply, 402, 'insufficient_credits', 'Not enough credits');
      return false;
    }
    return true;
  };

  const providerFailure = (reply: FastifyReply, e: unknown) => {
    if (e instanceof ProviderError) {
      return fail(reply, e.status === 429 ? 503 : 502, 'provider_unavailable', 'AI provider is unavailable, try again');
    }
    throw e;
  };

  app.get('/v1/me', async (req) => ({ uid: req.uid, credits: deps.credits.balance(req.uid!) }));

  app.get('/v1/usage', async (req) => ({ entries: deps.credits.history(req.uid!) }));

  app.post('/v1/complete', async (req, reply) => {
    const parsed = completeBody.safeParse(req.body);
    if (!parsed.success) return fail(reply, 400, 'invalid_request', parsed.error.issues[0]?.message ?? 'invalid');
    const uid = req.uid!;
    if (!requireCredits(uid, reply)) return;
    try {
      const r = await deps.providers.complete(parsed.data);
      const cost = creditsFor(r.model, r.inputTokens, r.outputTokens);
      const credits = deps.credits.apply(uid, {
        delta: -cost,
        reason: 'complete',
        model: r.model,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
      });
      return { text: r.text, usage: { inputTokens: r.inputTokens, outputTokens: r.outputTokens }, cost, credits };
    } catch (e) {
      return providerFailure(reply, e);
    }
  });

  app.post('/v1/video/analyze', async (req, reply) => {
    const uid = req.uid!;
    if (!requireCredits(uid, reply)) return;
    const file = await req.file();
    if (!file) return fail(reply, 400, 'invalid_request', 'video file is required');
    if (!VIDEO_MIME.has(file.mimetype)) return fail(reply, 415, 'unsupported_format', 'Unsupported video format');
    let bytes: Buffer;
    try {
      bytes = await file.toBuffer();
    } catch {
      return fail(reply, 413, 'too_large', 'Video is too large');
    }
    if (file.file.truncated) return fail(reply, 413, 'too_large', 'Video is too large');
    try {
      const r = await deps.providers.analyzeVideo({ bytes, mime: file.mimetype, prompt: VIDEO_PROMPT });
      const cost = creditsFor(r.model, r.inputTokens, r.outputTokens);
      const credits = deps.credits.apply(uid, {
        delta: -cost,
        reason: 'video_analyze',
        model: r.model,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
      });
      return { text: r.text, usage: { inputTokens: r.inputTokens, outputTokens: r.outputTokens }, cost, credits };
    } catch (e) {
      return providerFailure(reply, e);
    }
  });

  app.post('/v1/images', async (req, reply) => {
    const parsed = imageBody.safeParse(req.body);
    if (!parsed.success) return fail(reply, 400, 'invalid_request', parsed.error.issues[0]?.message ?? 'invalid');
    const uid = req.uid!;
    if (!requireCredits(uid, reply, IMAGE_CREDITS)) return;
    try {
      const r = await deps.providers.generateImage(parsed.data);
      const credits = deps.credits.apply(uid, { delta: -IMAGE_CREDITS, reason: 'image', model: r.model });
      return { b64: r.b64, mime: r.mime, cost: IMAGE_CREDITS, credits };
    } catch (e) {
      return providerFailure(reply, e);
    }
  });

  return app;
}
