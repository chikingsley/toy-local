declare const __dirname: string;
declare const require: (module: string) => unknown;

const { readFileSync } = require("fs") as {
  readFileSync: (path: string, encoding: string) => string;
};
const { resolve } = require("path") as {
  resolve: (...paths: string[]) => string;
};

describe("swipe decoder contract", () => {
  const decoder = readFileSync(
    resolve(__dirname, "../targets/keyboard/GeometricSwipeDecoder.swift"),
    "utf8",
  );
  const languageEngine = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardLanguageEngine.swift"),
    "utf8",
  );
  const nativeTests = readFileSync(
    resolve(
      __dirname,
      "../targets/keyboard-tests/GeometricSwipeDecoderTests.swift",
    ),
    "utf8",
  );
  const neuralDecoder = readFileSync(
    resolve(__dirname, "../targets/keyboard/NeuralSwipeDecoder.swift"),
    "utf8",
  );
  const runtime = readFileSync(
    resolve(__dirname, "../targets/keyboard/FutoSwipeRuntime.swift"),
    "utf8",
  );
  const settings = readFileSync(
    resolve(__dirname, "../src/app/(tabs)/settings/index.tsx"),
    "utf8",
  );
  const appConfig = readFileSync(resolve(__dirname, "../app.json"), "utf8");
  const keyboardController = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardViewController.swift"),
    "utf8",
  );
  const frequencyVocabulary = readFileSync(
    resolve(
      __dirname,
      "../targets/keyboard/assets/english_frequency.txt",
    ),
    "utf8",
  );

  it("never treats crossed keys as the intended word length", () => {
    expect(decoder).not.toContain("estimatedKeyCount");
    expect(languageEngine).not.toContain("estimatedLength");
  });

  it("keeps the reported when-versus-watermelon failure in the native corpus", () => {
    expect(nativeTests).toContain('densePath(for: "when")');
    expect(nativeTests).toContain('word: "watermelon"');
    expect(nativeTests).toContain('"when"');
  });

  it("runs all three FUTO models behind a geometric fallback", () => {
    expect(neuralDecoder).toContain("FutoSwipeRuntime");
    expect(neuralDecoder).toContain("fallback.predictions");
    expect(runtime).toContain('named: "futo_swipe_encoder"');
    expect(runtime).toContain('named: "futo_swipe_refiner"');
    expect(runtime).toContain('forResource: "futo_swipe_context_lm"');
    expect(neuralDecoder).toContain("ContextCandidateReranker");
  });

  it("keeps the reported haptic and industrial words in the active vocabulary", () => {
    const activeVocabulary = frequencyVocabulary.split("\n").slice(0, 25_000);
    expect(activeVocabulary).toContain("haptic 5374");
    expect(activeVocabulary).toContain("industrial 5375");
    expect(nativeTests).toContain('"haptic"');
    expect(nativeTests).toContain('"industrial"');
  });

  it("uses the same stronger haptic for ordinary keys and completed swipes", () => {
    expect(keyboardController).toContain(
      "UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.78)",
    );
    expect(keyboardController.match(/ordinaryHapticFeedback\(\)/g)).toHaveLength(
      3,
    );
  });

  it("merges learned and supplementary words into swipe candidates", () => {
    expect(languageEngine).toContain("learnedIndicesByEndpoints");
    expect(languageEngine).toContain("supplementaryIndicesByEndpoints");
    expect(languageEngine).toContain("preferredForms");
    expect(languageEngine).toContain("entriesByWord.values");
  });

  it("includes the pinned ExecuTorch keyboard plugin and required attribution", () => {
    expect(appConfig).toContain("./plugins/with-executorch-keyboard");
    expect(settings).toContain(
      "Swipe typing is powered by FUTO Swipe technology.",
    );
  });
});
