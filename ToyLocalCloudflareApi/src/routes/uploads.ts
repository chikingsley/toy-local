import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import type { Env } from "../bindings";
import { completeUpload, createUpload } from "../uploads/service";
import {
  JsonErrorContent,
  UploadCompletionResponse,
  UploadReservationRequest,
  UploadReservationResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const CreateUploadRequest = z
  .object({
    content_type: z.string().min(1).optional(),
    filename: z.string().min(1).optional(),
  })
  .strict();

const reserveUploadRoute = createRoute({
  method: "post",
  path: "/v1/uploads",
  request: {
    body: {
      content: { "application/json": { schema: UploadReservationRequest } },
      required: false,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: UploadReservationResponse } },
      description: "Upload reservation.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
  },
  summary: "Reserve upload",
  tags: ["Uploads"],
});

const completeUploadRoute = createRoute({
  method: "put",
  path: "/v1/uploads/{upload_id}",
  request: {
    params: z.object({ upload_id: z.string().min(1) }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: UploadCompletionResponse } },
      description: "Upload completed.",
    },
    400: { content: JsonErrorContent, description: "Empty body." },
    404: { content: JsonErrorContent, description: "Upload not found." },
  },
  summary: "Upload media",
  tags: ["Uploads"],
});

export const registerUploadRoutes = (app: App): void => {
  app.openapi(reserveUploadRoute, async (c) => {
    const parsed = CreateUploadRequest.safeParse(
      await c.req.json().catch(() => ({}))
    );
    if (!parsed.success) {
      return c.json(
        { error: "invalid request", issues: parsed.error.issues },
        400
      );
    }
    const upload = await createUpload(c.env, {
      contentType: parsed.data.content_type,
      filename: parsed.data.filename,
    });
    return c.json(upload, 201);
  });

  app.openapi(completeUploadRoute, async (c) => {
    if (!c.req.raw.body) {
      return c.json({ error: "empty body" }, 400);
    }
    const result = await completeUpload(
      c.env,
      c.req.param("upload_id"),
      c.req.raw.body,
      c.req.header("content-type") ?? "application/octet-stream"
    );
    if (!result) {
      return c.json({ error: "upload not found" }, 404);
    }
    return c.json(result, 200);
  });
};
