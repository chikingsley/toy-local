import {
  LANGUAGE_MODELS,
  SUPERWHISPER_OBSERVED_CONTRACT,
  VOICE_MODELS,
} from "@chikingsley/superwhisper-provider";

import type { Env } from "../../bindings";
import type { AsrTransport, PublicModelKind } from "../models/types";
import type {
  ProviderInventoryAdapter,
  ProviderInventoryContext,
  ProviderInventoryModel,
  ProviderInventoryProviderId,
  ProviderInventorySource,
} from "./types";

type ModelNormalizer = (body: unknown) => readonly ProviderInventoryModel[];

const geminiModelResourcePrefix = /^models\//;

interface ApiAdapterInput {
  apiKey: (env: Env) => string | undefined;
  headers: (apiKey: string) => HeadersInit;
  normalize: ModelNormalizer;
  provider: ProviderInventoryProviderId;
  url: (apiKey: string) => string;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const stringField = (
  record: Record<string, unknown>,
  key: string
): string | undefined =>
  typeof record[key] === "string" ? (record[key] as string) : undefined;

const arrayField = (record: Record<string, unknown>, key: string): unknown[] =>
  Array.isArray(record[key]) ? record[key] : [];

const uniqueModels = (
  models: readonly ProviderInventoryModel[]
): readonly ProviderInventoryModel[] => {
  // Providers can list the same model several times (e.g. Deepgram has
  // separate batch and streaming entries per name); merge transports
  // instead of dropping the duplicates.
  const byUpstreamModel = new Map<string, ProviderInventoryModel>();
  for (const model of models) {
    const existing = byUpstreamModel.get(model.upstreamModel);
    if (!existing) {
      byUpstreamModel.set(model.upstreamModel, model);
      continue;
    }
    if (model.transports?.length) {
      const transports = [
        ...new Set([...(existing.transports ?? []), ...model.transports]),
      ];
      byUpstreamModel.set(model.upstreamModel, { ...existing, transports });
    }
  }
  return [...byUpstreamModel.values()];
};

const source =
  (
    input: Omit<ProviderInventorySource, "checkedAt">
  ): ((context: ProviderInventoryContext) => ProviderInventorySource) =>
  (context) => ({ checkedAt: context.now.toISOString(), ...input });

const apiAdapter = (input: ApiAdapterInput): ProviderInventoryAdapter => ({
  list: async (context) => {
    const apiKey = input.apiKey(context.env);
    const url = input.url(apiKey ?? "");
    if (!apiKey) {
      return source({
        models: [],
        provider: input.provider,
        reason: "provider API key is not configured",
        sourceKind: "api",
        status: "skipped",
        url,
      })(context);
    }

    try {
      const response = await context.fetch(url, {
        headers: input.headers(apiKey),
      });
      if (!response.ok) {
        return source({
          models: [],
          provider: input.provider,
          reason: `provider returned ${response.status}`,
          sourceKind: "api",
          status: "failed",
          url,
        })(context);
      }

      const body = (await response.json()) as unknown;
      return source({
        models: uniqueModels(input.normalize(body)),
        provider: input.provider,
        sourceKind: "api",
        status: "ok",
        url,
      })(context);
    } catch (error) {
      return source({
        models: [],
        provider: input.provider,
        reason: error instanceof Error ? error.message : String(error),
        sourceKind: "api",
        status: "failed",
        url,
      })(context);
    }
  },
  provider: input.provider,
});

const bearerHeaders = (apiKey: string): HeadersInit => ({
  authorization: `Bearer ${apiKey}`,
});

const jsonBearerHeaders = (apiKey: string): HeadersInit => ({
  ...bearerHeaders(apiKey),
  "content-type": "application/json",
});

const normalizeDataList =
  (
    kind: PublicModelKind | ((id: string) => PublicModelKind | undefined),
    transports?:
      | readonly AsrTransport[]
      | ((id: string) => readonly AsrTransport[] | undefined)
  ): ModelNormalizer =>
  (body) => {
    const data = isRecord(body) ? arrayField(body, "data") : [];
    return data.flatMap((item) => {
      if (!isRecord(item)) {
        return [];
      }
      const id = stringField(item, "id");
      if (!id) {
        return [];
      }
      const resolvedKind = typeof kind === "function" ? kind(id) : kind;
      if (!resolvedKind) {
        return [];
      }
      const resolvedTransports =
        typeof transports === "function" ? transports(id) : transports;
      return [
        {
          displayName: stringField(item, "display_name"),
          kind: resolvedKind,
          transports: resolvedTransports,
          upstreamModel: id,
        },
      ];
    });
  };

const groqModelKind = (id: string): PublicModelKind =>
  id.includes("whisper") ? "transcription" : "language";

const groqTransports = (id: string): readonly AsrTransport[] | undefined =>
  id.includes("whisper") ? ["batch"] : undefined;

const mistralModelKind = (id: string): PublicModelKind =>
  id.startsWith("voxtral") ? "transcription" : "language";

const mistralTransports = (id: string): readonly AsrTransport[] | undefined => {
  if (id.includes("realtime")) {
    return ["realtime"];
  }
  if (id.startsWith("voxtral")) {
    return ["batch"];
  }
};

const normalizeGeminiModels: ModelNormalizer = (body) => {
  const models = isRecord(body) ? arrayField(body, "models") : [];
  return models.flatMap((item) => {
    if (!isRecord(item)) {
      return [];
    }
    // The live v1beta ListModels response calls this field
    // supportedGenerationMethods; older docs used supportedActions.
    const supportedActions = [
      ...arrayField(item, "supportedGenerationMethods"),
      ...arrayField(item, "supportedActions"),
    ];
    if (!supportedActions.includes("generateContent")) {
      return [];
    }
    const upstreamModel =
      stringField(item, "baseModelId") ??
      stringField(item, "name")?.replace(geminiModelResourcePrefix, "");
    if (!upstreamModel) {
      return [];
    }
    return [
      {
        displayName: stringField(item, "displayName"),
        kind: "language" as const,
        upstreamModel,
      },
    ];
  });
};

const normalizeDeepgramModels: ModelNormalizer = (body) => {
  const sttModels = isRecord(body) ? arrayField(body, "stt") : [];
  return sttModels.flatMap((item) => {
    if (!isRecord(item)) {
      return [];
    }
    const upstreamModel =
      stringField(item, "canonical_name") ?? stringField(item, "name");
    if (!upstreamModel) {
      return [];
    }
    const transports: AsrTransport[] = [];
    if (item.batch === true) {
      transports.push("batch");
    }
    if (item.streaming === true) {
      transports.push("realtime");
    }
    const entry = {
      displayName: stringField(item, "name"),
      kind: "transcription" as const,
      transports,
      upstreamModel,
    };
    // Deepgram's transcribe API accepts family aliases like "nova-2"
    // (resolving to the "-general" variant), but /v1/models only lists
    // the fully-qualified names.
    if (upstreamModel.endsWith("-general")) {
      return [
        entry,
        {
          ...entry,
          upstreamModel: upstreamModel.slice(0, -"-general".length),
        },
      ];
    }
    return [entry];
  });
};

const normalizeElevenLabsModels: ModelNormalizer = (body) => {
  const models = Array.isArray(body) ? body : [];
  return models.flatMap((item) => {
    if (!isRecord(item)) {
      return [];
    }
    const upstreamModel = stringField(item, "model_id");
    if (!upstreamModel?.startsWith("scribe")) {
      return [];
    }
    return [
      {
        displayName: stringField(item, "name"),
        kind: "transcription" as const,
        transports: upstreamModel.includes("realtime")
          ? ["realtime"]
          : ["batch"],
        upstreamModel,
      },
    ];
  });
};

const manualAdapter = (
  provider: ProviderInventoryProviderId,
  reason: string,
  models: readonly ProviderInventoryModel[],
  url?: string
): ProviderInventoryAdapter => ({
  list: async (context) =>
    source({
      models,
      provider,
      reason,
      sourceKind: "manual",
      status: "ok",
      url,
    })(context),
  provider,
});

const superwhisperContractAdapter: ProviderInventoryAdapter = {
  list: (context) => {
    const languageModels: ProviderInventoryModel[] = LANGUAGE_MODELS.filter(
      (model) => model.observedInventory && model.observedStatus === 200
    ).map((model) => ({
      kind: "language",
      upstreamModel: model.key,
    }));
    const voiceModels: ProviderInventoryModel[] = VOICE_MODELS.flatMap(
      (model) => {
        const transports: AsrTransport[] = [];
        if (model.observedBatch) {
          transports.push("batch");
        }
        if (model.observedRealtime) {
          transports.push("realtime");
        }
        return transports.length > 0
          ? [
              {
                kind: "transcription" as const,
                transports,
                upstreamModel: model.key,
              },
            ]
          : [];
      }
    );
    return Promise.resolve(
      source({
        models: [...languageModels, ...voiceModels],
        provider: "superwhisper",
        reason: `Observed Superwhisper ${SUPERWHISPER_OBSERVED_CONTRACT.app.version} contract from ${SUPERWHISPER_OBSERVED_CONTRACT.generatedFrom} (${SUPERWHISPER_OBSERVED_CONTRACT.app.binarySha256})`,
        sourceKind: "contract",
        status: "ok",
      })(context)
    );
  },
  provider: "superwhisper",
};

export const providerInventoryAdapters: readonly ProviderInventoryAdapter[] = [
  superwhisperContractAdapter,
  apiAdapter({
    apiKey: (env) => env.OPENAI_API_KEY,
    headers: bearerHeaders,
    normalize: normalizeDataList("language"),
    provider: "openai",
    url: () => "https://api.openai.com/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.ANTHROPIC_API_KEY,
    headers: (apiKey) => ({
      "anthropic-version": "2023-06-01",
      "x-api-key": apiKey,
    }),
    normalize: normalizeDataList("language"),
    provider: "anthropic",
    url: () => "https://api.anthropic.com/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.GOOGLE_GENERATIVE_AI_API_KEY,
    headers: () => ({}),
    normalize: normalizeGeminiModels,
    provider: "google",
    url: (apiKey) =>
      `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`,
  }),
  apiAdapter({
    apiKey: (env) => env.MISTRAL_API_KEY,
    headers: bearerHeaders,
    normalize: normalizeDataList(mistralModelKind, mistralTransports),
    provider: "mistral",
    url: () => "https://api.mistral.ai/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.GROQ_API_KEY,
    headers: jsonBearerHeaders,
    normalize: normalizeDataList(groqModelKind, groqTransports),
    provider: "groq",
    url: () => "https://api.groq.com/openai/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.DEEPSEEK_API_KEY,
    headers: bearerHeaders,
    normalize: normalizeDataList("language"),
    provider: "deepseek",
    url: () => "https://api.deepseek.com/models",
  }),
  apiAdapter({
    apiKey: (env) => env.CEREBRAS_API_KEY,
    headers: bearerHeaders,
    normalize: normalizeDataList("language"),
    provider: "cerebras",
    url: () => "https://api.cerebras.ai/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.DEEPGRAM_API_KEY,
    headers: (apiKey) => ({ authorization: `Token ${apiKey}` }),
    normalize: normalizeDeepgramModels,
    provider: "deepgram",
    url: () => "https://api.deepgram.com/v1/models",
  }),
  apiAdapter({
    apiKey: (env) => env.ELEVENLABS_API_KEY,
    headers: (apiKey) => ({ "xi-api-key": apiKey }),
    normalize: normalizeElevenLabsModels,
    provider: "elevenlabs",
    url: () => "https://api.elevenlabs.io/v1/models",
  }),
  manualAdapter(
    "zai",
    "Z.AI OpenAPI exposes model enums and pricing docs, but no model-list endpoint.",
    [
      {
        kind: "language",
        upstreamModel: "glm-5.2",
      },
      {
        kind: "language",
        upstreamModel: "glm-5.1",
      },
      {
        kind: "language",
        upstreamModel: "glm-5-turbo",
      },
      {
        kind: "language",
        upstreamModel: "glm-5",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.7",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.7-flash",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.7-flashx",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.6",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.5",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.5-air",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.5-x",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.5-airx",
      },
      {
        kind: "language",
        upstreamModel: "glm-4.5-flash",
      },
      {
        kind: "language",
        upstreamModel: "glm-4-32b-0414-128k",
      },
    ],
    "https://docs.z.ai/guides/overview/pricing#models"
  ),
];
