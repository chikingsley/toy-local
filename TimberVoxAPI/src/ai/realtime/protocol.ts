import type { TranscriptionArtifact } from "../transcription/artifact";
import type {
  TranscriptSegment,
  TranscriptSpeakerTurn,
  TranscriptWord,
} from "../transcription/types";
import type { RealtimeTranscriptEvent } from "./normalize";

const REALTIME_PROTOCOL_VERSION = 1 as const;

interface RealtimeEventBase {
  protocol_version: typeof REALTIME_PROTOCOL_VERSION;
  sequence: number;
  session_id: string;
}

export interface RealtimeSessionStartedEvent extends RealtimeEventBase {
  language: string | null;
  model: string;
  type: "session.started";
}

export interface RealtimeTranscriptProtocolEvent extends RealtimeEventBase {
  segments: TranscriptSegment[];
  speaker_turns: TranscriptSpeakerTurn[];
  speech_final?: boolean;
  text: string;
  type: "transcript.committed" | "transcript.delta" | "transcript.interim";
  words: TranscriptWord[];
}

interface RealtimeSessionCompletedEvent extends RealtimeEventBase {
  result: TranscriptionArtifact;
  status: "succeeded";
  type: "session.completed";
}

interface RealtimeSessionFailedEvent extends RealtimeEventBase {
  error: {
    code: "provider_error" | "session_error";
    message: string;
    retryable: boolean;
  };
  result: TranscriptionArtifact;
  status: "failed";
  type: "session.failed";
}

export type RealtimeSessionTerminalEvent =
  | RealtimeSessionCompletedEvent
  | RealtimeSessionFailedEvent;

export interface RealtimeProtocolSession {
  error?: string | null;
  errorCode?: "provider_error" | "session_error";
  result: TranscriptionArtifact;
  sessionId: string;
  status: "failed" | "succeeded";
}

export const sessionStartedEvent = (input: {
  language: string | null;
  model: string;
  sequence: number;
  sessionId: string;
}): RealtimeSessionStartedEvent => ({
  language: input.language,
  model: input.model,
  protocol_version: REALTIME_PROTOCOL_VERSION,
  sequence: input.sequence,
  session_id: input.sessionId,
  type: "session.started",
});

export const transcriptProtocolEvent = (
  sessionId: string,
  sequence: number,
  event: RealtimeTranscriptEvent
): RealtimeTranscriptProtocolEvent | null => {
  if (event.delivery === "complete") {
    return null;
  }
  let type: RealtimeTranscriptProtocolEvent["type"] = "transcript.interim";
  if (event.delivery === "committed") {
    type = "transcript.committed";
  } else if (event.delivery === "delta") {
    type = "transcript.delta";
  }
  return {
    protocol_version: REALTIME_PROTOCOL_VERSION,
    segments: event.segments,
    sequence,
    session_id: sessionId,
    speaker_turns: event.speakerTurns,
    ...(event.speechFinal === undefined
      ? {}
      : { speech_final: event.speechFinal }),
    text: event.text,
    type,
    words: event.words,
  };
};

export const terminalSessionEvent = (
  session: RealtimeProtocolSession,
  sequence: number
): RealtimeSessionTerminalEvent => {
  const base = {
    protocol_version: REALTIME_PROTOCOL_VERSION,
    result: session.result,
    sequence,
    session_id: session.sessionId,
  } as const;
  if (session.status === "failed") {
    return {
      ...base,
      error: {
        code: session.errorCode ?? "provider_error",
        message: session.error ?? "realtime transcription failed",
        retryable: true,
      },
      status: "failed",
      type: "session.failed",
    };
  }
  return {
    ...base,
    status: "succeeded",
    type: "session.completed",
  };
};
