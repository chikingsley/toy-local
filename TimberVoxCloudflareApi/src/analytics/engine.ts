import type { Env } from "../bindings";

export interface AnalyticsQueryInput {
  accountKey?: string;
  limit?: number;
  sinceMinutes?: number;
}

export interface AnalyticsQueryResult {
  data: unknown;
  dataset: string;
  query: string;
}

export interface AnalyticsQueryOptions {
  apiToken?: string;
}

const defaultDataset = "timbervox_usage";
const datasetIdentifierPattern = /^[A-Za-z_][A-Za-z0-9_]*$/u;
const maxLimit = 500;
const maxSinceMinutes = 60 * 24 * 90;

const sqlString = (value: string): string => `'${value.replaceAll("'", "''")}'`;

const datasetIdentifier = (value: string): string => {
  if (!datasetIdentifierPattern.test(value)) {
    throw new Error("invalid analytics dataset name");
  }
  return value;
};

export const usageAnalyticsQuery = (
  env: Env,
  input: AnalyticsQueryInput = {}
): { dataset: string; query: string } => {
  const dataset = datasetIdentifier(
    env.TIMBERVOX_USAGE_DATASET ?? defaultDataset
  );
  const sinceMinutes = Math.min(
    Math.max(Math.trunc(input.sinceMinutes ?? 60 * 24 * 7), 1),
    maxSinceMinutes
  );
  const limit = Math.min(Math.max(Math.trunc(input.limit ?? 100), 1), maxLimit);
  const filters = [`timestamp > NOW() - INTERVAL '${sinceMinutes}' MINUTE`];
  if (input.accountKey) {
    filters.push(`index1 = ${sqlString(input.accountKey)}`);
  }

  return {
    dataset,
    query: `
SELECT
  blob4 AS kind,
  blob5 AS provider,
  blob6 AS model,
  SUM(_sample_interval * double1) AS request_count,
  SUM(_sample_interval * double2) AS asr_seconds,
  SUM(_sample_interval * double3) AS input_tokens,
  SUM(_sample_interval * double4) AS output_tokens,
  SUM(_sample_interval * double5) AS total_tokens,
  SUM(_sample_interval * double6) AS provider_latency_ms,
  SUM(_sample_interval * double7) AS estimated_cost_micro_usd
FROM ${dataset}
WHERE ${filters.join(" AND ")}
GROUP BY kind, provider, model
ORDER BY request_count DESC
LIMIT ${limit}
FORMAT JSON`.trim(),
  };
};

export const queryUsageAnalytics = async (
  env: Env,
  input: AnalyticsQueryInput = {},
  options: AnalyticsQueryOptions = {}
): Promise<AnalyticsQueryResult> => {
  const apiToken = options.apiToken ?? env.CLOUDFLARE_ANALYTICS_API_TOKEN;
  if (!(env.CLOUDFLARE_ACCOUNT_ID && apiToken)) {
    throw new Error("analytics query credentials are not configured");
  }

  const { dataset, query } = usageAnalyticsQuery(env, input);
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${env.CLOUDFLARE_ACCOUNT_ID}/analytics_engine/sql`,
    {
      body: query,
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
      method: "POST",
    }
  );
  if (!response.ok) {
    throw new Error(
      `analytics query failed: ${response.status} ${await response.text()}`
    );
  }
  return {
    data: await response.json(),
    dataset,
    query,
  };
};
