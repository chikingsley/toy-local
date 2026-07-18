import {
  LANGUAGE_MODELS,
  SUPERWHISPER_OBSERVED_CONTRACT,
  VOICE_MODELS,
} from "@chikingsley/superwhisper-provider";
import { describe, expect, it } from "vitest";

import { providerInventoryAdapters } from "../../src/ai/model-inventory/adapters";
import { compareCatalogToInventory } from "../../src/ai/model-inventory/compare";
import { publicModelCatalog } from "../../src/ai/models/catalog";
import { LANGUAGE_MODEL_MAP } from "../../src/ai/models/language-models";
import {
  BATCH_ASR_MODEL_MAP,
  REALTIME_ASR_MODEL_MAP,
} from "../../src/ai/models/transcription-routes";

const sorted = (values: Iterable<string>): string[] => [...values].sort();

describe("Superwhisper provider contract", () => {
  it("is pinned to the promoted Superwhisper 2.16.4 observation", () => {
    expect(SUPERWHISPER_OBSERVED_CONTRACT).toEqual({
      app: {
        binarySha256:
          "99b50838fb5960860cfafb6a4ba282609a3d5e7d368a3e959116ed9d21058ac3",
        name: "superwhisper",
        version: "2.16.4",
      },
      generatedFrom: "2026-07-18",
      kind: "superwhisper_observed_contract_public_manifest",
      schemaVersion: 1,
    });
  });

  it("routes every observed language model through the pinned provider", () => {
    const routedModels = Object.values(LANGUAGE_MODEL_MAP)
      .filter((route) => route.executionProvider === "superwhisper")
      .map((route) => route.executionModel);
    const observedModels = LANGUAGE_MODELS.filter(
      (model) => model.observedInventory && model.observedStatus === 200
    ).map((model) => model.key);

    expect(sorted(routedModels)).toEqual(sorted(observedModels));
  });

  it("routes every observed batch and realtime ASR model", () => {
    const batchModels = Object.values(BATCH_ASR_MODEL_MAP)
      .filter((route) => route.executionProvider === "superwhisper")
      .map((route) => route.executionModel);
    const realtimeModels = Object.values(REALTIME_ASR_MODEL_MAP)
      .filter((route) => route.executionProvider === "superwhisper")
      .map((route) => route.executionModel);

    expect(sorted(batchModels)).toEqual(
      sorted(
        VOICE_MODELS.filter((model) => model.observedBatch).map(
          (model) => model.key
        )
      )
    );
    expect(sorted(realtimeModels)).toEqual(
      sorted(
        VOICE_MODELS.filter((model) => model.observedRealtime).map(
          (model) => model.key
        )
      )
    );
  });

  it("keeps public route identity separate from execution identity", () => {
    expect(LANGUAGE_MODEL_MAP["anthropic-claude-sonnet-5"]).toMatchObject({
      executionModel: "claude-sonnet-5",
      executionProvider: "superwhisper",
      provider: "anthropic",
      upstreamModel: "claude-sonnet-5",
    });
    expect(BATCH_ASR_MODEL_MAP["deepgram-nova-3"]).toMatchObject({
      executionModel: "sw-deepgram-nova-3",
      executionProvider: "superwhisper",
      provider: "deepgram",
      upstreamModel: "nova-3",
    });
    expect(REALTIME_ASR_MODEL_MAP["deepgram-nova-3"]).toMatchObject({
      executionModel: "sw-deepgram-nova-3",
      executionProvider: "superwhisper",
      provider: "deepgram",
      upstreamModel: "nova-3",
    });
    expect(
      VOICE_MODELS.find((model) => model.key === "sw-deepgram-nova-3")
    ).toMatchObject({
      realtimeRequestModel: "nova-2",
      requestModel: "nova-3",
    });
  });

  it("feeds execution routes into the TimberVox drift runner", async () => {
    const adapter = providerInventoryAdapters.find(
      (candidate) => candidate.provider === "superwhisper"
    );
    expect(adapter).toBeDefined();
    if (!adapter) {
      return;
    }
    const source = await adapter.list({
      env: {} as never,
      fetch,
      now: new Date("2026-07-18T12:00:00.000Z"),
    });
    const drift = compareCatalogToInventory(publicModelCatalog(), [source]);

    expect(source).toMatchObject({
      provider: "superwhisper",
      sourceKind: "contract",
      status: "ok",
    });
    expect(
      drift.catalogModelsWithoutProviderMatch.filter(
        (model) => model.provider === "superwhisper"
      )
    ).toEqual([]);
    expect(
      drift.providerModelsNotInCatalog.filter(
        (model) => model.provider === "superwhisper"
      )
    ).toEqual([]);
  });

  it("leaves direct Mistral and Voxtral routes on Mistral", () => {
    expect(LANGUAGE_MODEL_MAP["mistral-mistral-small-latest"]).toMatchObject({
      executionProvider: "mistral",
    });
    expect(BATCH_ASR_MODEL_MAP["mistral-voxtral-mini-latest"]).toMatchObject({
      executionProvider: "mistral",
    });
    expect(
      REALTIME_ASR_MODEL_MAP["mistral-voxtral-mini-transcribe-realtime-2602"]
    ).toMatchObject({ executionProvider: "mistral" });
  });
});
