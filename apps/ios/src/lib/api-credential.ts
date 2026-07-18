import Constants from "expo-constants";

export function configuredApiCredential() {
  const value = Constants.expoConfig?.extra?.timberVoxApiKey;
  return typeof value === "string" ? value.trim() : "";
}
