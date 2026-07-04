export interface MistralConfig {
  apiKey: string;
  baseUrl?: string;
  fetch?: typeof fetch;
  headers?: Record<string, string | undefined>;
  provider: string;
}

const MISTRAL_BASE_URL = "https://api.mistral.ai";
const LEADING_SLASHES = /^\/+/;
const TRAILING_SLASHES = /\/+$/;

export const mistralUrl = (
  config: Pick<MistralConfig, "baseUrl">,
  path: string
): URL => {
  const baseUrl = new URL(config.baseUrl ?? MISTRAL_BASE_URL);
  baseUrl.pathname = baseUrl.pathname.replace(TRAILING_SLASHES, "/");
  return new URL(path.replace(LEADING_SLASHES, ""), baseUrl);
};

export const mistralHeaders = (
  config: Pick<MistralConfig, "apiKey" | "headers">,
  headers?: Record<string, string | undefined>
): Headers => {
  const result = new Headers();
  result.set("authorization", `Bearer ${config.apiKey}`);

  for (const [key, value] of Object.entries(config.headers ?? {})) {
    if (value !== undefined) {
      result.set(key, value);
    }
  }

  for (const [key, value] of Object.entries(headers ?? {})) {
    if (value !== undefined) {
      result.set(key, value);
    }
  }

  return result;
};
