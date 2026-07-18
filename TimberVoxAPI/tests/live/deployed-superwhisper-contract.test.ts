import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { liveTestsEnabled } from "./env";

const baseUrl = "https://timbervox.peacockery.studio";
const fixturePath = resolve("tests/fixtures/audio/asr-smoke.wav");

const configuredApiKey = (): string | null =>
  process.env.TIMBERVOX_API_KEY?.trim() || null;

const authorizationHeaders = (apiKey: string): Record<string, string> => ({
  Authorization: `Bearer ${apiKey}`,
});

const jsonRequest = (
  apiKey: string,
  body: Record<string, unknown>
): RequestInit => ({
  body: JSON.stringify(body),
  headers: {
    ...authorizationHeaders(apiKey),
    "content-type": "application/json",
  },
  method: "POST",
});

describe.sequential("deployed Superwhisper-backed API contract", () => {
  it("keeps execution details out of the public model catalog", async ({
    skip,
  }) => {
    const apiKey = configuredApiKey();
    if (!(liveTestsEnabled && apiKey)) {
      skip("live tests disabled or TIMBERVOX_API_KEY unavailable");
    }

    const response = await fetch(`${baseUrl}/v1/models`);
    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      models: Record<string, unknown>[];
    };
    const sonnet = payload.models.find(
      (model) => model.id === "anthropic-claude-sonnet-5"
    );
    const nova = payload.models.find((model) => model.id === "deepgram-nova-3");

    expect(sonnet).toMatchObject({ provider: "anthropic" });
    expect(nova).toMatchObject({ provider: "deepgram" });
    expect(sonnet).not.toHaveProperty("executionProvider");
    expect(sonnet).not.toHaveProperty("execution_provider");
    expect(nova).not.toHaveProperty("executionProvider");
    expect(nova).not.toHaveProperty("execution_provider");
  });

  it("generates through a logical Anthropic route", async ({ skip }) => {
    const apiKey = configuredApiKey();
    if (!(liveTestsEnabled && apiKey)) {
      skip("live tests disabled or TIMBERVOX_API_KEY unavailable");
    }

    const response = await fetch(
      `${baseUrl}/v1/text`,
      jsonRequest(apiKey, {
        maxOutputTokens: 24,
        messages: [
          {
            content: "Return exactly three words about desert rain.",
            role: "user",
          },
        ],
        model: "anthropic-claude-sonnet-5",
      })
    );
    expect(response.status).toBe(200);
    const result = (await response.json()) as Record<string, unknown>;
    expect(result).toMatchObject({
      model: "anthropic-claude-sonnet-5",
      outputType: "text",
      provider: "anthropic",
      upstreamModel: "claude-sonnet-5",
    });
    expect(String(result.text ?? "").trim().length).toBeGreaterThan(0);
  });

  it("reports no Superwhisper execution-contract drift", async ({ skip }) => {
    const adminToken = process.env.TIMBERVOX_ADMIN_TOKEN?.trim();
    if (!(liveTestsEnabled && adminToken)) {
      skip("live tests disabled or TIMBERVOX_ADMIN_TOKEN unavailable");
    }

    const response = await fetch(`${baseUrl}/v1/admin/model-inventory`, {
      headers: { "x-admin-token": adminToken },
    });
    expect(response.status).toBe(200);
    const report = (await response.json()) as {
      drift: {
        catalog_models_without_provider_match: Record<string, unknown>[];
        provider_models_not_in_catalog: Record<string, unknown>[];
      };
      sources: Record<string, unknown>[];
    };
    const source = report.sources.find(
      (candidate) => candidate.provider === "superwhisper"
    );
    const missing = report.drift.catalog_models_without_provider_match.filter(
      (model) => model.provider === "superwhisper"
    );
    const extra = report.drift.provider_models_not_in_catalog.filter(
      (model) => model.provider === "superwhisper"
    );

    expect(source).toMatchObject({
      provider: "superwhisper",
      source_kind: "contract",
      status: "ok",
    });
    expect(missing).toEqual([]);
    expect(extra).toEqual([]);
  });

  it("runs the upload and synchronous batch ASR path", async ({ skip }) => {
    const apiKey = configuredApiKey();
    if (!(liveTestsEnabled && apiKey)) {
      skip("live tests disabled or TIMBERVOX_API_KEY unavailable");
    }
    const audio = await readFile(fixturePath);
    const reservationResponse = await fetch(
      `${baseUrl}/v1/uploads`,
      jsonRequest(apiKey, {
        content_type: "audio/wav",
        filename: "superwhisper-live-smoke.wav",
        size_bytes: audio.byteLength,
      })
    );
    expect(reservationResponse.status).toBe(201);
    const reservation = (await reservationResponse.json()) as {
      input_key: string;
      transfer: {
        headers: Record<string, string>;
        kind: string;
        url: string;
      };
      upload_id: string;
    };
    expect(reservation.transfer.kind).toBe("single");

    const uploadResponse = await fetch(reservation.transfer.url, {
      body: audio,
      headers: reservation.transfer.headers,
      method: "PUT",
    });
    expect(uploadResponse.ok).toBe(true);

    const completionResponse = await fetch(
      `${baseUrl}/v1/uploads/${reservation.upload_id}/complete`,
      jsonRequest(apiKey, { parts: [] })
    );
    expect(completionResponse.status).toBe(200);

    const transcriptionResponse = await fetch(
      `${baseUrl}/v1/transcriptions`,
      jsonRequest(apiKey, {
        asr_model: "deepgram-nova-3",
        input_key: reservation.input_key,
        sync: true,
      })
    );
    expect(transcriptionResponse.status).toBe(200);
    const job = (await transcriptionResponse.json()) as {
      result?: {
        provenance?: Record<string, unknown>;
        text?: string;
      };
      status?: string;
    };
    expect(job.status).toBe("succeeded");
    expect(job.result?.provenance).toMatchObject({
      model: "deepgram-nova-3",
      provider: "deepgram",
      transport: "batch",
      upstream_model: "nova-3",
    });
    expect(String(job.result?.text ?? "").trim().length).toBeGreaterThan(0);
  });
});
