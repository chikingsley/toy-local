import { describe, expect, it } from "vitest";

import { runText } from "../../src/ai/text/service";
import { liveEnv, liveTestsEnabled } from "./env";

interface TextCase {
  envKey: string;
  model: string;
}

// The production request itself stops at ten seconds. The small harness margin
// lets Vitest report the provider error instead of replacing it with a test
// timeout.
const liveTestTimeoutMs = 10_500;

const cases: TextCase[] = [
  { envKey: "MISTRAL_API_KEY", model: "mistral-mistral-small-latest" },
  { envKey: "OPENAI_API_KEY", model: "openai-gpt-5.5" },
  {
    envKey: "GOOGLE_GENERATIVE_AI_API_KEY",
    model: "google-gemini-3.1-flash-lite",
  },
];

describe("live text providers", () => {
  for (const testCase of cases) {
    it(
      `generates text with ${testCase.model}`,
      async ({ skip }) => {
        if (!(liveTestsEnabled && process.env[testCase.envKey])) {
          skip("live tests disabled or provider credential unavailable");
        }
        const result = await runText(liveEnv(), {
          messages: [
            {
              content:
                "Clean up this transcript as a short message. Return only the cleaned text.\n\nhello comma this is a live test period thank you",
              role: "user",
            },
          ],
          model: testCase.model,
        });

        expect(result.model).toBe(testCase.model);
        expect(result.text.trim().length).toBeGreaterThan(0);
      },
      liveTestTimeoutMs
    );
  }

  it(
    "returns a caller-schema object with Mistral",
    async ({ skip }) => {
      if (!(liveTestsEnabled && process.env.MISTRAL_API_KEY)) {
        skip("live tests disabled or Mistral credential unavailable");
      }
      const result = await runText(liveEnv(), {
        messages: [
          {
            content: "Return a short title for a coordination meeting.",
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
      });

      expect(result.outputType).toBe("object");
      if (result.outputType === "object") {
        expect(typeof result.output.title).toBe("string");
      }
    },
    liveTestTimeoutMs
  );
});
