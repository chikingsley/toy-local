import {
  createSuperwhisper,
  type SuperwhisperCredentials,
  type SuperwhisperProvider,
} from "@chikingsley/superwhisper-provider";

import type { Env } from "../../bindings";

export const superwhisperCredentials = (env: Env): SuperwhisperCredentials => ({
  id: env.SUPERWHISPER_X_ID ?? "",
  license: env.SUPERWHISPER_X_LICENSE ?? "",
  signature: env.SUPERWHISPER_X_SIGNATURE ?? "",
  userAgent: env.SUPERWHISPER_USER_AGENT ?? "",
});

export const superwhisperIsConfigured = (env: Env): boolean =>
  Object.values(superwhisperCredentials(env)).every(
    (value) => value.trim().length > 0
  );

export const createSuperwhisperProvider = (env: Env): SuperwhisperProvider => {
  if (!superwhisperIsConfigured(env)) {
    throw new Error("missing Superwhisper credentials");
  }
  return createSuperwhisper({ credentials: superwhisperCredentials(env) });
};
