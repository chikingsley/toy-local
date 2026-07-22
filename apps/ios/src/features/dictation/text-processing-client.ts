import { buildPresetProcessingRequest } from "@/features/modes/preset-contracts";
import type { DictationPlan } from "@/features/dictation/dictation-types";
import {
  configuredVoiceClient,
  voiceApiError,
  withRequestTimeout,
} from "@/lib/peacockery-voice-client";

type TextStreamEvent =
  | { delta: string; protocol_version: 1; type: "text.delta" }
  | {
      error: { message: string };
      protocol_version: 1;
      type: "stream.failed";
    }
  | { protocol_version: 1; type: "stream.completed" | "stream.started" };

async function processDictationText(plan: DictationPlan, transcript: string) {
  const request = buildPresetProcessingRequest({
    presetKind: plan.mode.presetKind,
    processingInstructions: plan.mode.processingInstructions,
    processingModelId: plan.mode.processingModelId,
    transcript,
  });
  if (!request) return null;
  const { data, error, response } = await withRequestTimeout(
    60_000,
    "Text processing",
    (signal) =>
      configuredVoiceClient(plan.credential).POST("/v1/text/stream", {
        body: request,
        parseAs: "text",
        signal,
      }),
  );
  if (error) throw voiceApiError("Text processing", response, error);
  let output = "";
  let completed = false;
  for (const event of parseServerSentEvents(data)) {
    if (event.type === "text.delta") output += event.delta;
    if (event.type === "stream.failed") throw new Error(event.error.message);
    if (event.type === "stream.completed") completed = true;
  }
  if (!completed) throw new Error("Text processing ended without a result.");
  if (!output.trim()) throw new Error("Text processing returned no text.");
  return output;
}

function parseServerSentEvents(payload: string): TextStreamEvent[] {
  const events: TextStreamEvent[] = [];
  for (const block of payload.split(/\r?\n\r?\n/)) {
    const data = block
      .split(/\r?\n/)
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).trimStart())
      .join("\n");
    if (!data) continue;
    let candidate: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(data);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        continue;
      }
      candidate = parsed as Record<string, unknown>;
    } catch {
      // Keepalive comments and sentinel lines such as "[DONE]" are not
      // protocol events; skip them instead of failing the whole stream.
      continue;
    }
    if (
      candidate.protocol_version !== 1 ||
      typeof candidate.type !== "string"
    ) {
      throw new Error("The text service uses an unsupported stream protocol.");
    }
    if (
      candidate.type === "text.delta" &&
      typeof candidate.delta === "string"
    ) {
      events.push(candidate as TextStreamEvent);
    } else if (candidate.type === "stream.failed") {
      const error = candidate.error as Record<string, unknown> | undefined;
      if (!error || typeof error.message !== "string") {
        throw new Error("The text service returned an invalid failure.");
      }
      events.push(candidate as TextStreamEvent);
    } else if (
      candidate.type === "stream.started" ||
      candidate.type === "stream.completed"
    ) {
      events.push(candidate as TextStreamEvent);
    }
  }
  return events;
}

export { parseServerSentEvents, processDictationText };
