import type { TranscriptionStreamPart } from "ai";

import type { DeepgramRealtimeEvent } from "../deepgram/realtime/events";
import type { MistralRealtimeEvent } from "../mistral/realtime/events";
import type { RealtimeAsrProviderId } from "../models/types";
import { speakerTurnsFromWords } from "../transcription/speaker-turns";
import type {
  TranscriptSegment,
  TranscriptSpeakerTurn,
  TranscriptWord,
} from "../transcription/types";

export interface RealtimeTranscriptEvent {
  delivery: "complete" | "committed" | "delta" | "interim";
  isFinal: boolean;
  providerEvent: unknown;
  segments: TranscriptSegment[];
  speakerTurns: TranscriptSpeakerTurn[];
  speechFinal?: boolean;
  text: string;
  type: "transcript";
  words: TranscriptWord[];
}

export const realtimeTranscriptEventFromStreamPart = (
  part: TranscriptionStreamPart
): RealtimeTranscriptEvent | null => {
  if (
    part.type === "error" ||
    part.type === "raw" ||
    (part.type !== "transcript-delta" &&
      part.type !== "transcript-partial" &&
      part.type !== "transcript-final")
  ) {
    return null;
  }
  const metadata = timbervoxMetadata(part.providerMetadata?.timbervox);
  const text = part.type === "transcript-delta" ? part.delta : part.text;
  const segments =
    metadata.segments.length > 0
      ? metadata.segments
      : segmentsFromStandardPart(part, text);
  return {
    delivery: deliveryFromStreamPart(part),
    isFinal: part.type === "transcript-final",
    providerEvent: null,
    segments,
    speakerTurns: metadata.speakerTurns,
    ...(metadata.speechFinal === undefined
      ? {}
      : { speechFinal: metadata.speechFinal }),
    text,
    type: "transcript",
    words: metadata.words,
  };
};

const deliveryFromStreamPart = (
  part: Extract<
    TranscriptionStreamPart,
    {
      type: "transcript-delta" | "transcript-final" | "transcript-partial";
    }
  >
): RealtimeTranscriptEvent["delivery"] => {
  if (part.type === "transcript-delta") {
    return "delta";
  }
  return part.type === "transcript-partial" ? "interim" : "committed";
};

interface TimberVoxStreamMetadata {
  segments: TranscriptSegment[];
  speakerTurns: TranscriptSpeakerTurn[];
  speechFinal?: boolean;
  words: TranscriptWord[];
}

const timbervoxMetadata = (value: unknown): TimberVoxStreamMetadata => {
  if (!isRecord(value)) {
    return { segments: [], speakerTurns: [], words: [] };
  }
  return {
    segments: timedTextArray(value.segments),
    speakerTurns: timedTextArray(value.speakerTurns),
    ...(typeof value.speechFinal === "boolean"
      ? { speechFinal: value.speechFinal }
      : {}),
    words: timedTextArray(value.words),
  };
};

const timedTextArray = <
  T extends TranscriptSegment | TranscriptSpeakerTurn | TranscriptWord,
>(
  value: unknown
): T[] => {
  if (!Array.isArray(value)) {
    return [];
  }
  const items: T[] = [];
  for (const item of value) {
    if (
      !isRecord(item) ||
      typeof item.text !== "string" ||
      typeof item.startSeconds !== "number" ||
      typeof item.endSeconds !== "number"
    ) {
      continue;
    }
    items.push(item as T);
  }
  return items;
};

