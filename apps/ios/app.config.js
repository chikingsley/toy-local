const path = require("node:path");

try {
  process.loadEnvFile(path.resolve(__dirname, "../..", ".env"));
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

function developmentCredential() {
  const production =
    process.env.PEACOCKERY_VOICE_ENVIRONMENT === "production" ||
    process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL === "0";
  if (production) return "";
  const credential = process.env.PEACOCKERY_VOICE_API_KEY?.trim();
  const credentialRequired =
    process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL === "1" ||
    process.env.CONFIGURATION === "Release";
  if (!credential && credentialRequired) {
    throw new Error(
      "Internal TimberVox builds require PEACOCKERY_VOICE_API_KEY",
    );
  }
  return credential ?? "";
}

module.exports = ({ config }) => {
  const credential = developmentCredential();
  return {
    ...config,
    extra: {
      ...config.extra,
      peacockeryVoiceEnvironment:
        process.env.PEACOCKERY_VOICE_ENVIRONMENT === "production"
          ? "production"
          : "lab",
      ...(credential ? { peacockeryVoiceApiKey: credential } : {}),
    },
  };
};
