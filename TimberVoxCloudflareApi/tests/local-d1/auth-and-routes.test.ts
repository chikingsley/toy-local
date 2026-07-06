import { randomUUID } from "node:crypto";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";

import { app } from "../../src";
import type { Env, QueueJobMessage } from "../../src/bindings";
import { executeD1, localD1Env, MemoryQueue, migrateLocalD1 } from "./helpers";

const adminHeaders = {
  "content-type": "application/json",
  "x-admin-token": "test-admin-token",
};

const jsonHeaders = { "content-type": "application/json" };
const licenseKeyPattern = /^tl_license_/;
const credentialPattern = /^tlc_/;

const createLicense = async (env: Env, email: string) => {
  const response = await app.request(
    "/v1/admin/licenses",
    {
      body: JSON.stringify({ email, max_activations: 1 }),
      headers: adminHeaders,
      method: "POST",
    },
    env
  );
  return {
    body: (await response.json()) as {
      license_id: string;
      license_key: string;
      user_id: string;
    },
    status: response.status,
  };
};

const activateLicense = async (
  env: Env,
  input: { email: string; licenseKey: string }
) => {
  const response = await app.request(
    "/v1/licenses/activate",
    {
      body: JSON.stringify({
        app_version: "local-test",
        device_id: `device_${randomUUID()}`,
        device_name: "Local D1 Test",
        email: input.email,
        license_key: input.licenseKey,
      }),
      headers: jsonHeaders,
      method: "POST",
    },
    env
  );
  return {
    body: (await response.json()) as {
      activation_id: string;
      credential: string;
      credential_id: string;
      user_id: string;
    },
    status: response.status,
  };
};

