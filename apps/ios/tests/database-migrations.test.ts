import type { SQLiteDatabase } from "expo-sqlite";

import { migrateDatabase, migrations } from "@/lib/db/database";

describe("mobile database migrations", () => {
  it("applies every migration once and is idempotent on relaunch", async () => {
    const applied = new Set<number>();
    let seedCount = 0;
    const database = {
      execAsync: jest.fn(async () => undefined),
      getAllAsync: jest.fn(async () => []),
      getFirstAsync: jest.fn(async (_query: string, version: number) =>
        applied.has(version) ? { version } : null,
      ),
      runAsync: jest.fn(async (query: string, ...params: unknown[]) => {
        if (query.includes("INSERT INTO modes")) seedCount += 1;
        if (query.includes("INSERT INTO schema_migrations")) {
          applied.add(params[0] as number);
        }
        return { changes: 1, lastInsertRowId: 1 };
      }),
      withExclusiveTransactionAsync: jest.fn(
        async (task: (transaction: SQLiteDatabase) => Promise<void>) => {
          await task(database as unknown as SQLiteDatabase);
        },
      ),
    } as unknown as SQLiteDatabase;

    await migrateDatabase(database);
    await migrateDatabase(database);

    expect([...applied]).toEqual(
      migrations.map((migration) => migration.version),
    );
    expect(seedCount).toBe(1);
  });

  it("migrates legacy history into durable dictations and raw artifacts", async () => {
    const runAsync = jest.fn(async (_query: string, ..._params: unknown[]) => ({
      changes: 1,
      lastInsertRowId: 1,
    }));
    const database = {
      getAllAsync: jest.fn(async () => [
        {
          audio_uri: "file:///legacy.wav",
          created_at: "2026-07-01T10:00:00.000Z",
          duration_ms: 2_500,
          id: 7,
          model: "voxtral",
          source: "keyboard",
          text: "Legacy words survive.",
        },
      ]),
      runAsync,
    } as unknown as SQLiteDatabase;
    const migration = migrations.find((candidate) => candidate.version === 4);

    await migration!.migrate(database);

    expect(runAsync.mock.calls[0][0]).toContain(
      "INSERT OR IGNORE INTO dictations",
    );
    expect(runAsync.mock.calls[0]).toEqual(
      expect.arrayContaining([
        "legacy:7",
        "legacy_request_7",
        3,
        "keyboard",
        "file:///legacy.wav",
      ]),
    );
    expect(runAsync.mock.calls[1][0]).toContain(
      "INSERT OR IGNORE INTO artifacts",
    );
    expect(runAsync.mock.calls[1]).toEqual(
      expect.arrayContaining([
        "legacy:7_raw",
        "legacy:7",
        "Legacy words survive.",
      ]),
    );
    expect(runAsync).toHaveBeenLastCalledWith("DELETE FROM dictation_history");
  });

  it("creates normalized durable dictation and artifact tables", async () => {
    const database = {
      execAsync: jest.fn(async () => undefined),
    } as unknown as SQLiteDatabase;
    const migration = migrations.find((candidate) => candidate.version === 3);
    expect(migration).toBeDefined();

    await migration!.migrate(database);

    const schema = (database.execAsync as jest.Mock).mock.calls[0][0] as string;
    expect(schema).toContain("CREATE TABLE IF NOT EXISTS dictations");
    expect(schema).toContain("request_id TEXT NOT NULL UNIQUE");
    expect(schema).toContain("mode_snapshot_json TEXT NOT NULL");
    expect(schema).toContain("CREATE TABLE IF NOT EXISTS artifacts");
    expect(schema).toContain("REFERENCES dictations(id) ON DELETE CASCADE");
  });
});
