import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import type { Env } from "../bindings";
import { getJob, jobView } from "../jobs/db";
import { JobView, JsonErrorContent } from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const getJobRoute = createRoute({
  method: "get",
  path: "/v1/jobs/{job_id}",
  request: {
    params: z.object({
      job_id: z.string().min(1),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: JobView } },
      description: "Job state and canonical result JSON.",
    },
    404: { content: JsonErrorContent, description: "Job not found." },
  },
  summary: "Get job",
  tags: ["Jobs"],
});

export const registerJobRoutes = (app: App): void => {
  app.openapi(getJobRoute, async (c) => {
    const job = await getJob(c.env, c.req.param("job_id"));
    if (!job) {
      return c.json({ error: "job not found" }, 404);
    }
    return c.json(jobView(job), 200);
  });
};
