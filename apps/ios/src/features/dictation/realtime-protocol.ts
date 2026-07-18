import type { TranscriptionArtifact } from "@/features/dictation/dictation-types";

const REALTIME_PROTOCOL_VERSION = 1;
const TRANSCRIPTION_ARTIFACT_SCHEMA_VERSION = 2;

type RealtimeProtocolEvent =
  | {
      language: string | null;
      model: string;
      sequence: number;
      sessionId: string;
      type: "session.started";
    }
  | {
      sequence: number;
      sessionId: string;
      text: string;
      type: "transcript.committed" | "transcript.delta" | "transcript.interim";
    }
  | {
      result: TranscriptionArtifact;
      sequence: number;
      sessionId: string;
      type: "session.completed";
    }
  | {
      error: {
        code: string;
        message: string;
        retryable: boolean;
      };
      result: TranscriptionArtifact;
      sequence: number;
      sessionId: string;
      type: "session.failed";
    };

class RealtimeProtocolError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RealtimeProtocolError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function parseArtifact(value: unknown): TranscriptionArtifact {
  if (
    !isRecord(value) ||
    value.schema_version !== TRANSCRIPTION_ARTIFACT_SCHEMA_VERSION ||
    typeof value.text !== "string"
  ) {
    throw new RealtimeProtocolError(
      "The transcription result uses an unsupported artifact schema.",
    );
  }
  return value as TranscriptionArtifact;
}

function parseRealtimeEvent(raw: string): RealtimeProtocolEvent | null {
  let candidate: unknown;
  try {
    candidate = JSON.parse(raw);
  } catch {
    throw new RealtimeProtocolError("The realtime service sent invalid JSON.");
  }
  if (!isRecord(candidate) || typeof candidate.type !== "string") return null;

  const relevant =
    candidate.type === "session.started" ||
    candidate.type === "session.completed" ||
    candidate.type === "session.failed" ||
    candidate.type === "transcript.delta" ||
    candidate.type === "transcript.interim" ||
    candidate.type === "transcript.committed";
  if (!relevant) return null;
  if (candidate.protocol_version !== REALTIME_PROTOCOL_VERSION) {
    throw new RealtimeProtocolError(
      "The realtime service uses an unsupported protocol version.",
    );
  }
  if (
    !Number.isInteger(candidate.sequence) ||
    typeof candidate.session_id !== "string" ||
    !candidate.session_id
  ) {
    throw new RealtimeProtocolError("The realtime event is incomplete.");
  }
  const base = {
    sequence: candidate.sequence as number,
    sessionId: candidate.session_id,
  };

  if (candidate.type === "session.started") {
    if (
      typeof candidate.model !== "string" ||
      (candidate.language !== null && typeof candidate.language !== "string")
    ) {
      throw new RealtimeProtocolError("The session-start event is invalid.");
    }
    return {
      ...base,
      language: candidate.language,
      model: candidate.model,
      type: "session.started",
    };
  }
  if (
    candidate.type === "transcript.delta" ||
    candidate.type === "transcript.interim" ||
    candidate.type === "transcript.committed"
  ) {
    if (typeof candidate.text !== "string") {
      throw new RealtimeProtocolError("The transcript event has no text.");
    }
    return { ...base, text: candidate.text, type: candidate.type };
  }
  if (candidate.type === "session.completed") {
    return {
      ...base,
      result: parseArtifact(candidate.result),
      type: "session.completed",
    };
  }

  if (
    !isRecord(candidate.error) ||
    typeof candidate.error.message !== "string"
  ) {
    throw new RealtimeProtocolError("The failed-session event is invalid.");
  }
  return {
    ...base,
    error: {
      code:
        typeof candidate.error.code === "string"
          ? candidate.error.code
          : "provider_error",
      message: candidate.error.message,
      retryable: candidate.error.retryable !== false,
    },
    result: parseArtifact(candidate.result),
    type: "session.failed",
  };
}

export {
  parseRealtimeEvent,
  REALTIME_PROTOCOL_VERSION,
  RealtimeProtocolError,
  TRANSCRIPTION_ARTIFACT_SCHEMA_VERSION,
};
export type { RealtimeProtocolEvent };
