import { createRoute, OpenAPIHono } from "@hono/zod-openapi";
import { apiReference } from "@scalar/hono-api-reference";

import type { Env, QueueJobMessage } from "./bindings";
import { jsonError } from "./http/json";
import { requestLogger } from "./http/request-log";
import { handleJobs } from "./jobs/consumer";
import { registerAdminRoutes } from "./routes/admin";
import { registerJobRoutes } from "./routes/jobs";
import { registerLicenseRoutes } from "./routes/licenses";
import { HealthResponse, JsonErrorContent } from "./routes/openapi-schemas";
import { registerRealtimeRoutes } from "./routes/realtime";
import { registerTextTransformRoutes } from "./routes/text-transforms";
import { registerTranscriptionRoutes } from "./routes/transcriptions";
import { registerUploadRoutes } from "./routes/uploads";
import { registerUsageRoutes } from "./routes/usage";

export const app = new OpenAPIHono<{ Bindings: Env }>({
  defaultHook: (result, c) =>
    result.success
      ? undefined
      : c.json(
          {
            error: "invalid request",
            issues: result.error.issues,
          },
          400
        ),
});

const healthRoute = createRoute({
  method: "get",
  path: "/health",
  responses: {
    200: {
      content: { "application/json": { schema: HealthResponse } },
      description: "Worker health.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
  },
  summary: "Health",
  tags: ["Health"],
});

app.use("*", requestLogger);

app.openapi(healthRoute, (c) =>
  c.json({ ok: true, service: "timbervox" }, 200)
);
app.get(
  "/docs",
  apiReference({
    spec: { url: "/openapi.json" },
    theme: "default",
  })
);

registerUploadRoutes(app);
registerTranscriptionRoutes(app);
registerJobRoutes(app);
registerTextTransformRoutes(app);
registerRealtimeRoutes(app);
registerLicenseRoutes(app);
registerUsageRoutes(app);
registerAdminRoutes(app);

app.doc("/openapi.json", {
  info: {
    description:
      "TimberVox Cloud for cloud upload, transcription jobs, realtime ASR, text transforms, licensing, and usage.",
    title: "TimberVox Cloud",
    version: "0.1.0",
  },
  openapi: "3.1.0",
});

app.notFound(() => jsonError("not found", 404));

export default {
  fetch: app.fetch,
  queue: (batch: MessageBatch<QueueJobMessage>, env: Env): Promise<void> =>
    handleJobs(batch, env),
};

// biome-ignore lint/performance/noBarrelFile: Wrangler requires Durable Object classes to be exported from the Worker entrypoint.
export { RealtimeSession } from "./durable-objects/realtime-session";
