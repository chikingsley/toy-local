import type { DictationPlan } from "@/features/dictation/dictation-types";
import {
  parseRealtimeEvent,
  type RealtimeProtocolEvent,
} from "@/features/dictation/realtime-protocol";
import type {
  RealtimeTransport,
  RealtimeTransportCallbacks,
} from "@/features/dictation/dictation-workflow";

const API_ORIGIN = "https://timbervox.peacockery.studio";
const REALTIME_ORIGIN = "wss://timbervox.peacockery.studio";

function createWebSocketTransport(
  plan: DictationPlan,
  callbacks: RealtimeTransportCallbacks,
): RealtimeTransport {
  const params = new URLSearchParams({
    channels: "1",
    diarize: String(plan.mode.identifySpeakers),
    dictation: "true",
    encoding: "linear16",
    interim_results: "true",
    model: plan.mode.realtimeModel,
    punctuate: "true",
    sample_rate: "16000",
    target_streaming_delay_ms: "200",
  });
  if (plan.mode.language) params.set("language", plan.mode.language);
  const WebSocketWithHeaders = WebSocket as unknown as new (
    url: string,
    protocols: string[],
    options: { headers: Record<string, string> },
  ) => WebSocket;
  const socket = new WebSocketWithHeaders(
    `${REALTIME_ORIGIN}/v1/realtime?${params.toString()}`,
    [],
    { headers: { Authorization: `Bearer ${plan.credential}` } },
  );
  socket.binaryType = "arraybuffer";
  socket.onopen = callbacks.onOpen;
  socket.onmessage = (event) => {
    if (typeof event.data === "string") callbacks.onMessage(event.data);
  };
  socket.onerror = () => {
    callbacks.onError("The realtime transcription connection failed.");
  };
  socket.onclose = callbacks.onClose;
  return {
    close: () => socket.close(),
    finalize: () => {
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "close" }));
      } else {
        socket.close();
      }
    },
    sendAudio: (audio) => {
      if (socket.readyState === WebSocket.OPEN) socket.send(audio);
    },
  };
}

async function recoverRealtimeSession(
  sessionId: string,
  credential: string,
): Promise<RealtimeProtocolEvent> {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const response = await fetch(
      `${API_ORIGIN}/v1/realtime/sessions/${encodeURIComponent(sessionId)}`,
      { headers: { Authorization: `Bearer ${credential}` } },
    );
    if (response.ok) {
      const event = parseRealtimeEvent(JSON.stringify(await response.json()));
      if (!event) {
        throw new Error("Realtime recovery returned no terminal result.");
      }
      return event;
    }
    if (response.status !== 404 && response.status < 500) {
      throw new Error(`Realtime recovery failed (${response.status}).`);
    }
    if (attempt < 7) await delay(500);
  }
  throw new Error("Realtime recovery timed out.");
}

function delay(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

export { API_ORIGIN, createWebSocketTransport, recoverRealtimeSession };
