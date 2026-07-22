import type { SQLiteDatabase } from "expo-sqlite";

import type { StoredDictationDetail } from "@/features/dictation/dictation-repository";
import { reprocessStoredDictation } from "@/features/history/history-reprocess";

const detail: StoredDictationDetail = {
  artifacts: [
    {
      id: "dictation_1_raw",
      kind: "raw",
      modelId: "voxtral-mini",
      payload: null,
      text: "rough spoken words",
      timing: null,
    },
  ],
  audioFormat: "audio/wav",
  audioSizeBytes: 48,
  audioUri: "file:///recordings/request_1_dictation_1.wav",
  createdAt: "2026-07-18T10:00:00.000Z",
  durationMs: 2_000,
  endedAt: "2026-07-18T10:00:02.000Z",
  entryPoint: "app",
  error: null,
  id: "dictation_1",
  language: "en",
  mode: {
    asrModelId: "voxtral-mini",
    description: "A concise message",
    iconKey: "message.fill",
    id: "mode_message",
    identifySpeakers: false,
    language: "en",
    name: "Message",
    presetKind: "message",
    processingInstructions: "Rewrite this as a concise message.",
    processingModelId: "gpt-5-mini",
    realtimeModel: "voxtral-mini-transcribe-realtime-2602",
  },
  modelId: "voxtral-mini",
  requestId: "request_1",
  startedAt: "2026-07-18T10:00:00.000Z",
  status: "succeeded",
  text: "rough spoken words",
  wordCount: 3,
};

function databaseThatRuns() {
  const runAsync = jest.fn(async (_query: string, ..._params: unknown[]) => ({
    changes: 1,
  }));
  const database = {
    runAsync,
    withExclusiveTransactionAsync: jest.fn(
      async (task: (transaction: SQLiteDatabase) => Promise<void>) => {
        await task({ runAsync } as unknown as SQLiteDatabase);
      },
    ),
  } as unknown as SQLiteDatabase;
  return { database, runAsync };
}

describe("history reprocessing", () => {
  it("links a processing run to Raw input and a Processed output", async () => {
    const { database, runAsync } = databaseThatRuns();
    const dates = [
      new Date("2026-07-18T10:01:00.000Z"),
      new Date("2026-07-18T10:01:01.000Z"),
    ];

    const result = await reprocessStoredDictation(database, detail, "token", {
      createId: () => "processing_1",
      now: () => dates.shift()!,
      process: jest.fn(async () => "A concise message."),
    });

    expect(result).toEqual({
      output: "A concise message.",
      outputArtifactId: "dictation_1_processed",
      runId: "processing_1",
    });
    expect(runAsync.mock.calls[0][0]).toContain("INSERT INTO processing_runs");
    expect(runAsync.mock.calls[0]).toEqual(
      expect.arrayContaining([
        "processing_1",
        "dictation_1",
        "dictation_1_raw",
        "gpt-5-mini",
      ]),
    );
    expect(runAsync.mock.calls[1][0]).toContain("INSERT INTO artifacts");
    expect(runAsync.mock.calls[1]).toEqual(
      expect.arrayContaining([
        "dictation_1_processed",
        "dictation_1",
        "A concise message.",
      ]),
    );
    expect(runAsync.mock.calls[2][0]).toContain("UPDATE processing_runs");
    expect(runAsync.mock.calls[3][0]).toContain("UPDATE dictations");
    expect(runAsync.mock.calls.join("\n")).not.toContain(
      "UPDATE artifacts SET kind = 'raw'",
    );
  });

  it("retains a failed run with its terminal error", async () => {
    const { database, runAsync } = databaseThatRuns();

    await expect(
      reprocessStoredDictation(database, detail, "token", {
        createId: () => "processing_failed",
        now: () => new Date("2026-07-18T10:01:00.000Z"),
        process: jest.fn(async () => {
          throw new Error("provider unavailable");
        }),
      }),
    ).rejects.toThrow("provider unavailable");

    expect(runAsync.mock.calls[1][0]).toContain("status = 'failed'");
    expect(runAsync.mock.calls[1]).toEqual(
      expect.arrayContaining(["provider unavailable", "processing_failed"]),
    );
  });
});
