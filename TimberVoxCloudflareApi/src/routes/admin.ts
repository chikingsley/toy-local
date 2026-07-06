import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute } from "@hono/zod-openapi";

import { adminAuthFailure } from "../auth/http";
import type { Env, QueueJobMessage } from "../bindings";
import { newId } from "../lib/ids";
import {
  JsonErrorContent,
  ResourceValidationResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

interface ResourceCheck {
  detail?: string;
  ok: boolean;
}

const resourceValidationRoute = createRoute({
  method: "post",
  path: "/v1/admin/resources/validate",
  responses: {
    200: {
      content: { "application/json": { schema: ResourceValidationResponse } },
      description: "Runtime validation result for bound Cloudflare resources.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Validate deployed Cloudflare resources",
  tags: ["Admin"],
});

const check = async (
  checks: Record<string, ResourceCheck>,
  key: string,
  action: () => Promise<string | undefined>
): Promise<void> => {
  try {
    checks[key] = { detail: await action(), ok: true };
  } catch (error) {
    checks[key] = {
      detail: error instanceof Error ? error.message : String(error),
      ok: false,
    };
  }
};

const validateD1 = async (env: Env): Promise<string> => {
  const row = await env.DB.prepare(
    `SELECT COUNT(*) AS count
       FROM sqlite_master
      WHERE type = 'table'
        AND name IN ('uploads', 'jobs', 'usage_daily', 'realtime_sessions')`
  ).first<{ count: number }>();
  if ((row?.count ?? 0) !== 4) {
    throw new Error("expected core D1 tables are missing");
  }
  return "core tables are readable";
};

const validateR2 = async (env: Env, validationId: string): Promise<string> => {
  const key = `_validation/${validationId}.txt`;
  await env.ARTIFACTS.put(key, validationId, {
    httpMetadata: { contentType: "text/plain; charset=utf-8" },
  });
  const object = await env.ARTIFACTS.get(key);
  if (!object) {
    throw new Error("validation object was not readable");
  }
  await env.ARTIFACTS.delete(key);
  return "put/get/delete succeeded";
};

const validateQueue = async (
  env: Env,
  validationId: string
): Promise<string> => {
  await env.JOBS_QUEUE.send({
    kind: "validation",
    validation_id: validationId,
  } satisfies QueueJobMessage);
  return "validation message sent";
};

const validateDlq = async (env: Env, validationId: string): Promise<string> => {
  await env.JOBS_DLQ.send({
    kind: "validation",
    validation_id: validationId,
  } satisfies QueueJobMessage);
  return "validation message sent";
};

const validateDurableObject = async (
  env: Env,
  validationId: string,
  requestUrl: string
): Promise<string> => {
  const id = env.REALTIME_SESSIONS.idFromName(`validation-${validationId}`);
  const url = new URL(requestUrl);
  url.pathname = "/_internal/realtime-validation";
  const response = await env.REALTIME_SESSIONS.get(id).fetch(new Request(url));
  if (response.status !== 426) {
    throw new Error(
      `expected 426 from non-upgrade request, got ${response.status}`
    );
  }
  return "namespace fetch reached RealtimeSession";
};

const validateAnalytics = (env: Env, validationId: string): Promise<string> => {
  if (!env.USAGE_ANALYTICS) {
    throw new Error("USAGE_ANALYTICS binding is not configured");
  }
  env.USAGE_ANALYTICS.writeDataPoint({
    blobs: [
      validationId,
      "",
      "",
      "validation",
      "cloudflare",
      "resource-check",
      "",
      "/v1/admin/resources/validate",
      "",
      "ok",
    ],
    doubles: [1, 0, 0, 0, 0, 0, 0, 200],
    indexes: [validationId],
  });
  return Promise.resolve("writeDataPoint accepted");
};

export const registerAdminRoutes = (app: App): void => {
  app.openapi(resourceValidationRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }

    const validationId = newId("val");
    const checks: Record<string, ResourceCheck> = {};
    await check(checks, "d1", () => validateD1(c.env));
    await check(checks, "r2", () => validateR2(c.env, validationId));
    await check(checks, "queue", () => validateQueue(c.env, validationId));
    await check(checks, "dlq", () => validateDlq(c.env, validationId));
    await check(checks, "durable_object", () =>
      validateDurableObject(c.env, validationId, c.req.url)
    );
    await check(checks, "analytics_engine", () =>
      validateAnalytics(c.env, validationId)
    );
    console.log(
      JSON.stringify({
        checks,
        event: "resources.validation",
        validation_id: validationId,
      })
    );
    checks.workers_logs = {
      detail: "emitted resources.validation log line",
      ok: true,
    };

    const ok = Object.values(checks).every((resource) => resource.ok);
    return c.json({ checks, ok, validation_id: validationId }, 200);
  });
};
