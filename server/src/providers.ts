export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface TextResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
  model: string;
}

export interface Providers {
  complete(input: { system: string; messages: ChatMessage[]; maxTokens: number }): Promise<TextResult>;
  analyzeVideo(input: { bytes: Buffer; mime: string; prompt: string }): Promise<TextResult>;
  generateImage(input: { prompt: string; aspectRatio: string }): Promise<{ b64: string; mime: string; model: string }>;
}

export class ProviderError extends Error {
  readonly status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

type Fetch = typeof fetch;

async function json(res: Response, who: string): Promise<any> {
  if (!res.ok) {
    // Never forward provider bodies (may echo request data); log server-side only.
    throw new ProviderError(`${who} error ${res.status}`, res.status === 429 ? 429 : 502);
  }
  return res.json();
}

/** Real providers: Anthropic for text, Gemini for video understanding and images. */
export class RealProviders implements Providers {
  private readonly cfg: {
    anthropicKey: string;
    geminiKey: string;
    claudeModel: string;
    geminiTextModel: string;
    geminiImageModel: string;
  };
  private readonly fetch: Fetch;

  constructor(cfg: RealProviders['cfg'], fetchImpl: Fetch = fetch) {
    this.cfg = cfg;
    this.fetch = fetchImpl;
  }

  async complete({ system, messages, maxTokens }: { system: string; messages: ChatMessage[]; maxTokens: number }) {
    const body = await json(
      await this.fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'x-api-key': this.cfg.anthropicKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: JSON.stringify({ model: this.cfg.claudeModel, max_tokens: maxTokens, system, messages }),
        signal: AbortSignal.timeout(120_000),
      }),
      'Claude',
    );
    const text = (body.content ?? [])
      .filter((b: any) => b.type === 'text')
      .map((b: any) => b.text)
      .join('');
    return {
      text,
      inputTokens: body.usage?.input_tokens ?? 0,
      outputTokens: body.usage?.output_tokens ?? 0,
      model: this.cfg.claudeModel,
    };
  }

  private geminiUrl(model: string) {
    return `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  }

  async analyzeVideo({ bytes, mime, prompt }: { bytes: Buffer; mime: string; prompt: string }) {
    const body = await json(
      await this.fetch(this.geminiUrl(this.cfg.geminiTextModel), {
        method: 'POST',
        headers: { 'x-goog-api-key': this.cfg.geminiKey, 'content-type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ inline_data: { mime_type: mime, data: bytes.toString('base64') } }, { text: prompt }] }],
        }),
        signal: AbortSignal.timeout(240_000),
      }),
      'Gemini',
    );
    const text = (body.candidates?.[0]?.content?.parts ?? []).map((p: any) => p.text ?? '').join('');
    if (!text.trim()) throw new ProviderError('Gemini returned no analysis', 502);
    return {
      text,
      inputTokens: body.usageMetadata?.promptTokenCount ?? 0,
      outputTokens: body.usageMetadata?.candidatesTokenCount ?? 0,
      model: this.cfg.geminiTextModel,
    };
  }

  async generateImage({ prompt, aspectRatio }: { prompt: string; aspectRatio: string }) {
    const body = await json(
      await this.fetch(this.geminiUrl(this.cfg.geminiImageModel), {
        method: 'POST',
        headers: { 'x-goog-api-key': this.cfg.geminiKey, 'content-type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseModalities: ['TEXT', 'IMAGE'], imageConfig: { aspectRatio } },
        }),
        signal: AbortSignal.timeout(120_000),
      }),
      'Gemini',
    );
    for (const p of body.candidates?.[0]?.content?.parts ?? []) {
      const d = p.inlineData ?? p.inline_data;
      if (d?.data) return { b64: d.data, mime: d.mimeType ?? d.mime_type ?? 'image/png', model: this.cfg.geminiImageModel };
    }
    throw new ProviderError('No image returned (request may have been refused)', 502);
  }
}

/** Local wiring tests only. Every output is visibly marked as fake. */
export class FakeProviders implements Providers {
  async complete({ messages }: { messages: ChatMessage[] }) {
    const last = messages[messages.length - 1]?.content ?? '';
    return { text: `[DEV FAKE] ${last.slice(0, 80)}`, inputTokens: 120, outputTokens: 40, model: 'fake' };
  }
  async analyzeVideo({ bytes }: { bytes: Buffer }) {
    return { text: `[DEV FAKE] video of ${bytes.length} bytes`, inputTokens: 300, outputTokens: 60, model: 'fake' };
  }
  async generateImage() {
    // 1x1 transparent PNG
    return {
      b64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      mime: 'image/png',
      model: 'fake',
    };
  }
}
