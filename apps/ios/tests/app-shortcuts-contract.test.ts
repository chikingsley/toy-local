const fs = jest.requireActual("fs") as {
  readFileSync(filePath: string, encoding: string): string;
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
};

const projectRoot = process.cwd();

describe("App Shortcut registration contract", () => {
  it("registers its native AppDelegate plugin in Expo config", () => {
    const appConfig = JSON.parse(
      fs.readFileSync(path.join(projectRoot, "app.json"), "utf8"),
    ) as { expo: { plugins: Array<string | unknown[]> } };
    expect(appConfig.expo.plugins).toContain(
      "./plugins/with-timbervox-app-shortcuts",
    );
  });

  it("injects exactly one host-owned provider during every prebuild", () => {
    const plugin = fs.readFileSync(
      path.join(projectRoot, "plugins", "with-timbervox-app-shortcuts.js"),
      "utf8",
    );
    const sharedIntent = fs.readFileSync(
      path.join(
        projectRoot,
        "targets",
        "shortcut",
        "_shared",
        "AudioRecordingIntent.swift",
      ),
      "utf8",
    );

    expect(plugin).toContain('require("expo/config-plugins")');
    expect(plugin).toContain("withXcodeProject");
    expect(plugin).toContain("import AppIntents");
    expect(plugin).toContain(
      "struct TimberVoxAppShortcuts: AppShortcutsProvider",
    );
    expect(plugin).toContain("intent: AudioRecordingIntent()");
    expect(plugin).toContain(
      "configuration.buildSettings.CURRENT_PROJECT_VERSION = buildNumber",
    );
    expect(sharedIntent).not.toContain(
      "struct TimberVoxAppShortcuts: AppShortcutsProvider",
    );
  });

  it("keeps delivery native instead of returning a Shortcuts text item", () => {
    const sharedIntent = fs.readFileSync(
      path.join(
        projectRoot,
        "targets",
        "shortcut",
        "_shared",
        "AudioRecordingIntent.swift",
      ),
      "utf8",
    );

    expect(sharedIntent).toContain(
      "func perform() async throws -> some IntentResult",
    );
    expect(sharedIntent).not.toContain("ReturnsValue<");
    expect(sharedIntent).not.toContain(".result(value:");
    expect(sharedIntent).toContain("await copyToClipboard(text)");
  });
});
