type ExpoConfigInput = {
  config: { extra?: Record<string, unknown> };
};

type ExpoConfigFactory = (input: ExpoConfigInput) => {
  extra?: Record<string, unknown>;
};

const createConfig = require("../app.config.js") as ExpoConfigFactory;

describe("mobile build credential policy", () => {
  const originalEmbed = process.env.TIMBERVOX_EMBED_DEV_CREDENTIAL;
  const originalKey = process.env.TIMBERVOX_API_KEY;

  afterEach(() => {
    restoreEnvironment("TIMBERVOX_EMBED_DEV_CREDENTIAL", originalEmbed);
    restoreEnvironment("TIMBERVOX_API_KEY", originalKey);
  });

  it("embeds a supplied disposable credential only for a dev-enabled build", () => {
    process.env.TIMBERVOX_EMBED_DEV_CREDENTIAL = "1";
    process.env.TIMBERVOX_API_KEY = "disposable-test-key";

    const result = createConfig({ config: { extra: { router: {} } } });

    expect(result.extra?.timberVoxApiKey).toBe("disposable-test-key");
  });

  it("omits the credential from production config even when one is present", () => {
    process.env.TIMBERVOX_EMBED_DEV_CREDENTIAL = "0";
    process.env.TIMBERVOX_API_KEY = "must-not-ship";

    const result = createConfig({ config: { extra: { router: {} } } });

    expect(result.extra).not.toHaveProperty("timberVoxApiKey");
  });
});

function restoreEnvironment(name: string, value: string | undefined) {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
