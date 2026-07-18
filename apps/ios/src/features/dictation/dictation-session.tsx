import {
  requestRecordingPermissionsAsync,
  setAudioModeAsync,
  useAudioStream,
  type AudioStreamBuffer,
} from "expo-audio";
import * as Linking from "expo-linking";
import { useSQLiteContext } from "expo-sqlite";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { AppState } from "react-native";

import { persistDictationOutcome } from "@/features/dictation/dictation-repository";
import { transcribeCloudBatch } from "@/features/dictation/cloud-batch-client";
import {
  createLocalRealtimeTransport,
  transcribeLocalBatch,
} from "@/features/dictation/local-asr";
import { useLocalModelPackage } from "@/features/dictation/local-model-package";
import { consumeNativeResult } from "@/features/dictation/native-result-bridge";
import { deliverDictationResult } from "@/features/dictation/result-delivery";
import { processDictationText } from "@/features/dictation/text-processing-client";
import type {
  DictationEntryPoint,
  DictationFailure,
  DictationModeSnapshot,
  DictationPlan,
  DictationStage,
  DictationWorkflowSnapshot,
} from "@/features/dictation/dictation-types";
import { DictationWorkflow } from "@/features/dictation/dictation-workflow";
import {
  API_ORIGIN,
  createWebSocketTransport,
  recoverRealtimeSession,
} from "@/features/dictation/websocket-transport";
import { useHistory } from "@/features/history/history-store";
import { configuredApiCredential } from "@/lib/api-credential";
import {
  initializeAppGroupBridge,
  readBridgeBoolean,
  readBridgeNumber,
  readBridgeString,
  writeBridgeBoolean,
  writeBridgeNumber,
  writeBridgeString,
} from "@/features/keyboard/app-group-bridge";
import {
  selectedRoute,
  selectedTranscriptionModel,
  type ModelCatalog,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import type { Mode } from "@/features/modes/mode-types";

const buildCredential = configuredApiCredential();

type DictationSessionValue = {
  cancelDictation: () => void;
  endSession: () => Promise<void>;
  error: string | null;
  errorCode: string | null;
  finalizing: boolean;
  lastTranscript: string;
  partialTranscript: string;
  recording: boolean;
  recover: () => Promise<void>;
  recoveryLabel: string | null;
  sessionActive: boolean;
  stage: DictationStage;
  startDictation: () => Promise<void>;
  startSession: () => Promise<boolean>;
  stateLabel: string;
  stopDictation: () => void;
};

const INITIAL_SNAPSHOT: DictationWorkflowSnapshot = {
  error: null,
  finalText: "",
  requestId: null,
  resultId: null,
  sessionId: null,
  stage: "idle",
  visibleText: "",
};

const DictationSessionContext = createContext<DictationSessionValue | null>(
  null,
);

export function DictationSessionProvider({ children }: PropsWithChildren) {
  initializeAppGroupBridge();
  const database = useSQLiteContext();
  const history = useHistory();
  const historyReload = history.reload;
  const modes = useModes();
  const localPackage = useLocalModelPackage();
  const [snapshot, setSnapshot] =
    useState<DictationWorkflowSnapshot>(INITIAL_SNAPSHOT);
  const sessionActiveRef = useRef(false);
  const lastEntryPointRef = useRef<DictationEntryPoint>("app");
  const lastRequestRevisionRef = useRef(readBridgeNumber("requestRevision"));
  const activeModeRef = useRef<Mode | null>(modes.activeMode);
  const catalogRef = useRef<ModelCatalog | null>(modes.catalog);
  const consumingNativeResultRef = useRef(false);

  const workflow = useMemo(
    () =>
      new DictationWorkflow({
        createTransport: (plan, callbacks) =>
          plan.executor.kind === "local-realtime"
            ? createLocalRealtimeTransport(plan, callbacks)
            : createWebSocketTransport(plan, callbacks),
        deliver: deliverDictationResult,
        onChange: setSnapshot,
        persist: async (outcome) => {
          await persistDictationOutcome(database, outcome);
          await historyReload();
        },
        process: processDictationText,
        recover: (plan, sessionId, credential) => {
          if (plan.executor.kind !== "cloud-realtime") {
            throw new Error("Local realtime recovery is unavailable.");
          }
          return recoverRealtimeSession(sessionId, credential);
        },
        transcribeBatch: (plan, audioChunks) =>
          plan.executor.kind === "local-batch"
            ? transcribeLocalBatch(plan, audioChunks)
            : transcribeCloudBatch(plan, audioChunks),
      }),
    [database, historyReload],
  );
  const workflowRef = useRef(workflow);

  useEffect(() => {
    workflowRef.current = workflow;
  }, [workflow]);

  useEffect(() => {
    activeModeRef.current = modes.activeMode;
    catalogRef.current = modes.catalog;
  }, [modes.activeMode, modes.catalog]);

  useEffect(() => {
    writeBridgeString("apiBaseURL", API_ORIGIN);
    writeBridgeString("apiCredential", buildCredential);
  }, []);

  const importNativeResult = useCallback(async () => {
    if (consumingNativeResultRef.current) return;
    consumingNativeResultRef.current = true;
    try {
      if (await consumeNativeResult(database)) await historyReload();
    } finally {
      consumingNativeResultRef.current = false;
    }
  }, [database, historyReload]);

  useEffect(() => {
    void importNativeResult();
    const subscription = AppState.addEventListener("change", (state) => {
      if (state === "active") void importNativeResult();
    });
    return () => subscription.remove();
  }, [importNativeResult]);

  const beginDictation = useCallback(
    (entryPoint: DictationEntryPoint, requestedId?: string) => {
      const plan = createPlan(
        activeModeRef.current,
        catalogRef.current,
        entryPoint,
        buildCredential,
        localPackage.ready,
        requestedId,
      );
      if (!plan.ok) {
        workflowRef.current.failBeforeStart(plan.error);
        writeBridgeBoolean("recordingRequested", false);
        return false;
      }
      const started = workflowRef.current.start(plan.value);
      if (started) {
        lastEntryPointRef.current = entryPoint;
        writeBridgeString("partialTranscript", "");
        writeBridgeString("activeRequestId", plan.value.requestId);
      }
      return started;
    },
    [localPackage.ready],
  );

  const handleAudioBuffer = useCallback(
    (buffer: AudioStreamBuffer) => {
      if (!sessionActiveRef.current) return;
      const revision = readBridgeNumber("requestRevision");
      if (revision !== lastRequestRevisionRef.current) {
        lastRequestRevisionRef.current = revision;
        if (
          readBridgeBoolean("recordingRequested") &&
          readBridgeString("requestedEntryPoint") === "keyboard"
        ) {
          beginDictation("keyboard", readBridgeString("keyboardRequestId"));
        } else if (!readBridgeBoolean("recordingRequested")) {
          workflowRef.current.stop();
        }
      }
      if (!readBridgeBoolean("recordingRequested")) return;
      workflowRef.current.receiveAudio(buffer.data);
    },
    [beginDictation],
  );

  const { stream } = useAudioStream({
    channels: 1,
    encoding: "int16",
    onBuffer: handleAudioBuffer,
    sampleRate: 16_000,
  });

  const startSession = useCallback(async () => {
    if (sessionActiveRef.current) {
      workflowRef.current.ready();
      return true;
    }
    const pendingKeyboardRequestId =
      readBridgeBoolean("recordingRequested") &&
      readBridgeString("requestedEntryPoint") === "keyboard"
        ? readBridgeString("keyboardRequestId")
        : undefined;
    const permission = await requestRecordingPermissionsAsync();
    if (!permission.granted) {
      workflowRef.current.failBeforeStart({
        action: "open-settings",
        code: "microphone_denied",
        message: "Microphone access is required to dictate.",
        retryable: true,
      });
      return false;
    }
    try {
      await setAudioModeAsync({
        allowsBackgroundRecording: true,
        allowsRecording: true,
        playsInSilentMode: true,
      });
      await stream.start();
      writeBridgeBoolean("sessionActive", true);
      sessionActiveRef.current = true;
      workflowRef.current.ready();
      if (pendingKeyboardRequestId) {
        lastRequestRevisionRef.current = readBridgeNumber("requestRevision");
        writeBridgeBoolean("recordingRequested", true);
        if (!beginDictation("keyboard", pendingKeyboardRequestId)) {
          writeBridgeBoolean("recordingRequested", false);
        }
      } else {
        writeBridgeBoolean("recordingRequested", false);
      }
      return true;
    } catch {
      workflowRef.current.failBeforeStart({
        action: "retry-session",
        code: "interrupted_input",
        message: "TimberVox could not start the microphone session.",
        retryable: true,
      });
      return false;
    }
  }, [beginDictation, stream]);

  const startDictation = useCallback(async () => {
    if (!sessionActiveRef.current && !(await startSession())) return;
    writeBridgeString("requestedEntryPoint", "app");
    writeBridgeBoolean("recordingRequested", true);
    writeBridgeNumber(
      "requestRevision",
      readBridgeNumber("requestRevision") + 1,
    );
    if (!beginDictation("app")) writeBridgeBoolean("recordingRequested", false);
  }, [beginDictation, startSession]);

  const stopDictation = useCallback(() => {
    writeBridgeBoolean("recordingRequested", false);
    writeBridgeNumber(
      "requestRevision",
      readBridgeNumber("requestRevision") + 1,
    );
    workflowRef.current.stop();
  }, []);

  const cancelDictation = useCallback(() => {
    writeBridgeBoolean("recordingRequested", false);
    writeBridgeNumber(
      "requestRevision",
      readBridgeNumber("requestRevision") + 1,
    );
    writeBridgeString("partialTranscript", "");
    workflowRef.current.cancel();
  }, []);

  const endSession = useCallback(async () => {
    workflowRef.current.cancel();
    stream.stop();
    writeBridgeBoolean("sessionActive", false);
    writeBridgeBoolean("recordingRequested", false);
    writeBridgeString("partialTranscript", "");
    sessionActiveRef.current = false;
    workflowRef.current.idle();
  }, [stream]);

  const recover = useCallback(async () => {
    const action = workflowRef.current.current.error?.action;
    if (action === "open-settings") {
      await Linking.openSettings();
      return;
    }
    if (action === "retry-save") {
      await workflowRef.current.retrySave();
      return;
    }
    if (action === "retry-delivery") {
      await workflowRef.current.retryDelivery();
      return;
    }
    if (action === "retry-session") {
      if (!(await startSession())) return;
    }
    writeBridgeBoolean("recordingRequested", true);
    writeBridgeString("requestedEntryPoint", lastEntryPointRef.current);
    writeBridgeNumber(
      "requestRevision",
      readBridgeNumber("requestRevision") + 1,
    );
    beginDictation(lastEntryPointRef.current);
  }, [beginDictation, startSession]);

  useEffect(() => {
    if (lastEntryPointRef.current === "keyboard") {
      writeBridgeString("partialTranscript", snapshot.visibleText);
    }
    if (snapshot.stage === "result") {
      writeBridgeBoolean("recordingRequested", false);
      writeBridgeString("activeRequestId", "");
      const timer = setTimeout(
        () => workflowRef.current.acknowledgeResult(),
        1_100,
      );
      return () => clearTimeout(timer);
    } else if (snapshot.stage === "error") {
      writeBridgeBoolean("recordingRequested", false);
    }
    return undefined;
  }, [snapshot]);

  useEffect(() => {
    const handleURL = ({ url }: { url: string }) => {
      const parsed = Linking.parse(url);
      if (parsed.hostname === "session" || parsed.path === "session") {
        void startSession();
      }
    };
    const subscription = Linking.addEventListener("url", handleURL);
    void Linking.getInitialURL().then((url) => url && handleURL({ url }));
    return () => subscription.remove();
  }, [startSession]);

  const value = useMemo<DictationSessionValue>(
    () => ({
      cancelDictation,
      endSession,
      error: snapshot.error?.message ?? null,
      errorCode: snapshot.error?.code ?? null,
      finalizing: snapshot.stage === "finalizing",
      lastTranscript: snapshot.finalText,
      partialTranscript: snapshot.visibleText,
      recording:
        snapshot.stage === "connecting" || snapshot.stage === "listening",
      recover,
      recoveryLabel: recoveryLabel(snapshot.error),
      sessionActive: snapshot.stage !== "idle",
      stage: snapshot.stage,
      startDictation,
      startSession,
      stateLabel: stageLabel(snapshot.stage, snapshot.finalText),
      stopDictation,
    }),
    [
      cancelDictation,
      endSession,
      recover,
      snapshot,
      startDictation,
      startSession,
      stopDictation,
    ],
  );

  return (
    <DictationSessionContext.Provider value={value}>
      {children}
    </DictationSessionContext.Provider>
  );
}

export function useDictationSession() {
  const value = useContext(DictationSessionContext);
  if (!value) {
    throw new Error(
      "useDictationSession must be used inside DictationSessionProvider",
    );
  }
  return value;
}

function createPlan(
  mode: Mode | null,
  catalog: ModelCatalog | null,
  entryPoint: DictationEntryPoint,
  credential: string,
  localPackageReady: boolean,
  requestedId?: string,
): { ok: true; value: DictationPlan } | { error: DictationFailure; ok: false } {
  if (!mode || !catalog) {
    return {
      error: {
        action: "retry-session",
        code: "unsupported_model",
        message: "The active mode is not ready yet.",
        retryable: true,
      },
      ok: false,
    };
  }
  const model = selectedTranscriptionModel(catalog, mode.asrModelId);
  const route = selectedRoute(model, mode.realtimeEnabled);
  if (!model || !route) {
    return {
      error: {
        action: "reconnect",
        code: "unsupported_model",
        message:
          "This mode does not have a supported iPhone transcription route.",
        retryable: false,
      },
      ok: false,
    };
  }
  if (model.runtime === "local" && !localPackageReady) {
    return {
      error: {
        action: "reconnect",
        code: "unsupported_model",
        message: "Download Parakeet Local before using this mode.",
        retryable: false,
      },
      ok: false,
    };
  }
  if (model.runtime === "cloud" && !credential) {
    return {
      error: {
        action: "retry-session",
        code: "missing_mobile_session",
        message: "This build does not have an active TimberVox session.",
        retryable: true,
      },
      ok: false,
    };
  }
  const realtime = route === model.realtime;
  const snapshot: DictationModeSnapshot = {
    asrModelId: mode.asrModelId,
    description: mode.description,
    iconKey: mode.iconKey,
    id: mode.id,
    identifySpeakers: mode.identifySpeakers,
    language: mode.language,
    name: mode.name,
    presetKind: mode.presetKind,
    processingInstructions: mode.processingInstructions,
    processingModelId: mode.processingModelId,
    realtimeModel: model.realtime?.model ?? "",
  };
  return {
    ok: true,
    value: {
      credential,
      entryPoint,
      executor: {
        kind:
          model.runtime === "local"
            ? realtime
              ? "local-realtime"
              : "local-batch"
            : realtime
              ? "cloud-realtime"
              : "cloud-batch",
        model: route.model,
        provider: route.provider,
      },
      mode: snapshot,
      requestId: requestedId || createRequestId(),
    },
  };
}

function createRequestId() {
  return `request_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function stageLabel(stage: DictationStage, finalText: string) {
  switch (stage) {
    case "idle":
      return "Session off";
    case "ready":
      return "Ready";
    case "connecting":
      return "Connecting…";
    case "listening":
      return "Listening…";
    case "finalizing":
      return "Finishing…";
    case "result":
      return finalText.trim() ? "Saved" : "No speech detected";
    case "error":
      return "Needs attention";
  }
}

function recoveryLabel(error: DictationFailure | null) {
  if (!error) return null;
  switch (error.action) {
    case "open-settings":
      return "Open Settings";
    case "retry-session":
      return "Retry Session";
    case "reconnect":
      return "Retry";
    case "retry-save":
      return "Retry Save";
    case "retry-delivery":
      return "Retry Delivery";
  }
}
