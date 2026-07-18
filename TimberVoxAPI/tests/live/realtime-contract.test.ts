import { afterEach, describe, expect, it } from "vitest";

import { liveTestsEnabled } from "./env";
import {
  closeRealtimeSockets,
  type RealtimeCase,
  runRealtimeSession,
} from "./realtime-harness";

const baseUrl = "https://timbervox.peacockery.studio";

const cases: RealtimeCase[] = [
  { model: "deepgram-nova-3", provider: "deepgram" },
  { model: "elevenlabs-scribe_v2", provider: "elevenlabs" },
  {
    model: "mistral-voxtral-mini-transcribe-realtime-2602",
    provider: "mistral",
  },
];

const configuredApiKey = (): string | null =>
  process.env.TIMBERVOX_API_KEY?.trim() || null;

afterEach(() => {
  closeRealtimeSockets();
});

describe.sequential("deployed provider-neutral realtime contract", () => {
  for (const testCase of cases) {
    it(`streams and recovers ${testCase.provider} through one protocol`, async ({
      skip,
    }) => {
      const apiKey = configuredApiKey();
      if (!(liveTestsEnabled && apiKey)) {
        skip("live tests disabled or TIMBERVOX_API_KEY unavailable");
      }
      const events = await runRealtimeSession(testCase, apiKey);
      const started = events.find((event) => event.type === "session.started");
      const completed = events.find(
        (event) => event.type === "session.completed"
      );
      expect(started?.protocol_version).toBe(1);
      expect(completed?.protocol_version).toBe(1);
      const completedResult = completed?.result as
        | Record<string, unknown>
        | undefined;
      const provenance = completedResult?.provenance as
        | Record<string, unknown>
        | undefined;
      expect(provenance?.provider).toBe(testCase.provider);
      expect(String(completedResult?.text ?? "").trim().length).toBeGreaterThan(
        0
      );

      const publicTypes = events
        .map((event) => event.type)
        .filter((type) => typeof type === "string");
      expect(publicTypes).not.toContain("Results");
      expect(publicTypes).not.toContain("transcription.segment");
      expect(publicTypes).not.toContain("transcription.done");

      const response = await fetch(
        `${baseUrl}/v1/realtime/sessions/${started?.session_id}`,
        { headers: { Authorization: `Bearer ${apiKey}` } }
      );
      expect(response.status).toBe(200);
      const recovered = (await response.json()) as Record<string, unknown>;
      expect(recovered.type).toBe("session.completed");
      expect(recovered.result).toEqual(completed?.result);
    }, 60_000);
  }
});
