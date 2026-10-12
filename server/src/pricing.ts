/**
 * Cost model. USD per 1M tokens, kept here (one place) and overridable by
 * env so prices can follow the providers without code changes.
 * 1 credit = $0.01. These defaults are estimates; verify against the
 * providers' current price lists before launch.
 */
export interface ModelPrice {
  inputPerM: number;
  outputPerM: number;
}

export const DEFAULT_PRICES: Record<string, ModelPrice> = {
  'claude-sonnet-5-5': { inputPerM: 2, outputPerM: 10 },
  'gemini-3.8-flash': { inputPerM: 0.75, outputPerM: 3 },
};

/** Flat price for one generated image, in credits. */
export const IMAGE_CREDITS = 5;

/** Minimum balance required before starting a call (protects against overdraft). */
export const MIN_CREDITS_TO_START = 1;

export function creditsFor(
  model: string,
  inputTokens: number,
  outputTokens: number,
  prices: Record<string, ModelPrice> = DEFAULT_PRICES,
): number {
  const p = prices[model] ?? { inputPerM: 3, outputPerM: 15 }; // conservative fallback
  const usd = (inputTokens * p.inputPerM + outputTokens * p.outputPerM) / 1_000_000;
  return Math.max(1, Math.ceil(usd * 100));
}
