import contract from "../app-group-bridge.contract.json";

declare const __dirname: string;
declare const require: (module: string) => unknown;

const { readFileSync } = require("fs") as {
  readFileSync: (path: string, encoding: string) => string;
};
const { resolve } = require("path") as {
  resolve: (...paths: string[]) => string;
};

describe("App Group bridge contract", () => {
  const typescript = readFileSync(
    resolve(__dirname, "../src/features/keyboard/app-group-bridge.ts"),
    "utf8",
  );
  const swift = readFileSync(
    resolve(__dirname, "../targets/keyboard/AppGroupBridge.swift"),
    "utf8",
  );
  const keyboardController = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardViewController.swift"),
    "utf8",
  );
  const keyboardSurface = readFileSync(
    resolve(__dirname, "../targets/keyboard/SwipeKeySurface.swift"),
    "utf8",
  );
  const keyboardRoot = readFileSync(
    resolve(__dirname, "../targets/keyboard/KeyboardRootView.swift"),
    "utf8",
  );
  const setupState = readFileSync(
    resolve(__dirname, "../src/features/setup/setup-state.ts"),
    "utf8",
  );
  const welcomeScreen = readFileSync(
    resolve(__dirname, "../src/app/(onboarding)/welcome.tsx"),
    "utf8",
  );
  const session = readFileSync(
    resolve(__dirname, "../src/features/dictation/dictation-session.tsx"),
    "utf8",
  );
  const delivery = readFileSync(
    resolve(__dirname, "../src/features/dictation/result-delivery.ts"),
    "utf8",
  );
  const keys = Object.values(contract.keys).flat();

  it("keeps the schema and every public key aligned across processes", () => {
    expect(typescript).toContain(
      `const BRIDGE_SCHEMA_VERSION = ${contract.schemaVersion}`,
    );
    expect(swift).toContain(
      `static let schemaVersion = ${contract.schemaVersion}`,
    );
    expect(typescript).toContain(contract.appGroup);
    expect(swift).toContain(contract.appGroup);
    for (const key of keys) {
      expect(typescript).toContain(`"${key}"`);
      expect(swift).toContain(`case ${key}`);
    }
  });

  it("publishes keyboard results with request ownership instead of v1 pending text", () => {
    expect(session).toContain('lastEntryPointRef.current === "keyboard"');
    expect(delivery).toContain('writeBridgeString("finalRequestId"');
    expect(delivery).toContain('writeBridgeString("finalResultId"');
    expect(session).not.toContain('storage.set("pendingTranscript"');
    expect(keyboardController).toContain(
      "requestID == KeyboardBridge.string(for: .keyboardRequestId)",
    );
    expect(keyboardController).toContain(
      "resultID != KeyboardBridge.string(for: .consumedResultId)",
    );
  });

  it("opens the app through TimberVox dictation and resumes the owned keyboard request", () => {
    expect(keyboardController).toContain("hasDictationKey = true");
    expect(keyboardController).toContain(
      'KeyboardBridge.set("keyboard", for: .requestedEntryPoint)',
    );
    expect(session).toContain("const pendingKeyboardRequestId =");
    expect(session).toContain(
      'beginDictation("keyboard", pendingKeyboardRequestId)',
    );
  });

  it("draws adaptive key labels in light and dark host apps", () => {
    expect(keyboardSurface).toContain(
      ".foregroundStyle(Color(uiColor: .label))",
    );
  });

  it("uses a conventional keyboard layout with third-row delete and alternate pages", () => {
    expect(keyboardSurface).toContain("deleteFrame");
    expect(keyboardSurface).toContain('systemName: "delete.left"');
    expect(keyboardSurface).toContain("struct AlternateKeySurface");
    expect(keyboardRoot).toContain(
      'Text(model.page == .letters ? "123" : "ABC")',
    );
    expect(keyboardRoot).toContain(".frame(width: 43, height: 44)");
    expect(keyboardRoot).not.toContain('keyButton(systemName: "delete.left"');
  });

  it("invalidates stale Settings observations and keeps verification above the keyboard", () => {
    expect(setupState).toContain('writeBridgeBoolean("keyboardSeen", false)');
    expect(setupState).toContain(
      'writeBridgeBoolean("keyboardHasFullAccess", false)',
    );
    expect(welcomeScreen).toContain("KeyboardAvoidingView");
    expect(welcomeScreen).toContain("ref={verificationInput}");
  });
});
