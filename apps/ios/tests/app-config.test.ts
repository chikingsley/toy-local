type ExpoConfigInput = {
  config: { extra?: Record<string, unknown> };
};

type ExpoConfigFactory = (input: ExpoConfigInput) => {
  extra?: Record<string, unknown>;
};

const createConfig = require("../app.config.js") as ExpoConfigFactory;

describe("mobile build credential policy", () => {
  const originalEmbed = process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL;
  const originalEnvironment = process.env.PEACOCKERY_VOICE_ENVIRONMENT;
  const originalKey = process.env.PEACOCKERY_VOICE_API_KEY;

  afterEach(() => {
    restoreEnvironment("PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL", originalEmbed);
    restoreEnvironment("PEACOCKERY_VOICE_ENVIRONMENT", originalEnvironment);
    restoreEnvironment("PEACOCKERY_VOICE_API_KEY", originalKey);
  });

  it("embeds a supplied disposable credential only for a dev-enabled build", () => {
    process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL = "1";
    process.env.PEACOCKERY_VOICE_ENVIRONMENT = "lab";
    process.env.PEACOCKERY_VOICE_API_KEY = "disposable-test-key";

    const result = createConfig({ config: { extra: { router: {} } } });

    expect(result.extra?.peacockeryVoiceApiKey).toBe("disposable-test-key");
    expect(result.extra?.peacockeryVoiceEnvironment).toBe("lab");
  });

  it("omits the credential from production config even when one is present", () => {
    process.env.PEACOCKERY_VOICE_EMBED_DEV_CREDENTIAL = "0";
    process.env.PEACOCKERY_VOICE_ENVIRONMENT = "production";
    process.env.PEACOCKERY_VOICE_API_KEY = "must-not-ship";

    const result = createConfig({ config: { extra: { router: {} } } });

    expect(result.extra).not.toHaveProperty("peacockeryVoiceApiKey");
    expect(result.extra?.peacockeryVoiceEnvironment).toBe("production");
  });
});

function restoreEnvironment(name: string, value: string | undefined) {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
