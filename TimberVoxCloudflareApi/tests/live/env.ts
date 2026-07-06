import type { Env } from "../../src/bindings";

export const liveTestsEnabled = process.env.TIMBERVOX_LIVE_TESTS === "1";

export const liveEnv = (): Env =>
  ({
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
    ASSEMBLYAI_API_KEY: process.env.ASSEMBLYAI_API_KEY,
    CEREBRAS_API_KEY: process.env.CEREBRAS_API_KEY,
    DEEPGRAM_API_KEY: process.env.DEEPGRAM_API_KEY,
    DEEPSEEK_API_KEY: process.env.DEEPSEEK_API_KEY,
    ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY,
    GOOGLE_GENERATIVE_AI_API_KEY: process.env.GOOGLE_GENERATIVE_AI_API_KEY,
    GROQ_API_KEY: process.env.GROQ_API_KEY,
    MISTRAL_API_KEY: process.env.MISTRAL_API_KEY ?? "",
    OPENAI_API_KEY: process.env.OPENAI_API_KEY,
    ZAI_API_KEY: process.env.ZAI_API_KEY,
  }) as Env;
