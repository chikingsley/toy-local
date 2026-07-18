import type { PublicModelSpec } from "../models/types";
import type {
  CatalogModelWithoutProviderMatch,
  ProviderInventoryDrift,
  ProviderInventoryModel,
  ProviderInventoryProviderId,
  ProviderInventorySource,
} from "./types";

interface CatalogProviderRoute {
  id: string;
  kind: PublicModelSpec["kind"];
  provider: ProviderInventoryProviderId;
  transport?: "batch" | "realtime";
  upstreamModel: string;
}

const catalogProviderRoutes = (
  model: PublicModelSpec
): CatalogProviderRoute[] => {
  if (model.kind !== "transcription" || !model.routes) {
    return [
      {
        id: model.id,
        kind: model.kind,
        provider: model.executionProvider,
        upstreamModel: model.executionModel,
      },
    ];
  }

  const routes: CatalogProviderRoute[] = [];
  if (model.routes.batch) {
    routes.push({
      id: model.id,
      kind: model.kind,
      provider: model.routes.batch.executionProvider,
      transport: "batch",
      upstreamModel: model.routes.batch.executionModel,
    });
  }
  if (model.routes.realtime) {
    routes.push({
      id: model.id,
      kind: model.kind,
      provider: model.routes.realtime.executionProvider,
      transport: "realtime",
      upstreamModel: model.routes.realtime.executionModel,
    });
  }

  return routes.length > 0
    ? routes
    : [
        {
          id: model.id,
          kind: model.kind,
          provider: model.executionProvider,
          upstreamModel: model.executionModel,
        },
      ];
};

const supportsCatalogRoute = (
  candidate: ProviderInventoryModel,
  route: CatalogProviderRoute
): boolean => {
  if (candidate.upstreamModel !== route.upstreamModel) {
    return false;
  }
  if (candidate.kind && candidate.kind !== route.kind) {
    return false;
  }
  if (route.transport && candidate.transports) {
    return candidate.transports.includes(route.transport);
  }
  return true;
};

const missingReason = (
  source: ProviderInventorySource | undefined
): string | undefined => {
  if (!source) {
    return "no inventory source is configured for provider";
  }
  if (source.status !== "ok") {
    return;
  }
  return "not found in provider inventory response";
};

export const compareCatalogToInventory = (
  catalog: readonly PublicModelSpec[],
  sources: readonly ProviderInventorySource[]
): ProviderInventoryDrift => {
  const sourceByProvider = new Map(
    sources.map((source) => [source.provider, source])
  );
  const catalogKeys = new Set(
    catalog
      .flatMap(catalogProviderRoutes)
      .map((route) => `${route.provider}:${route.upstreamModel}`)
  );

  const catalogModelsWithoutProviderMatch: CatalogModelWithoutProviderMatch[] =
    [];
  for (const model of catalog) {
    for (const route of catalogProviderRoutes(model)) {
      const source = sourceByProvider.get(route.provider);
      const reason = missingReason(source);
      if (!reason) {
        continue;
      }
      const matched = source?.models.some((candidate) =>
        supportsCatalogRoute(candidate, route)
      );
      if (!matched) {
        catalogModelsWithoutProviderMatch.push({
          id: route.id,
          provider: route.provider,
          reason,
          upstreamModel: route.upstreamModel,
        });
      }
    }
  }

  const providerModelsNotInCatalog = sources.flatMap((source) => {
    if (source.status !== "ok") {
      return [];
    }
    return source.models
      .filter(
        (model) => !catalogKeys.has(`${source.provider}:${model.upstreamModel}`)
      )
      .map((model) => ({
        kind: model.kind,
        provider: source.provider,
        transports: model.transports,
        upstreamModel: model.upstreamModel,
      }));
  });

  return {
    catalogModelsWithoutProviderMatch,
    providerModelsNotInCatalog,
    sourcesUnavailable: sources.flatMap((source) =>
      source.status === "ok"
        ? []
        : [
            {
              provider: source.provider,
              reason: source.reason,
              status: source.status,
            },
          ]
    ),
  };
};
