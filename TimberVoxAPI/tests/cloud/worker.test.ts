import { describe, expect, it } from "vitest";
import { z } from "zod";

const baseURL = "https://timbervox.peacockery.studio";

const UsageResponse = z.object({
  rows: z.array(z.unknown()),
  totals: z.object({
    asr_seconds: z.number(),
    estimated_cost_micro_usd: z.number(),
    input_tokens: z.number(),
    output_tokens: z.number(),
    provider_latency_ms: z.number(),
    request_count: z.number(),
    total_tokens: z.number(),
  }),
});

const ObjectTransformResponse = z.object({
  output: z.object({ title: z.string() }),
  outputType: z.literal("object"),
});

const configuredAPIKey = (): string => {
  const value = process.env.TIMBERVOX_API_KEY?.trim();
  if (!value) {
    throw new Error(
      "TIMBERVOX_API_KEY is required for the cloud integration test"
    );
  }
  return value;
};

describe("deployed Worker and Cloudflare D1", () => {
  it("rejects an unauthenticated D1-backed request", async () => {
    const response = await fetch(`${baseURL}/v1/usage/daily`);
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });

  it("accepts the configured static key and reads deployed usage", async () => {
    const response = await fetch(`${baseURL}/v1/usage/daily`, {
      headers: {
        Authorization: `Bearer ${configuredAPIKey()}`,
      },
    });
    expect(response.status).toBe(200);
    expect(UsageResponse.parse(await response.json())).toBeDefined();
  });

  it("returns a caller-schema object from the deployed text endpoint", async () => {
    const response = await fetch(`${baseURL}/v1/text`, {
      body: JSON.stringify({
        messages: [
          {
            content:
              "Return a short title for a concrete coordination meeting.",
            role: "user",
          },
        ],
        model: "mistral-mistral-medium-latest",
        output: {
          description: "A short meeting title.",
          name: "contract_title",
          schema: {
            additionalProperties: false,
            properties: { title: { type: "string" } },
            required: ["title"],
            type: "object",
          },
          type: "object",
        },
        temperature: 0,
      }),
      headers: {
        Authorization: `Bearer ${configuredAPIKey()}`,
        "content-type": "application/json",
      },
      method: "POST",
    });
    expect(response.status).toBe(200);
    expect(ObjectTransformResponse.parse(await response.json())).toBeDefined();
  });
});
