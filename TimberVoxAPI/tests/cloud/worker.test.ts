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

const TextStreamEvent = z.discriminatedUnion("type", [
  z.object({
    sequence: z.number().int().nonnegative(),
    type: z.literal("stream.started"),
  }),
  z.object({
    delta: z.string(),
    sequence: z.number().int().nonnegative(),
    type: z.literal("text.delta"),
  }),
  z.object({
    sequence: z.number().int().nonnegative(),
    type: z.literal("stream.completed"),
    usage: z.object({ output_tokens: z.number().optional() }),
  }),
  z.object({
    error: z.object({ message: z.string() }),
    sequence: z.number().int().nonnegative(),
    type: z.literal("stream.failed"),
  }),
]);

const parseSseEvents = (body: string): z.infer<typeof TextStreamEvent>[] =>
  body.split("\n\n").flatMap((frame) => {
    const data = frame
      .split("\n")
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice("data:".length).trimStart())
      .join("\n");
    return data ? [TextStreamEvent.parse(JSON.parse(data))] : [];
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
  it("rejects an unauthenticated model-catalog request", async () => {
    const response = await fetch(`${baseURL}/v1/models`);
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });

  it("returns the model catalog to an authenticated caller", async () => {
    const response = await fetch(`${baseURL}/v1/models`, {
      headers: {
        Authorization: `Bearer ${configuredAPIKey()}`,
      },
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      models: expect.any(Array),
      presentation_schema_version: 1,
    });
  });

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

  it("streams normalized text events through the deployed Worker", async () => {
    const response = await fetch(`${baseURL}/v1/text/stream`, {
      body: JSON.stringify({
        maxOutputTokens: 32,
        messages: [
          {
            content: "Return exactly five words about desert rain.",
            role: "user",
          },
        ],
        model: "mistral-mistral-small-latest",
        temperature: 0,
      }),
      headers: {
        Authorization: `Bearer ${configuredAPIKey()}`,
        "content-type": "application/json",
      },
      method: "POST",
    });
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("text/event-stream");

    const events = parseSseEvents(await response.text());
    expect(events.at(0)?.type).toBe("stream.started");
    expect(events.some((event) => event.type === "text.delta")).toBe(true);
    const terminal = events.at(-1);
    expect(terminal?.type).toBe("stream.completed");
    expect(terminal?.sequence).toBe(events.length - 1);
  });
});
