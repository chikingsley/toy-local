/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = config => ({
  type: "app-intent",
  name: "TimberVoxAppIntents",
  displayName: "TimberVox Shortcuts",
  bundleIdentifier: ".app-intents",
  deploymentTarget: "18.0",
  frameworks: ["ActivityKit", "AppIntents", "AVFoundation"],
  entitlements: {
    "com.apple.security.application-groups":
      config.ios.entitlements["com.apple.security.application-groups"],
  },
});
