import { File } from "expo-file-system";
import type { SQLiteDatabase } from "expo-sqlite";

type AudioRetentionDays = 1 | 7 | 30 | 90 | null;

type StorageSummary = {
  audioBytes: number;
  audioCount: number;
  historyCount: number;
};

async function loadStorageSummary(
  database: SQLiteDatabase,
): Promise<StorageSummary> {
  const row = await database.getFirstAsync<{
    audio_bytes: number;
    audio_count: number;
    history_count: number;
  }>(`SELECT
        COALESCE(SUM(audio_size_bytes), 0) AS audio_bytes,
        COUNT(audio_uri) AS audio_count,
        COUNT(*) AS history_count
      FROM dictations`);
  return {
    audioBytes: row?.audio_bytes ?? 0,
    audioCount: row?.audio_count ?? 0,
    historyCount: row?.history_count ?? 0,
  };
}

async function loadAudioRetention(
  database: SQLiteDatabase,
): Promise<AudioRetentionDays> {
  const row = await database.getFirstAsync<{ value_json: string }>(
    "SELECT value_json FROM app_settings WHERE key = ?",
    "audio_retention_days",
  );
  if (!row) return null;
  try {
    const value: unknown = JSON.parse(row.value_json);
    return value === 1 || value === 7 || value === 30 || value === 90
      ? value
      : null;
  } catch {
    return null;
  }
}

async function setAudioRetention(
  database: SQLiteDatabase,
  days: AudioRetentionDays,
) {
  await database.runAsync(
    `INSERT INTO app_settings (key, value_json, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET
       value_json = excluded.value_json,
       updated_at = excluded.updated_at`,
    "audio_retention_days",
    JSON.stringify(days),
    new Date().toISOString(),
  );
  await applyAudioRetention(database, days);
}

async function applyAudioRetention(
  database: SQLiteDatabase,
  days?: AudioRetentionDays,
) {
  const retention =
    days === undefined ? await loadAudioRetention(database) : days;
  if (retention === null) return 0;
  const cutoff = new Date(Date.now() - retention * 86_400_000).toISOString();
  const rows = await database.getAllAsync<{ audio_uri: string; id: string }>(
    `SELECT id, audio_uri FROM dictations
      WHERE audio_uri IS NOT NULL AND created_at < ?`,
    cutoff,
  );
  for (const row of rows) deleteFile(row.audio_uri);
  await database.runAsync(
    `UPDATE dictations
        SET audio_uri = NULL, audio_size_bytes = NULL, audio_format = NULL
      WHERE audio_uri IS NOT NULL AND created_at < ?`,
    cutoff,
  );
  return rows.length;
}

async function clearStoredAudio(database: SQLiteDatabase) {
  const rows = await database.getAllAsync<{ audio_uri: string }>(
    "SELECT audio_uri FROM dictations WHERE audio_uri IS NOT NULL",
  );
  for (const row of rows) deleteFile(row.audio_uri);
  await database.runAsync(
    `UPDATE dictations
        SET audio_uri = NULL, audio_size_bytes = NULL, audio_format = NULL`,
  );
}

async function clearStoredHistory(database: SQLiteDatabase) {
  await clearStoredAudio(database);
  await database.runAsync("DELETE FROM dictations");
}

function deleteFile(uri: string) {
  try {
    const file = new File(uri);
    if (file.exists) file.delete();
  } catch {
    // A missing file is already cleared from the user's device.
  }
}

export {
  applyAudioRetention,
  clearStoredAudio,
  clearStoredHistory,
  loadAudioRetention,
  loadStorageSummary,
  setAudioRetention,
};
export type { AudioRetentionDays, StorageSummary };
