import type { SQLiteDatabase } from "expo-sqlite";

import {
  loadAudioRetention,
  loadStorageSummary,
  setAudioRetention,
} from "@/features/history/history-storage";

describe("history storage settings", () => {
  it("reads the real database totals", async () => {
    const database = {
      getFirstAsync: jest.fn(async () => ({
        audio_bytes: 2_048,
        audio_count: 2,
        history_count: 5,
      })),
    } as unknown as SQLiteDatabase;

    await expect(loadStorageSummary(database)).resolves.toEqual({
      audioBytes: 2_048,
      audioCount: 2,
      historyCount: 5,
    });
  });

  it.each([null, 1, 7, 30, 90] as const)(
    "round-trips the %s day retention policy",
    async (days) => {
      const runAsync = jest.fn(async () => ({
        changes: 1,
        lastInsertRowId: 1,
      }));
      const database = {
        getAllAsync: jest.fn(async () => []),
        getFirstAsync: jest.fn(async () => ({
          value_json: JSON.stringify(days),
        })),
        runAsync,
      } as unknown as SQLiteDatabase;

      await setAudioRetention(database, days);

      expect(runAsync.mock.calls[0]).toEqual(
        expect.arrayContaining(["audio_retention_days", JSON.stringify(days)]),
      );
      await expect(loadAudioRetention(database)).resolves.toBe(days);
    },
  );
});
