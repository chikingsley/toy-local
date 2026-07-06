import { randomUUID } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";

import { recordUsageEvent } from "../../src/accounting/usage";
import { executeD1, localD1Env, migrateLocalD1 } from "./helpers";

describe("local D1 accounting integration", () => {
  beforeAll(async () => {
    await migrateLocalD1();
  });

  it("records request logs, daily usage, and estimated cost in real local D1", async () => {
    const testId = `local_d1_${randomUUID()}`;
    await executeD1(`
      INSERT OR REPLACE INTO model_prices
        (provider, model, unit, input_micro_usd_per_unit, output_micro_usd_per_unit, effective_at, source)
      VALUES
        ('test-asr', 'upstream-asr', 'audio_second', 2, NULL, '2026-01-01T00:00:00.000Z', 'local-test')
    `);
    await executeD1(`
      INSERT INTO jobs
        (id, kind, status, input_key, client_id, params_json, progress, created_at, updated_at, queued_at)
      VALUES
        ('job_${testId}', 'transcription', 'running', NULL, '${testId}', '{}', 0.2, '2026-07-02T00:00:00.000Z', '2026-07-02T00:00:00.000Z', '2026-07-02T00:00:00.000Z')
    `);

    await recordUsageEvent(localD1Env(), {
      asrSeconds: 12.5,
      clientId: testId,
      jobId: `job_${testId}`,
      kind: "asr",
      model: "timbervox-test-asr",
      provider: "test-asr",
      providerLatencyMs: 321,
      route: "/v1/transcriptions",
      status: 200,
      upstreamModel: "upstream-asr",
    });

    const requestLog = await executeD1<{
      asr_seconds: number;
      estimated_cost_micro_usd: number;
      provider_latency_ms: number;
    }>(`
      SELECT asr_seconds, provider_latency_ms, estimated_cost_micro_usd
      FROM request_logs
      WHERE account_key = '${testId}'
      LIMIT 1
    `);
    expect(requestLog.results[0]).toEqual({
      asr_seconds: 12.5,
      estimated_cost_micro_usd: 25,
      provider_latency_ms: 321,
    });

    const usage = await executeD1<{
      asr_seconds: number;
      estimated_cost_micro_usd: number;
      request_count: number;
    }>(`
      SELECT request_count, asr_seconds, estimated_cost_micro_usd
      FROM usage_daily
      WHERE account_key = '${testId}'
      LIMIT 1
    `);
    expect(usage.results[0]).toEqual({
      asr_seconds: 12.5,
      estimated_cost_micro_usd: 25,
      request_count: 1,
    });
  });

  it("records language-model tokens and estimated cost in real local D1", async () => {
    const testId = `local_d1_llm_${randomUUID()}`;
    await executeD1(`
      INSERT OR REPLACE INTO model_prices
        (provider, model, unit, input_micro_usd_per_unit, output_micro_usd_per_unit, effective_at, source)
      VALUES
        ('test-llm', 'upstream-llm', 'token', 0.25, 2, '2026-01-01T00:00:00.000Z', 'local-test')
    `);

    await recordUsageEvent(localD1Env(), {
      clientId: testId,
      inputTokens: 1000,
      kind: "llm",
      model: "timbervox-test-llm",
      outputTokens: 250,
      provider: "test-llm",
      providerLatencyMs: 456,
      route: "/v1/text-transforms",
      status: 200,
      totalTokens: 1250,
      upstreamModel: "upstream-llm",
    });

    const requestLog = await executeD1<{
      estimated_cost_micro_usd: number;
      input_tokens: number;
      output_tokens: number;
      total_tokens: number;
    }>(`
      SELECT input_tokens, output_tokens, total_tokens, estimated_cost_micro_usd
      FROM request_logs
      WHERE account_key = '${testId}'
      LIMIT 1
    `);
    expect(requestLog.results[0]).toEqual({
      estimated_cost_micro_usd: 750,
      input_tokens: 1000,
      output_tokens: 250,
      total_tokens: 1250,
    });

    const usage = await executeD1<{
      estimated_cost_micro_usd: number;
      input_tokens: number;
      output_tokens: number;
      request_count: number;
      total_tokens: number;
    }>(`
      SELECT request_count, input_tokens, output_tokens, total_tokens, estimated_cost_micro_usd
      FROM usage_daily
      WHERE account_key = '${testId}'
      LIMIT 1
    `);
    expect(usage.results[0]).toEqual({
      estimated_cost_micro_usd: 750,
      input_tokens: 1000,
      output_tokens: 250,
      request_count: 1,
      total_tokens: 1250,
    });
  });

  it("accepts the user and credential schema in real local D1", async () => {
    const testId = randomUUID();
    await executeD1(`
      INSERT INTO users (id, email, display_name, created_at, updated_at)
      VALUES ('usr_${testId}', '${testId}@example.test', NULL, '2026-07-02T00:00:00.000Z', '2026-07-02T00:00:00.000Z')
    `);
    await executeD1(`
      INSERT INTO api_credentials
        (id, user_id, label, credential_hash, status, created_at)
      VALUES
        ('cred_${testId}', 'usr_${testId}', 'local test', 'hash_${testId}', 'active', '2026-07-02T00:00:00.000Z')
    `);

    const result = await executeD1<{ status: string; user_id: string }>(`
      SELECT user_id, status
      FROM api_credentials
      WHERE id = 'cred_${testId}'
    `);
    expect(result.results[0]).toEqual({
      status: "active",
      user_id: `usr_${testId}`,
    });
  });
});
