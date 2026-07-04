import type { Env } from "../bindings";
import { newId } from "../lib/ids";
import { estimateCostMicroUsd, type ModelPrice, type UsageUnit } from "./cost";

type UsageKind = "asr" | "llm" | "realtime_asr";

export interface UsageEvent {
  asrSeconds?: number | null;
  clientId?: string | null;
  error?: string | null;
  inputTokens?: number | null;
  jobId?: string | null;
  kind: UsageKind;
  metadata?: unknown;
  method?: string | null;
  model: string;
  outputTokens?: number | null;
  provider: string;
  providerLatencyMs?: number | null;
  requestId?: string | null;
  route?: string | null;
  status?: number | null;
  totalTokens?: number | null;
  upstreamModel?: string | null;
  userId?: string | null;
}

interface ModelPriceRow {
  input_micro_usd_per_unit: number | null;
  output_micro_usd_per_unit: number | null;
  unit: UsageUnit;
}

const nowIso = (): string => new Date().toISOString();

const accountKey = (event: UsageEvent): string =>
  event.userId ?? event.clientId ?? "anonymous";

const usageUnit = (kind: UsageKind): UsageUnit =>
  kind === "llm" ? "token" : "audio_second";

const maybeNumber = (value: number | null | undefined): number | null =>
  typeof value === "number" && Number.isFinite(value) ? value : null;

const maybeInteger = (value: number | null | undefined): number | null => {
  const numeric = maybeNumber(value);
  return numeric === null ? null : Math.round(numeric);
};

const findModelPrice = async (
  env: Env,
  event: UsageEvent,
  createdAt: string
): Promise<ModelPrice | null> => {
  const row = await env.DB.prepare(
    `SELECT unit, input_micro_usd_per_unit, output_micro_usd_per_unit
       FROM model_prices
      WHERE provider = ?
        AND model = ?
        AND unit = ?
        AND effective_at <= ?
        AND (effective_until IS NULL OR effective_until > ?)
      ORDER BY effective_at DESC
      LIMIT 1`
  )
    .bind(
      event.provider,
      event.upstreamModel ?? event.model,
      usageUnit(event.kind),
      createdAt,
      createdAt
    )
    .first<ModelPriceRow>();

  if (!row) {
    return null;
  }

  return {
    inputMicroUsdPerUnit: row.input_micro_usd_per_unit,
    outputMicroUsdPerUnit: row.output_micro_usd_per_unit,
    unit: row.unit,
  };
};

const writeAnalyticsPoint = (
  env: Env,
  event: UsageEvent,
  input: {
    accountKey: string;
    estimatedCostMicroUsd: number | null;
  }
): void => {
  env.USAGE_ANALYTICS?.writeDataPoint({
    blobs: [
      input.accountKey,
      event.userId ?? "",
      event.clientId ?? "",
      event.kind,
      event.provider,
      event.model,
      event.upstreamModel ?? "",
      event.route ?? "",
      event.jobId ?? "",
      event.error ? "error" : "ok",
    ],
    doubles: [
      1,
      event.asrSeconds ?? 0,
      event.inputTokens ?? 0,
      event.outputTokens ?? 0,
      event.totalTokens ?? 0,
      event.providerLatencyMs ?? 0,
      input.estimatedCostMicroUsd ?? 0,
      event.status ?? 0,
    ],
    indexes: [input.accountKey],
  });
};

