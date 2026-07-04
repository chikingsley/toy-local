export class TransientProviderError extends Error {
  readonly retryDelaySeconds: number;

  constructor(message: string, retryDelaySeconds: number) {
    super(message);
    this.name = "TransientProviderError";
    this.retryDelaySeconds = retryDelaySeconds;
  }
}

const permanentMessagePatterns = [
  "empty body",
  "input object not found",
  "invalid request",
  "missing api key",
  "unsupported",
] as const;

const transientMessagePatterns = [
  "429",
  "connection reset",
  "econnreset",
  "fetch failed",
  "network",
  "overloaded",
  "rate limit",
  "temporarily",
  "timeout",
] as const;

const statusFromError = (error: unknown): number | null => {
  if (typeof error !== "object" || error === null) {
    return null;
  }
  for (const key of ["status", "statusCode", "status_code"]) {
    if (key in error) {
      const value = Number(error[key as keyof typeof error]);
      if (Number.isInteger(value)) {
        return value;
      }
    }
  }
  if ("response" in error) {
    return statusFromError(error.response);
  }
  return null;
};

const messageFromError = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

export const isTransientProviderError = (error: unknown): boolean => {
  const status = statusFromError(error);
  if (status !== null) {
    return (
      status === 408 ||
      status === 409 ||
      status === 425 ||
      status === 429 ||
      status >= 500
    );
  }

  const message = messageFromError(error).toLowerCase();
  if (permanentMessagePatterns.some((pattern) => message.includes(pattern))) {
    return false;
  }
  return transientMessagePatterns.some((pattern) => message.includes(pattern));
};

export const retryDelaySeconds = (attempts: number): number => {
  const attempt = Math.max(1, attempts);
  return Math.min(60 * 2 ** (attempt - 1), 900);
};

export const providerErrorMessage = (error: unknown): string =>
  messageFromError(error);