describe("local D1 auth and route integration", () => {
  beforeAll(async () => {
    await migrateLocalD1();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("creates a license, activates it, validates the issued credential, and revokes access", async () => {
    const env = localD1Env();
    const email = `license-${randomUUID()}@example.test`;
    const licenseResponse = await createLicense(env, email);
    expect(licenseResponse.status).toBe(201);
    const license = licenseResponse.body;
    expect(license.license_key).toMatch(licenseKeyPattern);

    const activationResponse = await activateLicense(env, {
      email,
      licenseKey: license.license_key,
    });
    expect(activationResponse.status).toBe(201);
    const activation = activationResponse.body;
    expect(activation.credential).toMatch(credentialPattern);
    expect(activation.user_id).toBe(license.user_id);

    const validateResponse = await app.request(
      "/v1/licenses/validate",
      {
        headers: { authorization: `Bearer ${activation.credential}` },
        method: "POST",
      },
      env
    );
    expect(validateResponse.status).toBe(200);
    await expect(validateResponse.json()).resolves.toMatchObject({
      activation_id: activation.activation_id,
      credential_id: activation.credential_id,
      valid: true,
    });

    const revokeResponse = await app.request(
      `/v1/admin/licenses/${license.license_id}/revoke`,
      { headers: adminHeaders, method: "POST" },
      env
    );
    expect(revokeResponse.status).toBe(200);

    const afterRevokeResponse = await app.request(
      "/v1/licenses/validate",
      {
        headers: { authorization: `Bearer ${activation.credential}` },
        method: "POST",
      },
      env
    );
    expect(afterRevokeResponse.status).toBe(401);
  });

  it("returns auth-linked usage rows and admin usage summaries from real local D1", async () => {
    const env = localD1Env();
    const email = `usage-${randomUUID()}@example.test`;
    const licenseResponse = await createLicense(env, email);
    expect(licenseResponse.status).toBe(201);
    const license = licenseResponse.body;
    const activationResponse = await activateLicense(env, {
      email,
      licenseKey: license.license_key,
    });
    expect(activationResponse.status).toBe(201);
    const activation = activationResponse.body;
    const requestId = `req_${randomUUID()}`;
    await executeD1(`
      INSERT INTO usage_daily
        (day, account_key, user_id, client_id, kind, provider, model, upstream_model,
         request_count, asr_seconds, input_tokens, output_tokens, total_tokens,
         provider_latency_ms, estimated_cost_micro_usd, first_request_at, last_request_at)
      VALUES
        ('2026-07-02', '${activation.user_id}', '${activation.user_id}', '${activation.credential_id}',
         'asr', 'mistral', 'mistral-voxtral-mini-transcribe-2507', 'voxtral-mini-2507',
         1, 4.5, 0, 0, 0, 250, 12, '2026-07-02T00:00:00.000Z', '2026-07-02T00:00:00.000Z')
    `);
    await executeD1(`
      INSERT INTO request_logs
        (id, account_key, user_id, client_id, route, status, kind, provider, model,
         upstream_model, estimated_cost_micro_usd, created_at)
      VALUES
        ('${requestId}', '${activation.user_id}', '${activation.user_id}', '${activation.credential_id}',
         '/v1/transcriptions', 200, 'asr', 'mistral', 'mistral-voxtral-mini-transcribe-2507',
         'voxtral-mini-2507', 12, '2026-07-02T00:00:00.000Z')
    `);

    const userUsage = await app.request(
      "/v1/usage/daily?from=2026-07-01&to=2026-07-03",
      {
        headers: { authorization: `Bearer ${activation.credential}` },
      },
      env
    );
    expect(userUsage.status).toBe(200);
    const userUsageBody = (await userUsage.json()) as {
      rows: unknown[];
      totals: { asr_seconds: number; estimated_cost_micro_usd: number };
    };
    expect(userUsageBody.rows).toHaveLength(1);
    expect(userUsageBody.totals).toMatchObject({
      asr_seconds: 4.5,
      estimated_cost_micro_usd: 12,
    });

    const adminSummary = await app.request(
      `/v1/admin/usage/summary?account_key=${activation.user_id}`,
      { headers: adminHeaders },
      env
    );
    expect(adminSummary.status).toBe(200);
    const adminSummaryBody = (await adminSummary.json()) as {
      analytics_engine: { queryable_from_worker: boolean };
      recent_request_logs: unknown[];
      totals: { request_count: number };
    };
    expect(adminSummaryBody.analytics_engine.queryable_from_worker).toBe(false);
    expect(adminSummaryBody.recent_request_logs.length).toBeGreaterThan(0);
    expect(adminSummaryBody.totals.request_count).toBe(1);
  });

  it("reserves uploads, completes storage, enqueues transcription jobs, returns idempotency hits, and polls jobs", async () => {
    const queue = new MemoryQueue();
    const env = localD1Env({
      JOBS_QUEUE: queue as unknown as Queue<QueueJobMessage>,
    });

    const uploadResponse = await app.request(
      "/v1/uploads",
      {
        body: JSON.stringify({
          content_type: "audio/wav",
          filename: "sample.wav",
        }),
        headers: jsonHeaders,
        method: "POST",
      },
      env
    );
    expect(uploadResponse.status).toBe(201);
    const upload = (await uploadResponse.json()) as {
      input_key: string;
      upload_id: string;
      upload_url: string;
    };
    expect(upload.input_key).toBe(`uploads/${upload.upload_id}/source`);

    const completeResponse = await app.request(
      upload.upload_url,
      {
        body: "fake wav bytes",
        headers: { "content-type": "audio/wav" },
        method: "PUT",
      },
      env
    );
    expect(completeResponse.status).toBe(200);
    await expect(completeResponse.json()).resolves.toMatchObject({
      input_key: upload.input_key,
      size_bytes: 14,
    });

    const idempotencyKey = `idem_${randomUUID()}`;
    const transcriptionBody = {
      asr_model: "mistral-voxtral-mini-transcribe-2507",
      input_key: upload.input_key,
    };
    const createJobResponse = await app.request(
      "/v1/transcriptions",
      {
        body: JSON.stringify(transcriptionBody),
        headers: {
          ...jsonHeaders,
          "idempotency-key": idempotencyKey,
          "x-timbervox-client-id": "route-contract-client",
        },
        method: "POST",
      },
      env
    );
    expect(createJobResponse.status).toBe(202);
    const job = (await createJobResponse.json()) as {
      job_id: string;
      status: string;
    };
    expect(job.status).toBe("queued");
    expect(queue.messages).toEqual([
      { job_id: job.job_id, kind: "transcription" },
    ]);

    const idempotentResponse = await app.request(
      "/v1/transcriptions",
      {
        body: JSON.stringify(transcriptionBody),
        headers: {
          ...jsonHeaders,
          "idempotency-key": idempotencyKey,
          "x-timbervox-client-id": "route-contract-client",
        },
        method: "POST",
      },
      env
    );
    expect(idempotentResponse.status).toBe(200);
    await expect(idempotentResponse.json()).resolves.toMatchObject({
      job_id: job.job_id,
      status: "queued",
    });
    expect(queue.messages).toHaveLength(1);

    const pollResponse = await app.request(`/v1/jobs/${job.job_id}`, {}, env);
    expect(pollResponse.status).toBe(200);
    await expect(pollResponse.json()).resolves.toMatchObject({
      job_id: job.job_id,
      result: null,
      status: "queued",
    });
  });

  it("validates bound resources through the admin route", async () => {
    const queue = new MemoryQueue();
    const dlq = new MemoryQueue();
    const env = localD1Env({
      JOBS_DLQ: dlq as unknown as Queue<QueueJobMessage>,
      JOBS_QUEUE: queue as unknown as Queue<QueueJobMessage>,
    });

    const response = await app.request(
      "/v1/admin/resources/validate",
      { headers: adminHeaders, method: "POST" },
      env
    );

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      checks: Record<string, { ok: boolean }>;
      ok: boolean;
      validation_id: string;
    };
    expect(body.ok).toBe(true);
    expect(body.checks).toMatchObject({
      analytics_engine: { ok: true },
      d1: { ok: true },
      dlq: { ok: true },
      durable_object: { ok: true },
      queue: { ok: true },
      r2: { ok: true },
      workers_logs: { ok: true },
    });
    expect(queue.messages).toEqual([
      { kind: "validation", validation_id: body.validation_id },
    ]);
    expect(dlq.messages).toEqual([
      { kind: "validation", validation_id: body.validation_id },
    ]);
  });

  it("queries Analytics Engine through the Cloudflare SQL API when credentials are configured", async () => {
    const env = localD1Env({
      CLOUDFLARE_ACCOUNT_ID: "0123456789abcdef0123456789abcdef",
      CLOUDFLARE_ANALYTICS_API_TOKEN: "test-token",
    });
    const fetchMock = vi.fn(
      (_url: string | URL | Request, init?: RequestInit) => {
        expect(init?.method).toBe("POST");
        expect(init?.headers).toMatchObject({
          Authorization: "Bearer test-token",
        });
        expect(String(init?.body)).toContain("FROM timbervox_usage");
        return Promise.resolve(
          Response.json({ data: [{ kind: "asr", request_count: 1 }] })
        );
      }
    );
    vi.stubGlobal("fetch", fetchMock);

    const response = await app.request(
      "/v1/admin/usage/analytics?account_key=acct_1&since_minutes=60&limit=5",
      { headers: adminHeaders },
      env
    );

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      data: { data: unknown[] };
      dataset: string;
      query: string;
    };
    expect(fetchMock).toHaveBeenCalledOnce();
    expect(body.dataset).toBe("timbervox_usage");
    expect(body.data.data).toEqual([{ kind: "asr", request_count: 1 }]);
    expect(body.query).toContain("index1 = 'acct_1'");
  });

  it("queries Analytics Engine with an admin-supplied one-off SQL API token", async () => {
    const env = localD1Env({
      CLOUDFLARE_ACCOUNT_ID: "0123456789abcdef0123456789abcdef",
    });
    const fetchMock = vi.fn(
      (_url: string | URL | Request, init?: RequestInit) => {
        expect(init?.headers).toMatchObject({
          Authorization: "Bearer one-off-token",
        });
        return Promise.resolve(
          Response.json({ data: [{ kind: "validation", request_count: 1 }] })
        );
      }
    );
    vi.stubGlobal("fetch", fetchMock);

    const response = await app.request(
      "/v1/admin/usage/analytics?account_key=acct_2",
      {
        headers: {
          ...adminHeaders,
          "x-analytics-api-token": "one-off-token",
        },
      },
      env
    );

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      data: { data: unknown[] };
      query: string;
    };
    expect(fetchMock).toHaveBeenCalledOnce();
    expect(body.data.data).toEqual([{ kind: "validation", request_count: 1 }]);
    expect(body.query).toContain("index1 = 'acct_2'");
  });
});