const insertRequestLog = async (
  env: Env,
  event: UsageEvent,
  input: {
    accountKey: string;
    createdAt: string;
    estimatedCostMicroUsd: number | null;
    requestLogId: string;
  }
): Promise<void> => {
  await env.DB.prepare(
    `INSERT INTO request_logs
      (id, account_key, user_id, client_id, request_id, job_id, route, method,
       status, kind, provider, model, upstream_model, asr_seconds, input_tokens,
       output_tokens, total_tokens, provider_latency_ms, estimated_cost_micro_usd,
       error, metadata_json, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      input.requestLogId,
      input.accountKey,
      event.userId ?? null,
      event.clientId ?? null,
      event.requestId ?? null,
      event.jobId ?? null,
      event.route ?? null,
      event.method ?? null,
      maybeInteger(event.status),
      event.kind,
      event.provider,
      event.model,
      event.upstreamModel ?? null,
      maybeNumber(event.asrSeconds),
      maybeInteger(event.inputTokens),
      maybeInteger(event.outputTokens),
      maybeInteger(event.totalTokens),
      maybeInteger(event.providerLatencyMs),
      input.estimatedCostMicroUsd,
      event.error ?? null,
      event.metadata === undefined ? null : JSON.stringify(event.metadata),
      input.createdAt
    )
    .run();
};

const upsertUsageDaily = async (
  env: Env,
  event: UsageEvent,
  input: {
    accountKey: string;
    createdAt: string;
    estimatedCostMicroUsd: number | null;
  }
): Promise<void> => {
  await env.DB.prepare(
    `INSERT INTO usage_daily
      (day, account_key, user_id, client_id, kind, provider, model, upstream_model,
       request_count, asr_seconds, input_tokens, output_tokens, total_tokens,
       provider_latency_ms, estimated_cost_micro_usd, first_request_at, last_request_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(day, account_key, kind, provider, model)
     DO UPDATE SET
       request_count = request_count + 1,
       asr_seconds = asr_seconds + excluded.asr_seconds,
       input_tokens = input_tokens + excluded.input_tokens,
       output_tokens = output_tokens + excluded.output_tokens,
       total_tokens = total_tokens + excluded.total_tokens,
       provider_latency_ms = provider_latency_ms + excluded.provider_latency_ms,
       estimated_cost_micro_usd =
         estimated_cost_micro_usd + excluded.estimated_cost_micro_usd,
       last_request_at = excluded.last_request_at`
  )
    .bind(
      input.createdAt.slice(0, 10),
      input.accountKey,
      event.userId ?? null,
      event.clientId ?? null,
      event.kind,
      event.provider,
      event.model,
      event.upstreamModel ?? null,
      maybeNumber(event.asrSeconds) ?? 0,
      maybeInteger(event.inputTokens) ?? 0,
      maybeInteger(event.outputTokens) ?? 0,
      maybeInteger(event.totalTokens) ?? 0,
      maybeInteger(event.providerLatencyMs) ?? 0,
      input.estimatedCostMicroUsd ?? 0,
      input.createdAt,
      input.createdAt
    )
    .run();
};

const recordUsageEventUnsafe = async (
  env: Env,
  event: UsageEvent
): Promise<string> => {
  const createdAt = nowIso();
  const resolvedAccountKey = accountKey(event);
  const price = await findModelPrice(env, event, createdAt);
  const estimatedCostMicroUsd = estimateCostMicroUsd(
    {
      asrSeconds: event.asrSeconds,
      inputTokens: event.inputTokens,
      outputTokens: event.outputTokens,
    },
    price
  );
  const requestLogId = newId("req");

  await insertRequestLog(env, event, {
    accountKey: resolvedAccountKey,
    createdAt,
    estimatedCostMicroUsd,
    requestLogId,
  });
  await upsertUsageDaily(env, event, {
    accountKey: resolvedAccountKey,
    createdAt,
    estimatedCostMicroUsd,
  });

  writeAnalyticsPoint(env, event, {
    accountKey: resolvedAccountKey,
    estimatedCostMicroUsd,
  });

  return requestLogId;
};

export const recordUsageEvent = async (
  env: Env,
  event: UsageEvent
): Promise<void> => {
  try {
    const requestLogId = await recordUsageEventUnsafe(env, event);
    console.log(
      JSON.stringify({
        event: "usage.recorded",
        kind: event.kind,
        model: event.model,
        provider: event.provider,
        request_log_id: requestLogId,
      })
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
        event: "usage.record_failed",
        kind: event.kind,
        model: event.model,
        provider: event.provider,
      })
    );
  }
};
