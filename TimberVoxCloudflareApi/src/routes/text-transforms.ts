import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute } from "@hono/zod-openapi";

import { runTextTransform, TextTransformRequest } from "../ai/text-transform";
import type { Env } from "../bindings";
import {
  JsonErrorContent,
  TextTransformRequestSchema,
  TextTransformResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const textTransformRoute = createRoute({
  method: "post",
  path: "/v1/text-transforms",
  request: {
    body: {
      content: { "application/json": { schema: TextTransformRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TextTransformResponse } },
      description: "Language-model transform result.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
  },
  summary: "Run text transform",
  tags: ["Text Transforms"],
});

export const registerTextTransformRoutes = (app: App): void => {
  app.openapi(textTransformRoute, async (c) => {
    const result = await runTextTransform(
      c.env,
      TextTransformRequest.parse(c.req.valid("json"))
    );
    return c.json(result, 200);
  });
};
