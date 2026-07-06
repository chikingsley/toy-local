import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import type { Env } from "../bindings";
import {
  createTranscription,
  TranscriptionRequest,
} from "../jobs/transcriptions";
import {
  JobView,
  JsonErrorContent,
  TranscriptionRequestSchema,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const createTranscriptionRoute = createRoute({
  method: "post",
  path: "/v1/transcriptions",
  request: {
    body: {
      content: { "application/json": { schema: TranscriptionRequestSchema } },
      required: true,
    },
    headers: z.object({
      "idempotency-key": z.string().optional(),
      "x-timbervox-client-id": z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: JobView } },
      description: "Existing idempotent job.",
    },
    202: {
      content: { "application/json": { schema: JobView } },
      description: "Queued transcription job.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
  },
  summary: "Create transcription job",
  tags: ["Transcriptions"],
});

export const registerTranscriptionRoutes = (app: App): void => {
  app.openapi(createTranscriptionRoute, async (c) => {
    const parsed = TranscriptionRequest.parse(c.req.valid("json"));
    const result = await createTranscription(c.env, parsed, {
      idempotencyKey: c.req.header("idempotency-key") ?? undefined,
      scope: c.req.header("x-timbervox-client-id") ?? "local-dev",
    });
    return c.json(result.view, result.status);
  });
};
