const { withAppDelegate, withXcodeProject } = require("expo/config-plugins");

const providerDefinition = [
  "struct TimberVoxAppShortcuts: AppShortcutsProvider {",
  "  static var appShortcuts: [AppShortcut] {",
  "    AppShortcut(",
  "      intent: AudioRecordingIntent(),",
  "      phrases: [",
  '        "Toggle dictation with \\(.applicationName)",',
  '        "Record with \\(.applicationName)",',
  '        "Start dictation with \\(.applicationName)",',
  '        "Stop dictation with \\(.applicationName)",',
  "      ],",
  '      shortTitle: "Toggle Dictation",',
  '      systemImageName: "waveform"',
  "    )",
  "  }",
  "}",
].join("\n");

module.exports = function withTimberVoxAppShortcuts(config) {
  config = withAppDelegate(config, (appDelegateConfig) => {
    if (appDelegateConfig.modResults.language !== "swift") {
      throw new Error("TimberVox App Shortcut registration requires Swift.");
    }

    let source = appDelegateConfig.modResults.contents;
    if (!source.includes("import AppIntents")) {
      const importAnchor = "internal import Expo";
      if (!source.includes(importAnchor)) {
        throw new Error("Unable to locate the TimberVox AppDelegate imports.");
      }
      source = source.replace(
        importAnchor,
        `import AppIntents\n${importAnchor}`,
      );
    }

    if (!source.includes("struct TimberVoxAppShortcuts: AppShortcutsProvider")) {
      const providerAnchor = "class ReactNativeDelegate";
      if (!source.includes(providerAnchor)) {
        throw new Error("Unable to locate the TimberVox AppDelegate body.");
      }
      source = source.replace(
        providerAnchor,
        `${providerDefinition}\n\n${providerAnchor}`,
      );
    }

    appDelegateConfig.modResults.contents = source;
    return appDelegateConfig;
  });

  return withXcodeProject(config, (projectConfig) => {
    const buildNumber = projectConfig.ios?.buildNumber;
    const bundleIdentifier = projectConfig.ios?.bundleIdentifier;
    if (!buildNumber || !bundleIdentifier) {
      throw new Error(
        "TimberVox requires an iOS bundle identifier and build number.",
      );
    }

    const configurations =
      projectConfig.modResults.pbxXCBuildConfigurationSection();
    for (const [key, configuration] of Object.entries(configurations)) {
      if (key.endsWith("_comment") || !configuration.buildSettings) continue;
      const configuredBundleIdentifier = String(
        configuration.buildSettings.PRODUCT_BUNDLE_IDENTIFIER ?? "",
      ).replaceAll('"', "");
      if (configuredBundleIdentifier !== bundleIdentifier) continue;
      configuration.buildSettings.CURRENT_PROJECT_VERSION = buildNumber;
    }

    return projectConfig;
  });
};
