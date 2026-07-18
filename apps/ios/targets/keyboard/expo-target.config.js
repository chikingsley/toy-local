/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = config => ({
  type: "keyboard",
  name: "TimberVoxKeyboard",
  displayName: "TimberVox",
  bundleIdentifier: ".keyboard",
  deploymentTarget: "18.0",
  frameworks: ["ActivityKit", "SwiftUI"],
  entitlements: {
    "com.apple.security.application-groups":
      config.ios.entitlements["com.apple.security.application-groups"],
  },
});
