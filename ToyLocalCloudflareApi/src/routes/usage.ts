import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { queryUsageAnalytics } from "../analytics/engine";
import { adminAuthFailure } from "../auth/http";
import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import {
  AnalyticsUsageResponse,
  JsonErrorContent,
  UsageDailyResponse,
  UsageSummaryResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const UsageQuery = z
  .object({
    from: z.iso.date().optional(),
    kind: z.enum(["asr", "llm", "realtime_asr"]).optional(),
    limit: z.coerce.number().int().positive().max(500).optional(),
    to: z.iso.date().optional(),
  })
  .strict();

const AdminUsageQuery = UsageQuery.extend({
  account_key: z.string().min(1).optional(),
});

const AnalyticsUsageQuery = z
  .object({
    account_key: z.string().min(1).optional(),
    limit: z.coerce.number().int().positive().max(500).optional(),
    since_minutes: z.coerce.number().int().positive().max(129_600).optional(),
  })
  .strict();

const usageDailyRoute = createRoute({
  method: "get",
  path: "/v1/usage/daily",
  request: { query: UsageQuery },
  responses: {
    200: {
      content: { "application/json": { schema: UsageDailyResponse } },
      description: "Usage rows for the authenticated account.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Get account daily usage",
  tags: ["Usage"],
});

const adminUsageDailyRoute = createRoute({
  method: "get",
  path: "/v1/admin/usage/daily",
  request: { query: AdminUsageQuery },
  responses: {
    200: {
      content: { "application/json": { schema: UsageDailyResponse } },
      description: "Admin usage rows.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Get admin daily usage",
  tags: ["Usage"],
});

const adminUsageSummaryRoute = createRoute({
  method: "get",
  path: "/v1/admin/usage/summary",
  request: { query: AdminUsageQuery },
  responses: {
    200: {
      content: { "application/json": { schema: UsageSummaryResponse } },
      description: "Admin usage summary and recent request logs.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Get admin usage summary",
  tags: ["Usage"],
});

const adminAnalyticsUsageRoute = createRoute({
  method: "get",
  path: "/v1/admin/usage/analytics",
  request: { query: AnalyticsUsageQuery },
  responses: {
    200: {
      content: { "application/json": { schema: AnalyticsUsageResponse } },
      description: "Workers Analytics Engine usage summary from the SQL API.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description:
        "Analytics query credentials or admin auth are not configured.",
    },
  },
  summary: "Query Analytics Engine usage",
  tags: ["Usage"],
});

interface UsageDailyRow {
  account_key: string;
  asr_seconds: number;
  day: string;
  estimated_cost_micro_usd: number;
  input_tokens: number;
  kind: string;
  model: string;
  output_tokens: number;
  provider: string;
  provider_latency_ms: number;
  request_count: number;
  total_tokens: number;
  upstream_model: string | null;
}

interface RequestLogRow {
  account_key: string;
  created_at: string;
  error: string | null;
  estimated_cost_micro_usd: number | null;
  id: string;
  kind: string;
  model: string;
  provider: string;
  route: string | null;
  status: number | null;
  upstream_model: string | null;
}

const usageWhere = (
  query: z.infer<typeof UsageQuery>,
  accountKey: string | null
): { clauses: string[]; values: unknown[] } => {
  const clauses: string[] = [];
  const values: unknown[] = [];
  if (accountKey) {
    clauses.push("account_key = ?");
    values.push(accountKey);
  }
  if (query.from) {
    clauses.push("day >= ?");
    values.push(query.from);
  }
  if (query.to) {
    clauses.push("day <= ?");
    values.push(query.to);
  }
  if (query.kind) {
    clauses.push("kind = ?");
    values.push(query.kind);
  }
  return { clauses, values };
};

const usageSql = (clauses: string[]): string => `
  SELECT
    day, account_key, kind, provider, model, upstream_model, request_count,
    asr_seconds, input_tokens, output_tokens, total_tokens, provider_latency_ms,
    estimated_cost_micro_usd
  FROM usage_daily
  ${clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : ""}
  ORDER BY day DESC, kind ASC, provider ASC, model ASC
  LIMIT ?`;

const listUsage = async (
  env: Env,
  input: {
    accountKey: string | null;
    limit?: number;
    query: z.infer<typeof UsageQuery>;
  }
): Promise<UsageDailyRow[]> => {
  const filter = usageWhere(input.query, input.accountKey);
  const result = await env.DB.prepare(usageSql(filter.clauses))
    .bind(...filter.values, input.limit ?? 100)
    .all<UsageDailyRow>();
  return result.results ?? [];
};

const usageTotals = (rows: UsageDailyRow[]) =>
  rows.reduce(
    (totals, row) => ({
      asr_seconds: totals.asr_seconds + row.asr_seconds,
      estimated_cost_micro_usd:
        totals.estimated_cost_micro_usd + row.estimated_cost_micro_usd,
      input_tokens: totals.input_tokens + row.input_tokens,
      output_tokens: totals.output_tokens + row.output_tokens,
      provider_latency_ms: totals.provider_latency_ms + row.provider_latency_ms,
      request_count: totals.request_count + row.request_count,
      total_tokens: totals.total_tokens + row.total_tokens,
    }),
    {
      asr_seconds: 0,
      estimated_cost_micro_usd: 0,
      input_tokens: 0,
      output_tokens: 0,
      provider_latency_ms: 0,
      request_count: 0,
      total_tokens: 0,
    }
  );

const listRequestLogs = async (
  env: Env,
  limit: number
): Promise<RequestLogRow[]> => {
  const result = await env.DB.prepare(
    `SELECT id, account_key, route, status, kind, provider, model,
            upstream_model, estimated_cost_micro_usd, error, created_at
       FROM request_logs
      ORDER BY created_at DESC
      LIMIT ?`
  )
    .bind(limit)
    .all<RequestLogRow>();
  return result.results ?? [];
};

export const registerUsageRoutes = (app: App): void => {
  app.openapi(usageDailyRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }

    const query = c.req.valid("query");

    const rows = await listUsage(c.env, {
      accountKey: auth.userId,
      limit: query.limit,
      query,
    });
    return c.json({ rows, totals: usageTotals(rows) }, 200);
  });

  app.openapi(adminUsageDailyRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }
    const query = c.req.valid("query");

    const rows = await listUsage(c.env, {
      accountKey: query.account_key ?? null,
      limit: query.limit,
      query,
    });
    return c.json({ rows, totals: usageTotals(rows) }, 200);
  });

  app.openapi(adminUsageSummaryRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }
    const query = c.req.valid("query");

    const rows = await listUsage(c.env, {
      accountKey: query.account_key ?? null,
      limit: query.limit ?? 500,
      query,
    });
    return c.json(
      {
        analytics_engine: {
          queryable_from_worker: false,
          writes_enabled: Boolean(c.env.USAGE_ANALYTICS),
        },
        recent_request_logs: await listRequestLogs(c.env, 25),
        rows,
        totals: usageTotals(rows),
      },
      200
    );
  });

  app.openapi(adminAnalyticsUsageRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }
    const query = c.req.valid("query");
    try {
      return c.json(
        await queryUsageAnalytics(
          c.env,
          {
            accountKey: query.account_key,
            limit: query.limit,
            sinceMinutes: query.since_minutes,
          },
          {
            apiToken: c.req.header("x-analytics-api-token"),
          }
        ),
        200
      );
    } catch (error) {
      return c.json(
        { error: error instanceof Error ? error.message : String(error) },
        503
      );
    }
  });
};
