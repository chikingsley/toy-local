import type { SQLiteDatabase } from "expo-sqlite";
import {
  acknowledgeNativeResult,
  getNativeResultOutbox,
} from "timbervox-system";

import { persistDictationOutcome } from "@/features/dictation/dictation-repository";
import type {
  DictationModeSnapshot,
  DictationOutcome,
  PersistedArtifact,
} from "@/features/dictation/dictation-types";
import {
  readBridgeNumber,
  readBridgeString,
  writeBridgeNumber,
} from "@/features/keyboard/app-group-bridge";

type NativeResultEnvelope = {
  artifactJSON: string | null;
  createdAt: string;
  durationMs: number;
  endedAt: string;
  entryPoint?: "app" | "keyboard" | "shortcut";
  errorCode: string | null;
  errorMessage: string | null;
  finalText: string;
  mode: DictationModeSnapshot & { batchModelId: string };
  rawText: string;
  recordingURI: string | null;
  requestId: string;
  resultId: string;
  schemaVersion: 1;
  startedAt: string;
  status: DictationOutcome["status"];
};

async function consumeNativeResult(database: SQLiteDatabase) {
  const outbox = getNativeResultOutbox();
  if (outbox.length) {
    let persistedAny = false;
    for (const item of outbox) {
      let envelope: NativeResultEnvelope;
      try {
        envelope = parseNativeResultEnvelope(item.json);
      } catch {
        // A malformed envelope must not block every later result forever;
        // acknowledge it so the outbox keeps draining. Persistence failures
        // below still propagate, leaving the item for a retry.
        acknowledgeNativeResult(item.filename);
        continue;
      }
      await persistNativeResult(database, envelope);
      acknowledgeNativeResult(item.filename);
      persistedAny = true;
    }
    writeBridgeNumber(
      "nativeResultConsumedRevision",
      readBridgeNumber("nativeResultRevision"),
    );
    return persistedAny;
  }

  const revision = readBridgeNumber("nativeResultRevision");
  if (revision <= readBridgeNumber("nativeResultConsumedRevision")) {
    return false;
  }
  let envelope: NativeResultEnvelope;
  try {
    envelope = parseNativeResultEnvelope(readBridgeString("nativeResultEnvelope"));
  } catch {
    writeBridgeNumber("nativeResultConsumedRevision", revision);
    return false;
  }
  await persistNativeResult(database, envelope);
  writeBridgeNumber("nativeResultConsumedRevision", revision);
  return true;
}

async function persistNativeResult(
  database: SQLiteDatabase,
  envelope: NativeResultEnvelope,
) {
  const artifactPayload = parseObject(envelope.artifactJSON);
  const artifacts: PersistedArtifact[] = [];
  if (envelope.rawText.trim()) {
    artifacts.push({
      id: `${envelope.resultId}_raw`,
      kind: "raw",
      modelId: envelope.mode.asrModelId,
      payload: artifactPayload,
      text: envelope.rawText,
      timing: timingPayload(artifactPayload),
    });
  }
  if (
    envelope.finalText.trim() &&
    envelope.finalText.trim() !== envelope.rawText.trim()
  ) {
    artifacts.push({
      id: `${envelope.resultId}_processed`,
      kind: "processed",
      modelId: envelope.mode.processingModelId,
      payload: null,
      text: envelope.finalText,
      timing: null,
    });
  }
  const mode: DictationModeSnapshot = {
    asrModelId: envelope.mode.asrModelId,
    description: envelope.mode.description,
    iconKey: envelope.mode.iconKey,
    id: envelope.mode.id,
    identifySpeakers: envelope.mode.identifySpeakers,
    language: envelope.mode.language,
    name: envelope.mode.name,
    presetKind: envelope.mode.presetKind,
    processingInstructions: envelope.mode.processingInstructions,
    processingModelId: envelope.mode.processingModelId,
    realtimeModel: envelope.mode.realtimeModel,
  };
  await persistDictationOutcome(
    database,
    {
      artifacts,
      audioChunks: [],
      createdAt: envelope.createdAt,
      durationMs: envelope.durationMs,
      endedAt: envelope.endedAt,
      entryPoint: envelope.entryPoint ?? "shortcut",
      error:
        envelope.errorCode || envelope.errorMessage
          ? {
              code: envelope.errorCode ?? "shortcut_recording_failed",
              message: envelope.errorMessage ?? "Shortcut dictation failed.",
            }
          : null,
      language: detectedLanguage(artifactPayload) ?? mode.language,
      mode,
      requestId: envelope.requestId,
      resultId: envelope.resultId,
      startedAt: envelope.startedAt,
      status: envelope.status,
    },
    envelope.recordingURI,
  );
}

function parseNativeResultEnvelope(value: string): NativeResultEnvelope {
  const parsed: unknown = JSON.parse(value);
  if (!isRecord(parsed) || parsed.schemaVersion !== 1) {
    throw new Error("The native dictation result uses an unsupported schema.");
  }
  if (
    typeof parsed.requestId !== "string" ||
    typeof parsed.resultId !== "string" ||
    typeof parsed.createdAt !== "string" ||
    typeof parsed.startedAt !== "string" ||
    typeof parsed.endedAt !== "string" ||
    (parsed.entryPoint !== undefined &&
      parsed.entryPoint !== "app" &&
      parsed.entryPoint !== "keyboard" &&
      parsed.entryPoint !== "shortcut") ||
    typeof parsed.durationMs !== "number" ||
    typeof parsed.rawText !== "string" ||
    typeof parsed.finalText !== "string" ||
    !isRecord(parsed.mode) ||
    !isNativeMode(parsed.mode) ||
    (parsed.status !== "succeeded" &&
      parsed.status !== "no_speech" &&
      parsed.status !== "failed")
  ) {
    throw new Error("The native dictation result is invalid.");
  }
  return parsed as NativeResultEnvelope;
}

function isNativeMode(value: Record<string, unknown>) {
  return (
    typeof value.asrModelId === "string" &&
    typeof value.batchModelId === "string" &&
    typeof value.description === "string" &&
    typeof value.iconKey === "string" &&
    typeof value.id === "string" &&
    typeof value.identifySpeakers === "boolean" &&
    typeof value.name === "string" &&
    typeof value.presetKind === "string" &&
    typeof value.realtimeModel === "string"
  );
}

function parseObject(value: string | null) {
  if (!value) return null;
  const parsed: unknown = JSON.parse(value);
  return isRecord(parsed) ? parsed : null;
}

function timingPayload(artifact: Record<string, unknown> | null) {
  const content = artifact?.content;
  return isRecord(content) ? content : null;
}

function detectedLanguage(artifact: Record<string, unknown> | null) {
  const language = artifact?.language;
  if (!isRecord(language)) return null;
  return typeof language.detected === "string" ? language.detected : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export { consumeNativeResult, parseNativeResultEnvelope };
