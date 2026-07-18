const fs = require("node:fs");
const path = require("node:path");

function localTimberVoxCredential() {
  try {
    const config = fs.readFileSync(
      path.resolve(__dirname, "../../Config/keys/TimberVoxAPI.local.xcconfig"),
      "utf8",
    );
    return config.match(/^TIMBERVOX_API_KEY\s*=\s*(.+)$/m)?.[1]?.trim() ?? "";
  } catch {
    return "";
  }
}

function developmentCredential() {
  if (process.env.TIMBERVOX_EMBED_DEV_CREDENTIAL !== "1") return "";
  const credential =
    process.env.TIMBERVOX_API_KEY?.trim() || localTimberVoxCredential();
  if (!credential) {
    throw new Error(
      "TIMBERVOX_EMBED_DEV_CREDENTIAL=1 requires TIMBERVOX_API_KEY or Config/keys/TimberVoxAPI.local.xcconfig",
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
      ...(credential ? { timberVoxApiKey: credential } : {}),
    },
  };
};
