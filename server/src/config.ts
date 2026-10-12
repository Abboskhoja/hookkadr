/** Runtime configuration. Secrets only come from the environment. */
export interface Config {
  port: number;
  production: boolean;
  /** Accept `dev:<uid>` bearer tokens (local development only). */
  devAuth: boolean;
  /** `fake` returns clearly-labelled canned output (local wiring tests only). */
  providers: 'real' | 'fake';
  anthropicKey?: string;
  geminiKey?: string;
  claudeModel: string;
  geminiTextModel: string;
  geminiImageModel: string;
  dbPath: string;
  /** Credits granted once to every new account. 1 credit = $0.01 of AI cost. */
  freeCredits: number;
  /** Requests per user per minute. */
  rateLimitPerMinute: number;
  maxVideoBytes: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const production = env.NODE_ENV === 'production';
  const config: Config = {
    port: Number(env.PORT ?? 8080),
    production,
    devAuth: env.DEV_AUTH === '1',
    providers: env.PROVIDERS === 'fake' ? 'fake' : 'real',
    anthropicKey: env.ANTHROPIC_API_KEY,
    geminiKey: env.GEMINI_API_KEY,
    claudeModel: env.CLAUDE_MODEL ?? 'claude-sonnet-5-5',
    geminiTextModel: env.GEMINI_TEXT_MODEL ?? 'gemini-3.8-flash',
    geminiImageModel: env.GEMINI_IMAGE_MODEL ?? 'gemini-3.1-flash-image',
    dbPath: env.DB_PATH ?? 'hookkadr.db',
    freeCredits: Number(env.FREE_CREDITS ?? 50),
    rateLimitPerMinute: Number(env.RATE_LIMIT_PER_MINUTE ?? 30),
    maxVideoBytes: Number(env.MAX_VIDEO_BYTES ?? 18 * 1024 * 1024),
  };
  if (production && (config.devAuth || config.providers === 'fake')) {
    throw new Error('DEV_AUTH and PROVIDERS=fake are not allowed in production');
  }
  if (config.providers === 'real' && (!config.anthropicKey || !config.geminiKey)) {
    throw new Error('ANTHROPIC_API_KEY and GEMINI_API_KEY are required (or PROVIDERS=fake for local dev)');
  }
  return config;
}
