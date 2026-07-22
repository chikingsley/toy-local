import type { SQLiteDatabase } from "expo-sqlite";

import type { StoredDictationDetail } from "@/features/dictation/dictation-repository";
import type { DictationPlan } from "@/features/dictation/dictation-types";
import { processDictationText } from "@/features/dictation/text-processing-client";

type ReprocessDependencies = {
  createId?: () => string;
  now?: () => Date;
  process?: (plan: DictationPlan, transcript: string) => Promise<string | null>;
};

async function reprocessStoredDictation(
  database: SQLiteDatabase,
  detail: StoredDictationDetail,
  credential: string,
  dependencies: ReprocessDependencies = {},
) {
  const source = detail.artifacts.find((artifact) => artifact.kind === "raw");
  if (!source?.text.trim()) {
    throw new Error("This dictation does not have Raw text to reprocess.");
  }
  if (detail.mode.presetKind === "voice") {
    throw new Error("Voice to Text does not apply AI post-processing.");
  }
  const modelId = detail.mode.processingModelId?.trim();
  const instructions = detail.mode.processingInstructions?.trim();
  if (!modelId || !instructions) {
    throw new Error("This mode does not have a complete processing setup.");
  }
  if (!credential) {
    throw new Error("This build does not have an active TimberVox session.");
  }

  const now = dependencies.now ?? (() => new Date());
  const createId = dependencies.createId ?? createProcessingRunId;
  const process = dependencies.process ?? processDictationText;
  const runId = createId();
  const startedAt = now().toISOString();
  const outputArtifactId =
    detail.artifacts.find((artifact) => artifact.kind === "processed")?.id ??
    `${detail.id}_processed`;
  const plan: DictationPlan = {
    credential,
    entryPoint: detail.entryPoint,
    executor: {
      kind: "cloud-batch",
      model: detail.modelId,
      provider: "stored-dictation",
    },
    mode: detail.mode,
    requestId: `reprocess_${detail.requestId}`,
  };

  await database.runAsync(
    `INSERT INTO processing_runs (
       id, dictation_id, source_artifact_id, output_artifact_id, model_id,
       instructions, status, output_text, error_message, started_at, ended_at
     ) VALUES (?, ?, ?, NULL, ?, ?, 'running', NULL, NULL, ?, NULL)`,
    runId,
    detail.id,
    source.id,
    modelId,
    instructions,
    startedAt,
  );

  try {
    const output = await process(plan, source.text);
    if (!output?.trim()) {
      throw new Error("Text processing returned no text.");
    }
    const endedAt = now().toISOString();
    await database.withExclusiveTransactionAsync(async (transaction) => {
      await transaction.runAsync(
        `INSERT INTO artifacts (
           id, dictation_id, kind, text, timing_json, model_id,
           payload_json, created_at
         ) VALUES (?, ?, 'processed', ?, NULL, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           text = excluded.text,
           model_id = excluded.model_id,
           payload_json = excluded.payload_json,
           created_at = excluded.created_at`,
        outputArtifactId,
        detail.id,
        output,
        modelId,
        JSON.stringify({
          processing_run_id: runId,
          source_artifact_id: source.id,
        }),
        endedAt,
      );
      await transaction.runAsync(
        `UPDATE processing_runs
            SET output_artifact_id = ?, status = 'succeeded', output_text = ?,
                ended_at = ?
          WHERE id = ?`,
        outputArtifactId,
        output,
        endedAt,
        runId,
      );
      await transaction.runAsync(
        `UPDATE dictations
            SET word_count = ?
          WHERE id = ?`,
        countWords(output),
        detail.id,
      );
    });
    return { output, outputArtifactId, runId };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await database.runAsync(
      `UPDATE processing_runs
          SET status = 'failed', error_message = ?, ended_at = ?
        WHERE id = ?`,
      message,
      now().toISOString(),
      runId,
    );
    throw error;
  }
}

function createProcessingRunId() {
  return `processing_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function countWords(text: string) {
  const clean = text.trim();
  return clean ? clean.split(/\s+/).length : 0;
}

export { reprocessStoredDictation };
export type { ReprocessDependencies };
