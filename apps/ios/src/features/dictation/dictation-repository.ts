import type { SQLiteDatabase } from "expo-sqlite";

import type {
  DictationModeSnapshot,
  DictationOutcome,
} from "@/features/dictation/dictation-types";
import {
  deleteRecording,
  importWaveRecording,
  persistRecording,
} from "@/features/dictation/recording-file";

type StoredDictation = {
  audioFormat: string | null;
  audioSizeBytes: number | null;
  audioUri: string | null;
  createdAt: string;
  durationMs: number;
  entryPoint: "app" | "keyboard" | "shortcut";
  id: string;
  language: string | null;
  modelId: string;
  status: DictationOutcome["status"];
  text: string;
  wordCount: number;
};

type StoredArtifact = {
  id: string;
  kind: "processed" | "raw" | "segmented";
  modelId: string | null;
  payload: Record<string, unknown> | null;
  text: string;
  timing: Record<string, unknown> | null;
};

type StoredDictationDetail = StoredDictation & {
  endedAt: string;
  error: { code: string; message: string } | null;
  mode: DictationModeSnapshot;
  requestId: string;
  startedAt: string;
  artifacts: StoredArtifact[];
};

async function persistDictationOutcome(
  database: SQLiteDatabase,
  outcome: DictationOutcome,
  sourceRecordingUri?: string | null,
) {
  const recording = sourceRecordingUri
    ? await importWaveRecording(
        sourceRecordingUri,
        outcome.requestId,
        outcome.resultId,
      )
    : persistRecording(
        outcome.audioChunks,
        outcome.requestId,
        outcome.resultId,
      );
  try {
    await database.withExclusiveTransactionAsync(async (transaction) => {
      await transaction.runAsync(
        `INSERT INTO dictations (
           id, request_id, created_at, started_at, ended_at, duration_ms,
           word_count, mode_id, mode_snapshot_json, entry_point, status,
           asr_model_id, language, audio_uri, audio_size_bytes, audio_format,
           error_code, error_message
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           ended_at = excluded.ended_at,
           duration_ms = excluded.duration_ms,
           word_count = excluded.word_count,
           status = excluded.status,
           language = excluded.language,
           audio_uri = excluded.audio_uri,
           audio_size_bytes = excluded.audio_size_bytes,
           audio_format = excluded.audio_format,
           error_code = excluded.error_code,
           error_message = excluded.error_message`,
        outcome.resultId,
        outcome.requestId,
        outcome.createdAt,
        outcome.startedAt,
        outcome.endedAt,
        outcome.durationMs,
        wordCount(displayText(outcome)),
        outcome.mode.id,
        JSON.stringify(outcome.mode),
        outcome.entryPoint,
        outcome.status,
        outcome.mode.asrModelId,
        outcome.language,
        recording?.uri ?? null,
        recording?.sizeBytes ?? null,
        recording?.format ?? null,
        outcome.error?.code ?? null,
        outcome.error?.message ?? null,
      );

      for (const artifact of outcome.artifacts) {
        await transaction.runAsync(
          `INSERT INTO artifacts (
             id, dictation_id, kind, text, timing_json, model_id,
             payload_json, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             text = excluded.text,
             timing_json = excluded.timing_json,
             model_id = excluded.model_id,
             payload_json = excluded.payload_json`,
          artifact.id,
          outcome.resultId,
          artifact.kind,
          artifact.text,
          artifact.timing ? JSON.stringify(artifact.timing) : null,
          artifact.modelId,
          artifact.payload ? JSON.stringify(artifact.payload) : null,
          outcome.endedAt,
        );
      }
    });
  } catch (error) {
    deleteRecording(recording?.uri ?? null);
    throw error;
  }
  return recording;
}

async function loadStoredDictations(
  database: SQLiteDatabase,
): Promise<StoredDictation[]> {
  const rows = await database.getAllAsync<{
    asr_model_id: string;
    audio_format: string | null;
    audio_size_bytes: number | null;
    audio_uri: string | null;
    created_at: string;
    duration_ms: number;
    entry_point: "app" | "keyboard" | "shortcut";
    id: string;
    language: string | null;
    status: "failed" | "no_speech" | "succeeded";
    text: string | null;
    word_count: number;
  }>(
    `SELECT d.id, d.created_at, d.duration_ms, d.word_count, d.language,
            d.entry_point, d.status, d.asr_model_id, d.audio_uri,
            d.audio_size_bytes, d.audio_format,
            COALESCE(
              (SELECT processed.text FROM artifacts processed
                WHERE processed.dictation_id = d.id
                  AND processed.kind = 'processed'),
              (SELECT raw.text FROM artifacts raw
                WHERE raw.dictation_id = d.id AND raw.kind = 'raw')
            ) AS text
       FROM dictations d
      ORDER BY d.created_at DESC`,
  );
  return rows.map((row) => ({
    audioFormat: row.audio_format,
    audioSizeBytes: row.audio_size_bytes,
    audioUri: row.audio_uri,
    createdAt: row.created_at,
    durationMs: row.duration_ms,
    entryPoint: row.entry_point,
    id: row.id,
    language: row.language,
    modelId: row.asr_model_id,
    status: row.status,
    text: row.text ?? "",
    wordCount: row.word_count,
  }));
}

