import { execFile } from "node:child_process";
import { promisify } from "node:util";

import type { Env, QueueJobMessage } from "../../src/bindings";

const execFileAsync = promisify(execFile);
const databaseName = "timbervox";

interface D1ExecuteResult<T = Record<string, unknown>> {
  meta?: { changes?: number };
  results: T[];
  success: boolean;
}

class WranglerD1Database {
  prepare(sql: string): D1PreparedStatement {
    return new WranglerD1Statement(sql) as unknown as D1PreparedStatement;
  }
}

class WranglerD1Statement {
  private readonly sql: string;
  private values: unknown[] = [];

  constructor(sql: string) {
    this.sql = sql;
  }

  bind(...values: unknown[]): WranglerD1Statement {
    this.values = values;
    return this;
  }

  async all<T>(): Promise<D1Result<T>> {
    const result = await executeD1<T>(substituteParams(this.sql, this.values));
    return {
      meta: {
        changes: result.meta?.changes ?? result.results.length,
        changed_db: true,
        duration: 0,
        last_row_id: 0,
        rows_read: result.results.length,
        rows_written: result.meta?.changes ?? 0,
        size_after: 0,
      },
      results: result.results,
      success: result.success,
    };
  }

  async first<T>(): Promise<T | null> {
    const result = await executeD1<T>(substituteParams(this.sql, this.values));
    return result.results[0] ?? null;
  }

  async run(): Promise<D1Result> {
    const result = await executeD1(substituteParams(this.sql, this.values));
    return {
      meta: {
        changes: result.meta?.changes ?? result.results.length,
        changed_db: true,
        duration: 0,
        last_row_id: 0,
        rows_read: result.results.length,
        rows_written: result.meta?.changes ?? 0,
        size_after: 0,
      },
      results: result.results,
      success: result.success,
    };
  }
}

class MemoryR2Object {
  readonly httpMetadata: R2HTTPMetadata | undefined;
  readonly size: number;
  private readonly data: Uint8Array;

  constructor(data: Uint8Array, httpMetadata?: R2HTTPMetadata) {
    this.data = data;
    this.httpMetadata = httpMetadata;
    this.size = data.byteLength;
  }

  arrayBuffer(): Promise<ArrayBuffer> {
    return Promise.resolve(
      this.data.buffer.slice(
        this.data.byteOffset,
        this.data.byteOffset + this.data.byteLength
      )
    );
  }

  text(): Promise<string> {
    return Promise.resolve(new TextDecoder().decode(this.data));
  }
}

export class MemoryR2Bucket {
  private readonly objects = new Map<string, MemoryR2Object>();

  delete(key: string): Promise<void> {
    this.objects.delete(key);
    return Promise.resolve();
  }

  get(key: string): Promise<MemoryR2Object | null> {
    return Promise.resolve(this.objects.get(key) ?? null);
  }

  async put(
    key: string,
    value: ArrayBuffer | ReadableStream | string,
    options?: R2PutOptions
  ): Promise<R2Object> {
    const data = await bodyBytes(value);
    const object = new MemoryR2Object(data, options?.httpMetadata);
    this.objects.set(key, object);
    return {
      checksums: {},
      etag: `"${key}"`,
      httpEtag: `"${key}"`,
      httpMetadata: object.httpMetadata,
      key,
      size: object.size,
      uploaded: new Date(),
      version: "local",
      writeHttpMetadata: () => undefined,
    } as unknown as R2Object;
  }
}

export class MemoryQueue {
  readonly messages: QueueJobMessage[] = [];

  send(message: QueueJobMessage): Promise<void> {
    this.messages.push(message);
    return Promise.resolve();
  }
}

class MemoryDurableObjectNamespace {
  get(): { fetch: (request: Request) => Promise<Response> } {
    return {
      fetch: (request: Request) => {
        if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
          return Promise.resolve(
            new Response("expected websocket upgrade", { status: 426 })
          );
        }
        return Promise.resolve(new Response(null, { status: 101 }));
      },
    };
  }

  idFromName(name: string): DurableObjectId {
    return { name } as unknown as DurableObjectId;
  }
}

class MemoryAnalyticsEngine {
  readonly points: AnalyticsEngineDataPoint[] = [];

  writeDataPoint(point: AnalyticsEngineDataPoint): void {
    this.points.push(point);
  }
}

export const executeD1 = async <T = Record<string, unknown>>(
  command: string
): Promise<D1ExecuteResult<T>> => {
  const { stdout } = await execFileAsync(
    "pnpm",
    [
      "exec",
      "wrangler",
      "d1",
      "execute",
      databaseName,
      "--local",
      "--json",
      "--command",
      command,
    ],
    { maxBuffer: 1024 * 1024 }
  );
  const results = JSON.parse(stdout) as D1ExecuteResult<T>[];
  return results[0];
};

export const localD1Env = (overrides: Partial<Env> = {}): Env =>
  ({
    ARTIFACTS: new MemoryR2Bucket() as unknown as R2Bucket,
    DB: new WranglerD1Database() as unknown as D1Database,
    JOBS_DLQ: new MemoryQueue() as unknown as Queue<QueueJobMessage>,
    JOBS_QUEUE: new MemoryQueue() as unknown as Queue<QueueJobMessage>,
    MISTRAL_API_KEY: "test-mistral-key",
    REALTIME_SESSIONS:
      new MemoryDurableObjectNamespace() as unknown as DurableObjectNamespace,
    TIMBERVOX_ADMIN_TOKEN: "test-admin-token",
    USAGE_ANALYTICS:
      new MemoryAnalyticsEngine() as unknown as AnalyticsEngineDataset,
    ...overrides,
  }) as Env;

export const migrateLocalD1 = async (): Promise<void> => {
  await execFileAsync(
    "pnpm",
    ["exec", "wrangler", "d1", "migrations", "apply", databaseName, "--local"],
    { maxBuffer: 1024 * 1024 }
  );
};

const bodyBytes = async (
  value: ArrayBuffer | ReadableStream | string
): Promise<Uint8Array> => {
  if (typeof value === "string") {
    return new TextEncoder().encode(value);
  }
  if (value instanceof ArrayBuffer) {
    return new Uint8Array(value);
  }
  const response = new Response(value);
  return new Uint8Array(await response.arrayBuffer());
};

const sqlLiteral = (value: unknown): string => {
  if (value === null || value === undefined) {
    return "NULL";
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? String(value) : "NULL";
  }
  if (typeof value === "boolean") {
    return value ? "1" : "0";
  }
  return `'${String(value).replaceAll("'", "''")}'`;
};

const substituteParams = (sql: string, values: unknown[]): string => {
  let index = 0;
  return sql.replaceAll("?", () => sqlLiteral(values[index++]));
};
