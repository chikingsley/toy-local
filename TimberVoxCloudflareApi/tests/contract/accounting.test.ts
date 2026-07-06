import { describe, expect, it } from "vitest";

import { estimateCostMicroUsd } from "../../src/accounting/cost";

describe("usage cost accounting", () => {
  it("estimates ASR cost from audio seconds when a model price is configured", () => {
    expect(
      estimateCostMicroUsd(
        { asrSeconds: 12.5 },
        {
          inputMicroUsdPerUnit: 2,
          outputMicroUsdPerUnit: null,
          unit: "audio_second",
        }
      )
    ).toBe(25);
  });

  it("estimates LLM cost from input and output tokens", () => {
    expect(
      estimateCostMicroUsd(
        { inputTokens: 1000, outputTokens: 250 },
        {
          inputMicroUsdPerUnit: 0.25,
          outputMicroUsdPerUnit: 2,
          unit: "token",
        }
      )
    ).toBe(750);
  });

  it("does not estimate cost without an explicit model price", () => {
    expect(estimateCostMicroUsd({ inputTokens: 1000 }, null)).toBeNull();
  });
});
