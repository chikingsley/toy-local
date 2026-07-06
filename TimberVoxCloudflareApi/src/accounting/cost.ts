export type UsageUnit = "audio_second" | "token";

export interface UsageAmounts {
  asrSeconds?: number | null;
  inputTokens?: number | null;
  outputTokens?: number | null;
}

export interface ModelPrice {
  inputMicroUsdPerUnit: number | null;
  outputMicroUsdPerUnit: number | null;
  unit: UsageUnit;
}

export const estimateCostMicroUsd = (
  amounts: UsageAmounts,
  price: ModelPrice | null
): number | null => {
  if (!price) {
    return null;
  }

  if (price.unit === "audio_second") {
    if (
      amounts.asrSeconds === undefined ||
      amounts.asrSeconds === null ||
      price.inputMicroUsdPerUnit === null
    ) {
      return null;
    }
    return Math.round(amounts.asrSeconds * price.inputMicroUsdPerUnit);
  }

  const inputCost =
    (amounts.inputTokens ?? 0) * (price.inputMicroUsdPerUnit ?? 0);
  const outputCost =
    (amounts.outputTokens ?? 0) * (price.outputMicroUsdPerUnit ?? 0);
  const total = inputCost + outputCost;
  return total > 0 ? Math.round(total) : null;
};
