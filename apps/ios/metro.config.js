const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");

const config = getDefaultConfig(__dirname);

// expo-sqlite's web implementation loads SQLite as WebAssembly. Metro does
// not include wasm in its default asset extensions, so browser previews need
// this explicit entry. Native iOS builds use the native SQLite module.
config.resolver.assetExts.push("wasm");

module.exports = withNativeWind(config, {
  input: "./src/global.css",
  inlineRem: 16,
});
