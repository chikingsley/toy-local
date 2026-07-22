/** @type {import('jest').Config} */
module.exports = {
  moduleNameMapper: {
    "^@chikingsley/peacockery-voice-client$":
      "<rootDir>/node_modules/@chikingsley/peacockery-voice-client/dist/index.js",
  },
  preset: "jest-expo",
  testMatch: ["<rootDir>/tests/**/*.test.{ts,tsx}"],
  transformIgnorePatterns: [
    "node_modules/(?!(.pnpm|@chikingsley/peacockery-voice-client|(jest-)?react-native|@react-native(-community)?|@rn-primitives/.*|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|standard-navigation|@sentry/react-native|native-base|react-native-svg))",
  ],
};