const segmentsFromStandardPart = (
  part: Extract<
    TranscriptionStreamPart,
    {
      type: "transcript-delta" | "transcript-final" | "transcript-partial";
    }
  >,
  text: string
): TranscriptSegment[] => {
  if (part.type === "transcript-delta" || part.startSecond === undefined) {
    return [];
  }
  let endSeconds: number | undefined;
  if (part.type === "transcript-final") {
    endSeconds = part.endSecond;
  } else if (part.durationInSeconds !== undefined) {
    endSeconds = part.startSecond + part.durationInSeconds;
  }
  return endSeconds === undefined
    ? []
    : [{ endSeconds, startSeconds: part.startSecond, text }];
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const wordText = (value: Record<string, unknown>): string | null => {
  const candidate = value.punctuated_word ?? value.text ?? value.word;
  return typeof candidate === "string" && candidate.trim()
    ? candidate.trim()
    : null;
};

const normalizeSpeaker = (value: unknown): string | number | undefined => {
  if (value === null || value === undefined || value === "") {
    return;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    return value;
  }
};

const normalizeWords = (value: unknown): TranscriptWord[] => {
  if (!Array.isArray(value)) {
    return [];
  }
  const words: TranscriptWord[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      continue;
    }
    const raw = item as Record<string, unknown>;
    const text = wordText(raw);
    if (!text || typeof raw.start !== "number" || typeof raw.end !== "number") {
      continue;
    }
    const word: TranscriptWord = {
      endSeconds: raw.end,
      startSeconds: raw.start,
      text,
    };
    if (typeof raw.confidence === "number") {
      word.scores = { confidence: raw.confidence };
    }
    const speaker = normalizeSpeaker(raw.speaker ?? raw.speaker_id);
    if (speaker !== undefined) {
      word.speaker = speaker;
    }
    words.push(word);
  }
  return words;
};

export const normalizeDeepgramTranscriptEvent = (
  event: DeepgramRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type !== "Results") {
    return null;
  }
  const raw = event as Record<string, unknown>;
  const channel = raw.channel as
    | { alternatives?: { transcript?: string; words?: unknown }[] }
    | undefined;
  const [alternative] = channel?.alternatives ?? [];
  const text = alternative?.transcript?.trim();
  if (!text) {
    return null;
  }
  const words = normalizeWords(alternative?.words);
  const startSeconds = typeof raw.start === "number" ? raw.start : undefined;
  const duration = typeof raw.duration === "number" ? raw.duration : undefined;
  const segments: TranscriptSegment[] =
    startSeconds === undefined || duration === undefined
      ? []
      : [
          {
            endSeconds: startSeconds + duration,
            startSeconds,
            text,
          },
        ];
  return {
    delivery: raw.is_final ? "committed" : "interim",
    isFinal: Boolean(raw.is_final),
    providerEvent: event,
    segments,
    speakerTurns: speakerTurnsFromWords(words),
    ...(typeof raw.speech_final === "boolean"
      ? { speechFinal: raw.speech_final }
      : {}),
    text,
    type: "transcript",
    words,
  };
};

export const normalizeMistralTranscriptEvent = (
  event: MistralRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type === "transcription.segment") {
    const segment: TranscriptSegment = {
      endSeconds: event.end,
      speaker: normalizeSpeaker(event.speaker_id),
      startSeconds: event.start,
      text: event.text,
    };
    const speakerTurns: TranscriptSpeakerTurn[] =
      segment.speaker === undefined
        ? []
        : [
            {
              endSeconds: segment.endSeconds,
              speaker: segment.speaker,
              startSeconds: segment.startSeconds,
              text: segment.text,
            },
          ];
    return {
      delivery: "committed",
      isFinal: true,
      providerEvent: event,
      segments: [segment],
      speakerTurns,
      text: event.text,
      type: "transcript",
      words: [],
    };
  }
  if (event.type === "transcription.done") {
    return transcriptEvent(event, event.text, true, "complete");
  }
  if (event.type === "transcription.text.delta") {
    return transcriptEvent(event, event.text, false, "delta");
  }
  return null;
};

const transcriptEvent = (
  providerEvent: unknown,
  text: string,
  isFinal: boolean,
  delivery: RealtimeTranscriptEvent["delivery"]
): RealtimeTranscriptEvent => ({
  delivery,
  isFinal,
  providerEvent,
  segments: [],
  speakerTurns: [],
  text,
  type: "transcript",
  words: [],
});

export const finalRealtimeTranscript = (
  provider: RealtimeAsrProviderId,
  events: readonly RealtimeTranscriptEvent[]
): string => {
  if (provider === "deepgram") {
    return events
      .filter((event) => event.isFinal && event.text)
      .map((event) => event.text)
      .join(" ")
      .trim();
  }

  const deltaText = events
    .filter((event) => event.delivery === "delta")
    .map((event) => event.text)
    .join("")
    .trim();
  if (deltaText) {
    return deltaText;
  }

  const committedText = events
    .filter((event) => event.delivery === "committed")
    .map((event) => event.text.trim())
    .filter(Boolean)
    .join(" ");
  if (committedText) {
    return committedText;
  }

  return (
    events.findLast((event) => event.delivery === "complete")?.text.trim() ?? ""
  );
};
