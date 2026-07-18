import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { getProviderInventory } from "../ai/model-inventory";
import type { PublicAsrRouteSpec, PublicModelSpec } from "../ai/models/types";
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

const InventoryModel = z
  .object({
    display_name: z.string().optional(),
    kind: z.enum(["language", "transcription"]).optional(),
    transports: z.array(z.enum(["batch", "realtime"])).optional(),
    upstream_model: z.string(),
  })
  .openapi("ProviderInventoryModel");

const AsrRouteSpec = z
  .object({
    accepted_options: z.array(z.string()).optional(),
    execution_model: z.string(),
    execution_provider: z.string(),
    model: z.string(),
    provider: z.string(),
    supported_languages: z.array(z.string()).optional(),
    supports_automatic_language: z.boolean(),
    upstream_model: z.string(),
  })
  .openapi("ProviderInventoryAsrRouteSpec");

const InventorySource = z
  .object({
    checked_at: z.string(),
    models: z.array(InventoryModel),
    provider: z.string(),
    reason: z.string().optional(),
    source_kind: z.enum(["api", "contract", "manual"]),
    status: z.enum(["ok", "skipped", "failed"]),
    url: z.string().optional(),
  })
  .openapi("ProviderInventorySource");

const InventoryCatalogModel = z
  .object({
    accepted_options: z
      .object({
        batch: z.array(z.string()).optional(),
        realtime: z.array(z.string()).optional(),
      })
      .optional(),
    execution_model: z.string(),
    execution_provider: z.string(),
    id: z.string(),
    kind: z.enum(["language", "transcription"]),
    provider: z.string(),
    routes: z
      .object({
        batch: AsrRouteSpec.optional(),
        realtime: AsrRouteSpec.optional(),
      })
      .optional(),
    supported_languages: z.array(z.string()).optional(),
    transports: z.array(z.enum(["batch", "realtime"])).optional(),
    upstream_model: z.string(),
  })
  .openapi("ProviderInventoryCatalogModel");

const ProviderInventoryResponse = z
  .object({
    catalog: z.array(InventoryCatalogModel),
    checked_at: z.string(),
    drift: z.object({
      catalog_models_without_provider_match: z.array(
        z.object({
          id: z.string(),
          provider: z.string(),
          reason: z.string(),
          upstream_model: z.string(),
        })
      ),
      provider_models_not_in_catalog: z.array(
        z.object({
          kind: z.enum(["language", "transcription"]).optional(),
          provider: z.string(),
          transports: z.array(z.enum(["batch", "realtime"])).optional(),
          upstream_model: z.string(),
        })
      ),
      sources_unavailable: z.array(
        z.object({
          provider: z.string(),
          reason: z.string().optional(),
          status: z.enum(["skipped", "failed"]),
        })
      ),
    }),
    sources: z.array(InventorySource),
  })
  .openapi("ProviderInventoryResponse");

const providerInventoryRoute = createRoute({
  method: "get",
  path: "/v1/admin/model-inventory",
  responses: {
    200: {
      content: {
        "application/json": { schema: ProviderInventoryResponse },
      },
      description:
        "Provider model inventory compared with the curated TimberVox catalog.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Inspect provider model inventory",
  tags: ["Admin"],
});

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

const acceptedOptionsView = (
  acceptedOptions: PublicModelSpec["acceptedOptions"]
) =>
  acceptedOptions
    ? {
        batch: acceptedOptions.batch ? [...acceptedOptions.batch] : undefined,
        realtime: acceptedOptions.realtime
          ? [...acceptedOptions.realtime]
          : undefined,
      }
    : undefined;

const routeView = (route: PublicAsrRouteSpec | undefined) =>
  route
    ? {
        accepted_options: route.acceptedOptions
          ? [...route.acceptedOptions]
          : undefined,
        execution_model: route.executionModel,
        execution_provider: route.executionProvider,
        model: route.model,
        provider: route.provider,
        supported_languages: route.supportedLanguages
          ? [...route.supportedLanguages]
          : undefined,
        supports_automatic_language: route.supportsAutomaticLanguage,
        upstream_model: route.upstreamModel,
      }
    : undefined;

const routesView = (routes: PublicModelSpec["routes"]) =>
  routes
    ? {
        batch: routeView(routes.batch),
        realtime: routeView(routes.realtime),
      }
    : undefined;

const catalogModelView = (model: PublicModelSpec) => ({
  accepted_options: acceptedOptionsView(model.acceptedOptions),
  execution_model: model.executionModel,
  execution_provider: model.executionProvider,
  id: model.id,
  kind: model.kind,
  provider: model.provider,
  routes: routesView(model.routes),
  supported_languages: model.supportedLanguages
    ? [...model.supportedLanguages]
    : undefined,
  transports: model.transports ? [...model.transports] : undefined,
  upstream_model: model.upstreamModel,
});

export const registerAdminRoutes = (app: App): void => {
  app.openapi(providerInventoryRoute, async (c) => {
    const failure = await adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }

    const report = await getProviderInventory(c.env);
    return c.json(
      {
        catalog: report.catalog.map(catalogModelView),
        checked_at: report.checkedAt,
        drift: {
          catalog_models_without_provider_match:
            report.drift.catalogModelsWithoutProviderMatch.map((model) => ({
              id: model.id,
              provider: model.provider,
              reason: model.reason,
              upstream_model: model.upstreamModel,
            })),
          provider_models_not_in_catalog:
            report.drift.providerModelsNotInCatalog.map((model) => ({
              kind: model.kind,
              provider: model.provider,
              transports: model.transports ? [...model.transports] : undefined,
              upstream_model: model.upstreamModel,
            })),
          sources_unavailable: report.drift.sourcesUnavailable.map(
            (source) => ({
              provider: source.provider,
              reason: source.reason,
              status: source.status,
            })
          ),
        },
        sources: report.sources.map((source) => ({
          checked_at: source.checkedAt,
          models: source.models.map((model) => ({
            display_name: model.displayName,
            kind: model.kind,
            transports: model.transports ? [...model.transports] : undefined,
            upstream_model: model.upstreamModel,
          })),
          provider: source.provider,
          reason: source.reason,
          source_kind: source.sourceKind,
          status: source.status,
          url: source.url,
        })),
      },
      200
    );
  });

  app.openapi(resourceValidationRoute, async (c) => {
    const failure = await adminAuthFailure(c);
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
