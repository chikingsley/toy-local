import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { publicModelCatalog } from "../ai/models/catalog";
import type { PublicAsrRouteSpec, PublicModelSpec } from "../ai/models/types";
import { superwhisperIsConfigured } from "../ai/superwhisper/config";
import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import { JsonErrorContent } from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const AsrRouteSpec = z
  .object({
    model: z.string(),
    provider: z.string(),
    supported_languages: z.array(z.string()),
    supports_automatic_language: z.boolean(),
    supports_diarization: z.boolean(),
    upstream_model: z.string(),
  })
  .openapi("AsrRouteSpec");

const IntelligenceSpec = z
  .object({
    display_score: z.number().min(0).max(10),
    index: z.number(),
    measured_at: z.string(),
    profile: z.string(),
    source: z.literal("artificial-analysis"),
    source_version: z.string(),
  })
  .openapi("LanguageModelIntelligenceSpec");

const AccuracySpec = z
  .object({
    benchmark: z.string(),
    metric: z.literal("wer"),
    source: z.enum([
      "fluid-audio",
      "provider-published",
      "route-capability",
      "timbervox-benchmark",
    ]),
    value: z.number().nonnegative(),
  })
  .openapi("ModelAccuracyPresentationSpec");

const SpeedSpec = z
  .object({
    approximate: z.boolean(),
    kind: z.enum(["effective-tps", "realtime", "rtfx"]),
    measured_at: z.string().optional(),
    profile: z.string().optional(),
    source: z.enum([
      "fluid-audio",
      "provider-published",
      "route-capability",
      "timbervox-benchmark",
    ]),
    value: z.number().nonnegative().optional(),
  })
  .openapi("ModelSpeedPresentationSpec");

const ModelSpec = z
  .object({
    accuracy: AccuracySpec.optional(),
    id: z.string(),
    intelligence: IntelligenceSpec.optional(),
    kind: z.enum(["language", "transcription"]),
    provider: z.string(),
    reasoning_profile: z.enum(["low", "medium", "minimal", "none"]).optional(),
    routes: z
      .object({
        batch: AsrRouteSpec.optional(),
        realtime: AsrRouteSpec.optional(),
      })
      .optional(),
    speed: SpeedSpec.optional(),
    upstream_model: z.string(),
  })
  .openapi("ModelSpec");

const ModelsResponse = z
  .object({
    models: z.array(ModelSpec),
    presentation_schema_version: z.literal(1),
  })
  .openapi("ModelsResponse");

const modelsRoute = createRoute({
  method: "get",
  path: "/v1/models",
  responses: {
    200: {
      content: { "application/json": { schema: ModelsResponse } },
      description: "Supported TimberVox model catalog.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
  },
  summary: "List supported models",
  tags: ["Models"],
});

const routeView = (route: PublicAsrRouteSpec | undefined) =>
  route
    ? {
        model: route.model,
        provider: route.provider,
        supported_languages: [...route.supportedLanguages],
        supports_automatic_language: route.supportsAutomaticLanguage,
        supports_diarization: route.supportsDiarization,
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

export const intelligenceDisplayScore = (index: number): number =>
  Math.round(index) / 10;

const modelView = (model: PublicModelSpec) => {
  const languageMetadata =
    model.kind === "language"
      ? {
          intelligence: model.intelligence
            ? {
                display_score: intelligenceDisplayScore(
                  model.intelligence.index
                ),
                index: model.intelligence.index,
                measured_at: model.intelligence.measuredAt,
                profile: model.intelligence.profile,
                source: model.intelligence.source,
                source_version: model.intelligence.sourceVersion,
              }
            : undefined,
          reasoning_profile: model.reasoningProfile,
        }
      : {};
  return {
    accuracy: model.accuracy,
    id: model.id,
    ...languageMetadata,
    kind: model.kind,
    provider: model.provider,
    routes: routesView(model.routes),
    speed: model.speed
      ? {
          approximate: model.speed.approximate,
          kind: model.speed.kind,
          measured_at: model.speed.measuredAt,
          profile: model.speed.profile,
          source: model.speed.source,
          value: model.speed.value,
        }
      : undefined,
    upstream_model: model.upstreamModel,
  };
};

const providerIsConfigured = (env: Env, provider: string): boolean => {
  switch (provider) {
    case "anthropic":
      return Boolean(env.ANTHROPIC_API_KEY);
    case "cerebras":
      return Boolean(env.CEREBRAS_API_KEY);
    case "deepgram":
      return Boolean(env.DEEPGRAM_API_KEY);
    case "deepseek":
      return Boolean(env.DEEPSEEK_API_KEY);
    case "elevenlabs":
      return Boolean(env.ELEVENLABS_API_KEY);
    case "google":
      return Boolean(env.GOOGLE_GENERATIVE_AI_API_KEY);
    case "groq":
      return Boolean(env.GROQ_API_KEY);
    case "mistral":
      return Boolean(env.MISTRAL_API_KEY);
    case "openai":
      return Boolean(env.OPENAI_API_KEY);
    case "superwhisper":
      return superwhisperIsConfigured(env);
    case "zai":
      return Boolean(env.ZAI_API_KEY);
    default:
      return false;
  }
};

export const registerModelRoutes = (app: App): void => {
  app.openapi(modelsRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const models = publicModelCatalog().filter((model) =>
      providerIsConfigured(c.env, model.executionProvider)
    );
    return c.json(
      {
        models: models.map(modelView),
        presentation_schema_version: 1 as const,
      },
      200
    );
  });
};
