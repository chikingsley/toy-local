import { describe, expect, it } from "vitest";

import { runTextTransform } from "../../src/ai/text-transform";
import { liveEnv, liveTestsEnabled } from "./env";

interface TextCase {
  envKey: string;
  model: string;
}

const cases: TextCase[] = [
  { envKey: "MISTRAL_API_KEY", model: "mistral-mistral-small-latest" },
  { envKey: "OPENAI_API_KEY", model: "openai-gpt-5.5" },
  {
    envKey: "GOOGLE_GENERATIVE_AI_API_KEY",
    model: "google-gemini-flash-latest",
  },
];

describe("live text transform providers", () => {
  for (const testCase of cases) {
    it.skipIf(!(liveTestsEnabled && process.env[testCase.envKey]))(
      `transforms text with ${testCase.model}`,
      async () => {
        const result = await runTextTransform(liveEnv(), {
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
      }
    );
  }
});
