import { localAsrModule } from "timbervox-local-asr";

import type {
  DictationPlan,
  TranscriptionArtifact,
} from "@/features/dictation/dictation-types";
import type {
  RealtimeTransport,
  RealtimeTransportCallbacks,
} from "@/features/dictation/dictation-workflow";

async function transcribeLocalBatch(
  plan: DictationPlan,
  audioChunks: ArrayBuffer[],
): Promise<TranscriptionArtifact> {
  const text = await localAsrModule().transcribeBatch(joinAudio(audioChunks));
  return localArtifact(plan, text);
}

function createLocalRealtimeTransport(
  plan: DictationPlan,
  callbacks: RealtimeTransportCallbacks,
): RealtimeTransport {
  const nativeModule = localAsrModule();
  const sessionId = `local_${plan.requestId}`;
  let sequence = 0;
  let active = true;
  let audioQueue = Promise.resolve();
  const partialSubscription = nativeModule.addListener(
    "onPartialTranscript",
    (event) => {
      if (!active || typeof event.text !== "string") return;
      callbacks.onMessage(
        protocolEvent(sessionId, ++sequence, "transcript.interim", {
          text: event.text,
        }),
      );
    },
  );

  void nativeModule
    .startRealtime()
    .then(() => {
      if (!active) return;
      callbacks.onOpen();
      callbacks.onMessage(
        protocolEvent(sessionId, ++sequence, "session.started", {
          language: plan.mode.language,
          model: plan.executor.model,
        }),
      );
    })
    .catch((error: unknown) => {
      if (active) callbacks.onError(errorMessage(error));
    });

  return {
    close: () => {
      if (!active) return;
      active = false;
      partialSubscription.remove();
      void nativeModule.cancelRealtime();
    },
    finalize: () => {
      audioQueue = audioQueue
        .then(() => nativeModule.finishRealtime())
        .then((text) => {
          if (!active) return;
          callbacks.onMessage(
            protocolEvent(sessionId, ++sequence, "session.completed", {
              result: localArtifact(plan, text),
            }),
          );
        })
        .catch((error: unknown) => {
          if (active) callbacks.onError(errorMessage(error));
        });
    },
    sendAudio: (audio) => {
      const bytes = new Uint8Array(audio.slice(0));
      audioQueue = audioQueue
        .then(() => nativeModule.sendRealtimeAudio(bytes))
        .catch((error: unknown) => {
          if (active) callbacks.onError(errorMessage(error));
        });
    },
  };
}

function localArtifact(
  plan: DictationPlan,
  text: string,
): TranscriptionArtifact {
  return {
    content: null,
    language: {
      detected: plan.mode.language ?? "en",
      requested: plan.mode.language,
    },
    model: plan.executor.model,
    provider: plan.executor.provider,
    schema_version: 2,
    text: text.trim(),
  };
}

function joinAudio(chunks: ArrayBuffer[]) {
  const byteLength = chunks.reduce(
    (total, chunk) => total + chunk.byteLength,
    0,
  );
  const joined = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    joined.set(new Uint8Array(chunk), offset);
    offset += chunk.byteLength;
  }
  return joined;
}

function protocolEvent(
  sessionId: string,
  sequence: number,
  type: string,
  fields: Record<string, unknown>,
) {
  return JSON.stringify({
    protocol_version: 1,
    sequence,
    session_id: sessionId,
    type,
    ...fields,
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Local transcription failed.";
}

export { createLocalRealtimeTransport, transcribeLocalBatch };
