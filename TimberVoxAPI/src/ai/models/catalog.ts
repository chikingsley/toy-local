import { LANGUAGE_MODEL_MAP } from "./language-models";
import {
  BATCH_ASR_MODEL_MAP,
  REALTIME_ASR_MODEL_MAP,
} from "./transcription-routes";
import type {
  AcceptedAsrOptionName,
  AsrTransport,
  PublicAsrRouteSpec,
  PublicModelSpec,
  PublicTranscriptionModelSpec,
} from "./types";

const REALTIME_PUBLIC_MODEL_ID_BY_ROUTE_ID: Record<string, string> = {
  "mistral-voxtral-mini-transcribe-realtime-2602":
    "mistral-voxtral-mini-latest",
};

const publicRealtimeModelId = (routeId: string): string =>
  REALTIME_PUBLIC_MODEL_ID_BY_ROUTE_ID[routeId] ?? routeId;

const mergeUnique = <T>(values: readonly T[]): T[] =>
  Array.from(new Set(values));

const copy = <T>(values: readonly T[]): T[] => [...values];

const supportsDiarization = (options: readonly string[]): boolean =>
  options.some((option) => option === "diarize");

const mergeOptions = (
  existing: PublicTranscriptionModelSpec["acceptedOptions"],
  transport: AsrTransport,
  options: readonly AcceptedAsrOptionName[]
): PublicTranscriptionModelSpec["acceptedOptions"] => ({
  ...existing,
  [transport]: [...options],
});

const mergeTransports = (
  existing: readonly AsrTransport[] | undefined,
  transport: AsrTransport
): AsrTransport[] => mergeUnique([...(existing ?? []), transport]);

const mergeSupportedLanguages = (
  existing: readonly string[],
  next: readonly string[]
): string[] => mergeUnique([...existing, ...next]);

const mergeRoutes = (
  existing: PublicTranscriptionModelSpec["routes"],
  transport: AsrTransport,
  route: PublicAsrRouteSpec
): PublicTranscriptionModelSpec["routes"] => ({
  ...existing,
  [transport]: route,
});

export const publicModelCatalog = (): PublicModelSpec[] => {
  const models = new Map<string, PublicModelSpec>();

  for (const [id, model] of Object.entries(LANGUAGE_MODEL_MAP)) {
    models.set(id, {
      id,
      kind: "language",
      provider: model.provider,
      upstreamModel: model.upstreamModel,
    });
  }

  for (const [id, model] of Object.entries(BATCH_ASR_MODEL_MAP)) {
    const { acceptedOptions } = model;
    models.set(id, {
      acceptedOptions: {
        batch: acceptedOptions,
      },
      id,
      kind: "transcription",
      provider: model.provider,
      routes: {
        batch: {
          acceptedOptions,
          model: id,
          provider: model.provider,
          supportedLanguages: copy(model.supportedLanguages),
          supportsAutomaticLanguage: model.supportsAutomaticLanguage,
          supportsDiarization: supportsDiarization(acceptedOptions),
          upstreamModel: model.upstreamModel,
        },
      },
      supportedLanguages: copy(model.supportedLanguages),
      transports: ["batch"],
      upstreamModel: model.upstreamModel,
    });
  }

  for (const [id, model] of Object.entries(REALTIME_ASR_MODEL_MAP)) {
    const publicId = publicRealtimeModelId(id);
    const existing = models.get(publicId);
    const { acceptedOptions } = model;
    const realtimeRoute: PublicAsrRouteSpec = {
      acceptedOptions,
      model: id,
      provider: model.provider,
      supportedLanguages: copy(model.supportedLanguages),
      supportsAutomaticLanguage: model.supportsAutomaticLanguage,
      supportsDiarization: supportsDiarization(acceptedOptions),
      upstreamModel: model.upstreamModel,
    };
    if (existing?.kind === "transcription") {
      models.set(publicId, {
        ...existing,
        acceptedOptions: mergeOptions(
          existing.acceptedOptions,
          "realtime",
          acceptedOptions
        ),
        routes: mergeRoutes(existing.routes, "realtime", realtimeRoute),
        supportedLanguages: mergeSupportedLanguages(
          existing.supportedLanguages,
          model.supportedLanguages
        ),
        transports: mergeTransports(existing.transports, "realtime"),
      });
      continue;
    }

    models.set(publicId, {
      acceptedOptions: {
        realtime: acceptedOptions,
      },
      id: publicId,
      kind: "transcription",
      provider: model.provider,
      routes: {
        realtime: realtimeRoute,
      },
      supportedLanguages: copy(model.supportedLanguages),
      transports: ["realtime"],
      upstreamModel: model.upstreamModel,
    });
  }

  return Array.from(models.values()).sort((left, right) =>
    left.id.localeCompare(right.id)
  );
};
