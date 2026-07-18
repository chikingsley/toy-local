/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = config => ({
  type: "widget",
  name: "TimberVoxRecordingActivity",
  displayName: "TimberVox Recording",
  bundleIdentifier: ".recording-activity",
  deploymentTarget: "18.0",
  frameworks: ["ActivityKit", "AppIntents", "SwiftUI", "WidgetKit"],
  entitlements: {
    "com.apple.security.application-groups":
      config.ios.entitlements["com.apple.security.application-groups"],
  },
});
