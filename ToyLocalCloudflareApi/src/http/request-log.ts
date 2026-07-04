import type { Context, Next } from "hono";

const redactPath = (url: string): string => {
  const parsed = new URL(url);
  return parsed.pathname;
};

export const requestLogger = async (c: Context, next: Next): Promise<void> => {
  const startedAt = performance.now();
  await next();
  console.log(
    JSON.stringify({
      duration_ms: Math.round(performance.now() - startedAt),
      event: "http.request",
      method: c.req.method,
      path: redactPath(c.req.url),
      request_id: c.req.header("cf-ray") ?? c.req.header("x-request-id"),
      status: c.res.status,
    })
  );
};
