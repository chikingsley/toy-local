import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { afterEach, describe, expect, it } from "vitest";
import WebSocket from "ws";

import { liveTestsEnabled } from "./env";

const baseUrl = "https://timbervox.peacockery.studio";
const fixturePath = resolve("tests/fixtures/audio/asr-smoke.wav");
const activeSockets = new Set<WebSocket>();

interface RealtimeCase {
  model: string;
  provider: "deepgram" | "elevenlabs" | "mistral";
}

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

const wavAudio = async (): Promise<{
  audio: Buffer;
  sampleRate: number;
}> => {
  const wav = await readFile(fixturePath);
  const sampleRate = wav.readUInt32LE(24);
  let offset = 12;
  while (offset + 8 <= wav.length) {
    const id = wav.toString("ascii", offset, offset + 4);
    const size = wav.readUInt32LE(offset + 4);
    const dataStart = offset + 8;
    if (id === "data") {
      return {
        audio: wav.subarray(dataStart, dataStart + size),
        sampleRate,
      };
    }
    offset = dataStart + size + (size % 2);
  }
  throw new Error("live WAV fixture has no data chunk");
};

const openSocket = (url: string, apiKey: string): Promise<WebSocket> =>
  new Promise((resolveSocket, reject) => {
    const socket = new WebSocket(url, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    activeSockets.add(socket);
    socket.once("open", () => resolveSocket(socket));
    socket.once("error", reject);
  });

const runRealtimeSession = async (
  testCase: RealtimeCase,
  apiKey: string
): Promise<Record<string, unknown>[]> => {
  const { audio, sampleRate } = await wavAudio();
  const url = new URL("/v1/realtime", baseUrl);
  url.protocol = "wss:";
  url.searchParams.set("encoding", "linear16");
  url.searchParams.set("interim_results", "true");
  url.searchParams.set("model", testCase.model);
  url.searchParams.set("punctuate", "true");
  url.searchParams.set("sample_rate", String(sampleRate));

  const socket = await openSocket(url.toString(), apiKey);
  const events: Record<string, unknown>[] = [];
  const terminal = new Promise<void>((resolveTerminal, reject) => {
    const timeout = setTimeout(
      () =>
        reject(new Error(`${testCase.provider} realtime session timed out`)),
      45_000
    );
    socket.on("message", (data) => {
      const event = JSON.parse(data.toString()) as Record<string, unknown>;
      events.push(event);
      if (event.type === "session.completed") {
        clearTimeout(timeout);
        resolveTerminal();
      } else if (event.type === "session.failed") {
        clearTimeout(timeout);
        reject(new Error(JSON.stringify(event.error)));
      }
    });
    socket.once("close", (code, reason) => {
      activeSockets.delete(socket);
      if (!events.some((event) => event.type === "session.completed")) {
        clearTimeout(timeout);
        reject(
          new Error(
            `${testCase.provider} socket closed before completion ` +
              `(code ${code}, reason ${reason.toString()}, events ${events
                .map((event) => String(event.type))
                .join(", ")})`
          )
        );
      }
    });
  });

  const chunkBytes = Math.max(320, Math.round((sampleRate * 2) / 10));
  for (let offset = 0; offset < audio.length; offset += chunkBytes) {
    socket.send(audio.subarray(offset, offset + chunkBytes));
    // biome-ignore lint/performance/noAwaitInLoops: preserve realtime chunk order and avoid provider burst limits.
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 10));
  }
  socket.send(JSON.stringify({ type: "close" }));
  await terminal;
  return events;
};

afterEach(() => {
  for (const socket of activeSockets) {
    socket.close();
  }
  activeSockets.clear();
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
