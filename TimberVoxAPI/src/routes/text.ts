import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute } from "@hono/zod-openapi";

import { runText, TextRequest, type TextResult } from "../ai/text/service";
import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import {
  JsonErrorContent,
  TextRequestSchema,
  TextResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const textRoute = createRoute({
  method: "post",
  path: "/v1/text",
  request: {
    body: {
      content: { "application/json": { schema: TextRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TextResponse } },
      description: "Language-model text or structured result.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
  },
  summary: "Generate text or structured output",
  tags: ["Text"],
});

const executeText = async (
  env: Env,
  authorization: string | undefined,
  request: TextRequest
): Promise<TextResult | null> => {
  const auth = await authenticateCredential(env, authorization);
  return auth
    ? runText(env, request, {
        credentialId: auth.credentialId,
        userId: auth.userId,
      })
    : null;
};

export const registerTextRoutes = (app: App): void => {
  app.openapi(textRoute, async (c) => {
    const result = await executeText(
      c.env,
      c.req.header("authorization"),
      TextRequest.parse(c.req.valid("json"))
    );
    if (!result) {
      return c.json({ error: "unauthorized" }, 401);
    }
    return c.json(result, 200);
  });
};
