import { describe, expect, it } from "vitest";

import {
  isTransientProviderError,
  retryDelaySeconds,
} from "../../src/jobs/provider-errors";

describe("provider error classification", () => {
  it("retries rate limits and provider/server failures", () => {
    expect(isTransientProviderError({ status: 429 })).toBe(true);
    expect(isTransientProviderError({ statusCode: 503 })).toBe(true);
    expect(isTransientProviderError(new Error("fetch failed"))).toBe(true);
  });

  it("does not retry permanent local request failures", () => {
    expect(isTransientProviderError(new Error("unsupported model"))).toBe(
      false
    );
    expect(isTransientProviderError(new Error("missing API key"))).toBe(false);
    expect(isTransientProviderError(new Error("input object not found"))).toBe(
      false
    );
  });

  it("backs off retries without exceeding the queue delay ceiling", () => {
    expect(retryDelaySeconds(1)).toBe(60);
    expect(retryDelaySeconds(2)).toBe(120);
    expect(retryDelaySeconds(10)).toBe(900);
  });
});
