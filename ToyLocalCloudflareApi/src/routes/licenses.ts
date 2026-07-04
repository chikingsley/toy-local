import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import { adminAuthFailure } from "../auth/http";
import {
  activateLicense,
  authenticateCredential,
  createLicense,
  revokeLicense,
} from "../auth/service";
import type { Env } from "../bindings";
import {
  JsonErrorContent,
  LicenseActivationRequest,
  LicenseActivationResponse,
  LicenseCreateRequest,
  LicenseCreateResponse,
  LicenseValidationResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const createLicenseRoute = createRoute({
  method: "post",
  path: "/v1/admin/licenses",
  request: {
    body: {
      content: { "application/json": { schema: LicenseCreateRequest } },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: LicenseCreateResponse } },
      description: "Issued license key. The raw key is returned once.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Create license",
  tags: ["Licensing"],
});

const revokeLicenseRoute = createRoute({
  method: "post",
  path: "/v1/admin/licenses/{license_id}/revoke",
  request: {
    params: z.object({ license_id: z.string().min(1) }),
  },
  responses: {
    200: {
      content: {
        "application/json": { schema: z.object({ revoked: z.literal(true) }) },
      },
      description: "License revoked.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    503: {
      content: JsonErrorContent,
      description: "Admin auth is not configured.",
    },
  },
  summary: "Revoke license",
  tags: ["Licensing"],
});

const activateLicenseRoute = createRoute({
  method: "post",
  path: "/v1/licenses/activate",
  request: {
    body: {
      content: { "application/json": { schema: LicenseActivationRequest } },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: LicenseActivationResponse } },
      description: "Activated license and app credential.",
    },
    400: { content: JsonErrorContent, description: "Invalid request." },
  },
  summary: "Activate license",
  tags: ["Licensing"],
});

const validateLicenseRoute = createRoute({
  method: "post",
  path: "/v1/licenses/validate",
  responses: {
    200: {
      content: { "application/json": { schema: LicenseValidationResponse } },
      description: "Credential is valid.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
  },
  summary: "Validate app credential",
  tags: ["Licensing"],
});

export const registerLicenseRoutes = (app: App): void => {
  app.openapi(createLicenseRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }

    const body = c.req.valid("json");
    const license = await createLicense(c.env, {
      displayName: body.display_name,
      email: body.email,
      expiresAt: body.expires_at,
      maxActivations: body.max_activations,
      notes: body.notes,
    });
    return c.json(
      {
        email: license.email,
        license_id: license.licenseId,
        license_key: license.licenseKey,
        max_activations: license.maxActivations,
        status: license.status,
        user_id: license.userId,
      },
      201
    );
  });

  app.openapi(revokeLicenseRoute, async (c) => {
    const failure = adminAuthFailure(c);
    if (failure) {
      return c.json({ error: failure.error }, failure.status);
    }
    const { license_id: licenseId } = c.req.valid("param");
    await revokeLicense(c.env, licenseId);
    return c.json({ revoked: true as const }, 200);
  });

  app.openapi(activateLicenseRoute, async (c) => {
    const body = c.req.valid("json");

    try {
      const activation = await activateLicense(c.env, {
        appVersion: body.app_version,
        deviceId: body.device_id,
        deviceName: body.device_name,
        email: body.email,
        licenseKey: body.license_key,
      });
      return c.json(
        {
          activation_id: activation.activationId,
          credential: activation.credential,
          credential_id: activation.credentialId,
          email: activation.email,
          license_id: activation.licenseId,
          user_id: activation.userId,
        },
        201
      );
    } catch (error) {
      return c.json(
        { error: error instanceof Error ? error.message : String(error) },
        400
      );
    }
  });

  app.openapi(validateLicenseRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }

    return c.json(
      {
        activation_id: auth.activationId,
        credential_id: auth.credentialId,
        email: auth.email,
        user_id: auth.userId,
        valid: true as const,
      },
      200
    );
  });
};
