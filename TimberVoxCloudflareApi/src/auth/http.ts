import type { Context } from "hono";

import type { Env } from "../bindings";

const bearerPattern = /^Bearer\s+(.+)$/i;

export const adminAuthFailure = (
  c: Context<{ Bindings: Env }>
): { error: string; status: 401 | 503 } | null => {
  const expected = c.env.TIMBERVOX_ADMIN_TOKEN;
  if (!expected) {
    return { error: "admin auth is not configured", status: 503 };
  }
  const bearer = c.req.header("authorization")?.match(bearerPattern)?.[1];
  const token = c.req.header("x-admin-token") ?? bearer;
  if (token !== expected) {
    return { error: "unauthorized", status: 401 };
  }
  return null;
};
