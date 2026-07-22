import type { SQLiteDatabase } from "expo-sqlite";

import type { ModelCatalog } from "@/features/modes/model-catalog";

// The last successfully fetched Worker catalog, kept so dictation still has a
// route when the app launches offline or the Worker is briefly unavailable.
// The cache is only ever written from a fresh network parse; a degraded or
// synthetic catalog must never be stored because stored modes are normalized
// against whatever catalog the provider adopts.
const CACHE_KEY = "model_catalog_cache";
const CACHE_SCHEMA_VERSION = 1;

async function readCachedModelCatalog(
  database: SQLiteDatabase,
): Promise<ModelCatalog | null> {
  const row = await database.getFirstAsync<{ value_json: string }>(
    "SELECT value_json FROM app_settings WHERE key = ?",
    CACHE_KEY,
  );
  if (!row) return null;
  try {
    const parsed: unknown = JSON.parse(row.value_json);
    if (!isRecord(parsed) || parsed.schemaVersion !== CACHE_SCHEMA_VERSION) {
      return null;
    }
    const catalog = parsed.catalog;
    if (
      !isRecord(catalog) ||
      !Array.isArray(catalog.languageModels) ||
      !Array.isArray(catalog.transcriptionModels) ||
      catalog.transcriptionModels.length === 0
    ) {
      return null;
    }
    return catalog as unknown as ModelCatalog;
  } catch {
    return null;
  }
}

async function writeCachedModelCatalog(
  database: SQLiteDatabase,
  catalog: ModelCatalog,
) {
  await database.runAsync(
    `INSERT INTO app_settings (key, value_json, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET
       value_json = excluded.value_json,
       updated_at = excluded.updated_at`,
    CACHE_KEY,
    JSON.stringify({ catalog, schemaVersion: CACHE_SCHEMA_VERSION }),
    new Date().toISOString(),
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export { readCachedModelCatalog, writeCachedModelCatalog };
