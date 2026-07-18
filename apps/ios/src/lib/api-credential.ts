import Constants from "expo-constants";

const VOICE_ORIGIN = {
  lab: "https://voice-lab.peacockery.studio",
  production: "https://voice.peacockery.studio",
} as const;

export function configuredApiCredential() {
  const value = Constants.expoConfig?.extra?.peacockeryVoiceApiKey;
  return typeof value === "string" ? value.trim() : "";
}

export function configuredApiOrigin() {
  const environment = Constants.expoConfig?.extra?.peacockeryVoiceEnvironment;
  return environment === "production"
    ? VOICE_ORIGIN.production
    : VOICE_ORIGIN.lab;
}
