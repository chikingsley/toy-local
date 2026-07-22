import type { ModePresetKind } from "@/features/modes/mode-types";

export type DictationEntryPoint = "app" | "keyboard" | "shortcut";

export type DictationStage =
  | "idle"
  | "ready"
  | "connecting"
  | "listening"
  | "finalizing"
  | "result"
  | "error";

export type DictationRecoveryAction =
  | "open-settings"
  | "retry-session"
  | "reconnect"
  | "retry-save"
  | "retry-delivery";

export type DictationFailureCode =
  | "microphone_denied"
  | "missing_mobile_session"
  | "connection_timeout"
  | "interrupted_input"
  | "provider_error"
  | "persistence_failure"
  | "delivery_failure"
  | "unsupported_model"
  | "unsupported_protocol";

export type DictationFailure = {
  action: DictationRecoveryAction;
  code: DictationFailureCode;
  message: string;
  retryable: boolean;
};

export type DictationModeSnapshot = {
  asrModelId: string;
  description: string;
  iconKey: string;
  id: string;
  identifySpeakers: boolean;
  language: string | null;
  name: string;
  presetKind: ModePresetKind;
  processingInstructions: string | null;
  processingModelId: string | null;
  realtimeModel: string;
};

export type TranscriptionArtifact = Record<string, unknown> & {
  schema_version: 2;
  text: string;
};

export type DictationPlan = {
  credential: string;
  entryPoint: DictationEntryPoint;
  executor: {
    kind: "cloud-batch" | "cloud-realtime" | "local-batch" | "local-realtime";
    model: string;
    provider: string;
  };
  mode: DictationModeSnapshot;
  requestId: string;
};

export type PersistedArtifact = {
  id: string;
  kind: "processed" | "raw" | "segmented";
  modelId: string | null;
  payload: Record<string, unknown> | null;
  text: string;
  timing: Record<string, unknown> | null;
};

export type DictationOutcome = {
  artifacts: PersistedArtifact[];
  audioChunks: ArrayBuffer[];
  createdAt: string;
  durationMs: number;
  endedAt: string;
  entryPoint: DictationEntryPoint;
  error: { code: string; message: string } | null;
  language: string | null;
  mode: DictationModeSnapshot;
  requestId: string;
  resultId: string;
  startedAt: string;
  status: "failed" | "no_speech" | "succeeded";
};

export type DictationWorkflowSnapshot = {
  error: DictationFailure | null;
  finalText: string;
  requestId: string | null;
  // True while stage is "result" and the delivered dictation contained text;
  // false for a no-speech result, whose row still lands in History.
  resultHadText: boolean;
  resultId: string | null;
  sessionId: string | null;
  stage: DictationStage;
  visibleText: string;
};
