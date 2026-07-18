import type { Env } from "../../bindings";
import type {
  AsrTransport,
  BatchAsrProviderId,
  LanguageModelProviderId,
  PublicModelKind,
  PublicModelSpec,
  RealtimeAsrProviderId,
} from "../models/types";

export type ProviderInventoryProviderId =
  | LanguageModelProviderId
  | BatchAsrProviderId
  | RealtimeAsrProviderId;

type ProviderInventorySourceKind = "api" | "contract" | "manual";
type ProviderInventoryStatus = "ok" | "skipped" | "failed";

export interface ProviderInventoryModel {
  displayName?: string;
  kind?: PublicModelKind;
  transports?: readonly AsrTransport[];
  upstreamModel: string;
}

export interface ProviderInventorySource {
  checkedAt: string;
  models: readonly ProviderInventoryModel[];
  provider: ProviderInventoryProviderId;
  reason?: string;
  sourceKind: ProviderInventorySourceKind;
  status: ProviderInventoryStatus;
  url?: string;
}

export interface ProviderInventoryContext {
  env: Env;
  fetch: typeof fetch;
  now: Date;
}

export interface ProviderInventoryAdapter {
  list: (context: ProviderInventoryContext) => Promise<ProviderInventorySource>;
  provider: ProviderInventoryProviderId;
}

export interface CatalogModelWithoutProviderMatch {
  id: string;
  provider: ProviderInventoryProviderId;
  reason: string;
  upstreamModel: string;
}

interface ProviderModelNotInCatalog {
  kind?: PublicModelKind;
  provider: ProviderInventoryProviderId;
  transports?: readonly AsrTransport[];
  upstreamModel: string;
}

export interface ProviderInventoryDrift {
  catalogModelsWithoutProviderMatch: readonly CatalogModelWithoutProviderMatch[];
  providerModelsNotInCatalog: readonly ProviderModelNotInCatalog[];
  sourcesUnavailable: readonly {
    provider: ProviderInventoryProviderId;
    reason?: string;
    status: Exclude<ProviderInventoryStatus, "ok">;
  }[];
}

export interface ProviderInventoryReport {
  catalog: readonly PublicModelSpec[];
  checkedAt: string;
  drift: ProviderInventoryDrift;
  sources: readonly ProviderInventorySource[];
}
