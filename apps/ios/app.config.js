const { execFileSync } = require("node:child_process");

function localLabCredential() {
  try {
    return execFileSync(
      "/usr/bin/security",
      [
        "find-generic-password",
        "-a",
        "lab-api-key",
        "-s",
        "peacockery-voice",
        "-w",
      ],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
  } catch {
    return "";
  }
}

function developmentCredential() {
  if (process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL !== "1") return "";
  const credential =
    process.env.PEACOCKERY_VOICE_API_KEY?.trim() || localLabCredential();
  if (!credential) {
    throw new Error(
      "PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL=1 requires PEACOCKERY_VOICE_API_KEY or the local peacockery-voice/lab-api-key Keychain item",
    );
  }
  return credential;
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