async function loadStoredDictationDetail(
  database: SQLiteDatabase,
  id: string,
): Promise<StoredDictationDetail | null> {
  const row = await database.getFirstAsync<{
    asr_model_id: string;
    audio_format: string | null;
    audio_size_bytes: number | null;
    audio_uri: string | null;
    created_at: string;
    duration_ms: number;
    ended_at: string;
    entry_point: "app" | "keyboard" | "shortcut";
    error_code: string | null;
    error_message: string | null;
    id: string;
    language: string | null;
    mode_snapshot_json: string;
    request_id: string;
    started_at: string;
    status: "failed" | "no_speech" | "succeeded";
    text: string | null;
    word_count: number;
  }>(
    `SELECT d.*,
            COALESCE(
              (SELECT processed.text FROM artifacts processed
                WHERE processed.dictation_id = d.id
                  AND processed.kind = 'processed'),
              (SELECT raw.text FROM artifacts raw
                WHERE raw.dictation_id = d.id AND raw.kind = 'raw')
            ) AS text
       FROM dictations d
      WHERE d.id = ?
      LIMIT 1`,
    id,
  );
  if (!row) return null;

  const artifactRows = await database.getAllAsync<{
    id: string;
    kind: "processed" | "raw" | "segmented";
    model_id: string | null;
    payload_json: string | null;
    text: string;
    timing_json: string | null;
  }>(
    `SELECT id, kind, text, timing_json, model_id, payload_json
       FROM artifacts
      WHERE dictation_id = ?
      ORDER BY CASE kind
        WHEN 'raw' THEN 0
        WHEN 'segmented' THEN 1
        ELSE 2
      END`,
    id,
  );

  return {
    artifacts: artifactRows.map((artifact) => ({
      id: artifact.id,
      kind: artifact.kind,
      modelId: artifact.model_id,
      payload: parseObject(artifact.payload_json),
      text: artifact.text,
      timing: parseObject(artifact.timing_json),
    })),
    audioFormat: row.audio_format,
    audioSizeBytes: row.audio_size_bytes,
    audioUri: row.audio_uri,
    createdAt: row.created_at,
    durationMs: row.duration_ms,
    endedAt: row.ended_at,
    entryPoint: row.entry_point,
    error:
      row.error_code || row.error_message
        ? {
            code: row.error_code ?? "dictation_failed",
            message: row.error_message ?? "Dictation failed.",
          }
        : null,
    id: row.id,
    language: row.language,
    mode: parseMode(row.mode_snapshot_json, row.asr_model_id),
    modelId: row.asr_model_id,
    requestId: row.request_id,
    startedAt: row.started_at,
    status: row.status,
    text: row.text ?? "",
    wordCount: row.word_count,
  };
}

async function deleteStoredDictation(database: SQLiteDatabase, id: string) {
  const row = await database.getFirstAsync<{ audio_uri: string | null }>(
    "SELECT audio_uri FROM dictations WHERE id = ?",
    id,
  );
  await database.runAsync("DELETE FROM dictations WHERE id = ?", id);
  deleteRecording(row?.audio_uri ?? null);
}

function displayText(outcome: DictationOutcome) {
  return (
    outcome.artifacts.find((artifact) => artifact.kind === "processed")?.text ??
    outcome.artifacts.find((artifact) => artifact.kind === "raw")?.text ??
    ""
  );
}

function wordCount(text: string) {
  const clean = text.trim();
  return clean ? clean.split(/\s+/).length : 0;
}

function parseObject(value: string | null) {
  if (!value) return null;
  try {
    const parsed: unknown = JSON.parse(value);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function parseMode(
  value: string,
  fallbackModel: string,
): DictationModeSnapshot {
  const parsed = parseObject(value);
  return {
    asrModelId:
      typeof parsed?.asrModelId === "string"
        ? parsed.asrModelId
        : fallbackModel,
    description:
      typeof parsed?.description === "string" ? parsed.description : "",
    iconKey:
      typeof parsed?.iconKey === "string"
        ? parsed.iconKey
        : "person.wave.2.fill",
    id: typeof parsed?.id === "string" ? parsed.id : "mode_unknown",
    identifySpeakers: parsed?.identifySpeakers === true,
    language: typeof parsed?.language === "string" ? parsed.language : null,
    name: typeof parsed?.name === "string" ? parsed.name : "Voice to Text",
    presetKind:
      parsed?.presetKind === "message" ||
      parsed?.presetKind === "mail" ||
      parsed?.presetKind === "note" ||
      parsed?.presetKind === "custom"
        ? parsed.presetKind
        : "voice",
    processingInstructions:
      typeof parsed?.processingInstructions === "string"
        ? parsed.processingInstructions
        : null,
    processingModelId:
      typeof parsed?.processingModelId === "string"
        ? parsed.processingModelId
        : null,
    realtimeModel:
      typeof parsed?.realtimeModel === "string"
        ? parsed.realtimeModel
        : fallbackModel,
  };
}

export {
  deleteStoredDictation,
  loadStoredDictationDetail,
  loadStoredDictations,
  persistDictationOutcome,
  wordCount,
};
export type { StoredArtifact, StoredDictation, StoredDictationDetail };
