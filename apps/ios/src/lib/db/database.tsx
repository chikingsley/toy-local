import { SQLiteProvider, type SQLiteDatabase } from "expo-sqlite";
import type { PropsWithChildren } from "react";

import { DEFAULT_TRANSCRIPTION_MODEL_ID } from "@/features/modes/mode-defaults";

const DATABASE_NAME = "timbervox-mobile.db";

const VOICE_MODE_ID = "mode_voice_default";
const VOICE_DESCRIPTION =
  "Turn your voice into punctuated text with no AI post-processing.";

type Migration = {
  migrate: (database: SQLiteDatabase) => Promise<void>;
  version: number;
};

const migrations: Migration[] = [
  {
    version: 1,
    migrate: async (database) => {
      await database.execAsync(`
        CREATE TABLE IF NOT EXISTS dictation_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          text TEXT NOT NULL,
          duration_ms INTEGER NOT NULL,
          model TEXT NOT NULL,
          source TEXT NOT NULL,
          audio_uri TEXT
        );

        CREATE TABLE IF NOT EXISTS modes (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          icon_key TEXT NOT NULL,
          icon_customized INTEGER NOT NULL DEFAULT 0 CHECK (icon_customized IN (0, 1)),
          description TEXT NOT NULL,
          preset_kind TEXT NOT NULL CHECK (
            preset_kind IN ('voice', 'message', 'mail', 'note', 'custom')
          ),
          language TEXT,
          asr_model_id TEXT NOT NULL,
          realtime_enabled INTEGER NOT NULL CHECK (realtime_enabled IN (0, 1)),
          identify_speakers INTEGER NOT NULL CHECK (identify_speakers IN (0, 1)),
          processing_model_id TEXT,
          processing_instructions TEXT,
          is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS modes_single_active
          ON modes (is_active)
          WHERE is_active = 1;

        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY NOT NULL,
          value_json TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      `);

      const now = new Date().toISOString();
      await database.runAsync(
        `INSERT INTO modes (
          id, name, icon_key, icon_customized, description, preset_kind,
          language, asr_model_id, realtime_enabled, identify_speakers,
          processing_model_id, processing_instructions, is_active,
          created_at, updated_at
        )
        SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        WHERE NOT EXISTS (SELECT 1 FROM modes)`,
        VOICE_MODE_ID,
        "Voice to Text",
        "person.wave.2.fill",
        0,
        VOICE_DESCRIPTION,
        "voice",
        null,
        DEFAULT_TRANSCRIPTION_MODEL_ID,
        1,
        0,
        null,
        null,
        1,
        now,
        now,
      );
      await database.runAsync(
        `INSERT INTO app_settings (key, value_json, updated_at)
         SELECT ?, ?, ?
         WHERE EXISTS (SELECT 1 FROM modes WHERE id = ?)
           AND NOT EXISTS (SELECT 1 FROM app_settings WHERE key = ?)`,
        "active_mode_id",
        JSON.stringify(VOICE_MODE_ID),
        now,
        VOICE_MODE_ID,
        "active_mode_id",
      );
    },
  },
  {
    version: 2,
    migrate: async (database) => {
      await database.runAsync(
        `UPDATE modes
         SET name = ?, updated_at = ?
         WHERE preset_kind = ? AND name = ?`,
        "Voice to Text",
        new Date().toISOString(),
        "voice",
        "Voice",
      );
    },
  },
  {
    version: 3,
    migrate: async (database) => {
      await database.execAsync(`
        CREATE TABLE IF NOT EXISTS dictations (
          id TEXT PRIMARY KEY NOT NULL,
          request_id TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          started_at TEXT NOT NULL,
          ended_at TEXT NOT NULL,
          duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
          word_count INTEGER NOT NULL CHECK (word_count >= 0),
          mode_id TEXT NOT NULL,
          mode_snapshot_json TEXT NOT NULL,
          entry_point TEXT NOT NULL CHECK (
            entry_point IN ('app', 'keyboard', 'shortcut')
          ),
          status TEXT NOT NULL CHECK (
            status IN ('succeeded', 'no_speech', 'failed')
          ),
          asr_model_id TEXT NOT NULL,
          language TEXT,
          audio_uri TEXT,
          audio_size_bytes INTEGER CHECK (
            audio_size_bytes IS NULL OR audio_size_bytes >= 0
          ),
          audio_format TEXT,
          error_code TEXT,
          error_message TEXT
        );

        CREATE INDEX IF NOT EXISTS dictations_created_at
          ON dictations (created_at DESC);
        CREATE INDEX IF NOT EXISTS dictations_status
          ON dictations (status);

        CREATE TABLE IF NOT EXISTS artifacts (
          id TEXT PRIMARY KEY NOT NULL,
          dictation_id TEXT NOT NULL REFERENCES dictations(id) ON DELETE CASCADE,
          kind TEXT NOT NULL CHECK (kind IN ('raw', 'segmented', 'processed')),
          text TEXT NOT NULL,
          timing_json TEXT,
          model_id TEXT,
          payload_json TEXT,
          created_at TEXT NOT NULL,
          UNIQUE (dictation_id, kind)
        );

        CREATE INDEX IF NOT EXISTS artifacts_dictation_id
          ON artifacts (dictation_id);
      `);
    },
  },
  {
    version: 4,
    migrate: async (database) => {
      const legacyRows = await database.getAllAsync<{
        audio_uri: string | null;
        created_at: string;
        duration_ms: number;
        id: number;
        model: string;
        source: "app" | "keyboard";
        text: string;
      }>("SELECT * FROM dictation_history ORDER BY id");

      for (const row of legacyRows) {
        const resultId = `legacy:${row.id}`;
        const requestId = `legacy_request_${row.id}`;
        const modelId = row.model || "legacy";
        const createdAt = normalizeLegacyDate(row.created_at);
        const endedAt = new Date(
          new Date(createdAt).getTime() + Math.max(0, row.duration_ms),
        ).toISOString();
        const modeSnapshot = {
          asrModelId: modelId,
          description: "Imported from an earlier TimberVox build.",
          iconKey: "person.wave.2.fill",
          id: "mode_legacy_import",
          identifySpeakers: false,
          language: null,
          name: "Imported",
          presetKind: "voice",
          processingInstructions: null,
          processingModelId: null,
          realtimeModel: modelId,
        };
        const status = row.text.trim() ? "succeeded" : "no_speech";

        await database.runAsync(
          `INSERT OR IGNORE INTO dictations (
             id, request_id, created_at, started_at, ended_at, duration_ms,
             word_count, mode_id, mode_snapshot_json, entry_point, status,
             asr_model_id, language, audio_uri, audio_size_bytes, audio_format,
             error_code, error_message
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          resultId,
          requestId,
          createdAt,
          createdAt,
          endedAt,
          Math.max(0, row.duration_ms),
          countWords(row.text),
          modeSnapshot.id,
          JSON.stringify(modeSnapshot),
          row.source,
          status,
          modelId,
          null,
          row.audio_uri,
          null,
          row.audio_uri ? "audio/unknown" : null,
          null,
          null,
        );
        await database.runAsync(
          `INSERT OR IGNORE INTO artifacts (
             id, dictation_id, kind, text, timing_json, model_id,
             payload_json, created_at
           ) VALUES (?, ?, 'raw', ?, NULL, ?, ?, ?)`,
          `${resultId}_raw`,
          resultId,
          row.text,
          modelId,
          JSON.stringify({
            provenance: "legacy_dictation_history",
            schema_version: 2,
            text: row.text,
          }),
          endedAt,
        );
      }

      if (legacyRows.length > 0) {
        await database.runAsync("DELETE FROM dictation_history");
      }
    },
  },
  {
    version: 5,
    migrate: async (database) => {
      await database.execAsync(`
        CREATE TABLE IF NOT EXISTS processing_runs (
          id TEXT PRIMARY KEY NOT NULL,
          dictation_id TEXT NOT NULL REFERENCES dictations(id) ON DELETE CASCADE,
          source_artifact_id TEXT NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
          output_artifact_id TEXT REFERENCES artifacts(id) ON DELETE SET NULL,
          model_id TEXT NOT NULL,
          instructions TEXT NOT NULL,
          status TEXT NOT NULL CHECK (status IN ('running', 'succeeded', 'failed')),
          output_text TEXT,
          error_message TEXT,
          started_at TEXT NOT NULL,
          ended_at TEXT
        );

        CREATE INDEX IF NOT EXISTS processing_runs_dictation_id
          ON processing_runs (dictation_id, started_at DESC);
      `);
    },
  },
  {
    version: 6,
    migrate: async (database) => {
      await database.runAsync(
        `UPDATE modes
         SET asr_model_id = ?, realtime_enabled = 1, updated_at = ?
         WHERE id = ? AND TRIM(asr_model_id) = ''`,
        DEFAULT_TRANSCRIPTION_MODEL_ID,
        new Date().toISOString(),
        VOICE_MODE_ID,
      );
    },
  },
];

function countWords(text: string) {
  const clean = text.trim();
  return clean ? clean.split(/\s+/).length : 0;
}

function normalizeLegacyDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? new Date(0).toISOString()
    : date.toISOString();
}

async function migrateDatabase(database: SQLiteDatabase) {
  await database.execAsync("PRAGMA journal_mode = WAL");
  await database.execAsync("PRAGMA foreign_keys = ON");
  await database.execAsync(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY NOT NULL,
      applied_at TEXT NOT NULL
    );
  `);

  for (const migration of migrations) {
    const applied = await database.getFirstAsync<{ version: number }>(
      "SELECT version FROM schema_migrations WHERE version = ?",
      migration.version,
    );
    if (applied) continue;

    await database.withExclusiveTransactionAsync(async (transaction) => {
      const alreadyApplied = await transaction.getFirstAsync<{
        version: number;
      }>(
        "SELECT version FROM schema_migrations WHERE version = ?",
        migration.version,
      );
      if (alreadyApplied) return;
      await migration.migrate(transaction);
      await transaction.runAsync(
        "INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)",
        migration.version,
        new Date().toISOString(),
      );
    });
  }
}

function AppDatabaseProvider({ children }: PropsWithChildren) {
  return (
    <SQLiteProvider databaseName={DATABASE_NAME} onInit={migrateDatabase}>
      {children}
    </SQLiteProvider>
  );
}

export {
  AppDatabaseProvider,
  DATABASE_NAME,
  migrateDatabase,
  migrations,
  DEFAULT_TRANSCRIPTION_MODEL_ID,
  VOICE_MODE_ID,
};
