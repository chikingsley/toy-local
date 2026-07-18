import { ExtensionStorage } from "@bacons/apple-targets";

const APP_GROUP = "group.com.chiejimofor.timbervox";
const BRIDGE_SCHEMA_VERSION = 3;
const storage = new ExtensionStorage(APP_GROUP);

const bridgeKeys = [
  "bridgeSchemaVersion",
  "keyboardSeen",
  "keyboardHasFullAccess",
  "shortcutAvailable",
  "activeModeId",
  "keyboardHapticsEnabled",
  "keyboardSoundEnabled",
  "keyboardPredictionsEnabled",
  "keyboardAutocorrectEnabled",
  "keyboardSwipeEnabled",
  "onboardingComplete",
  "apiBaseURL",
  "apiCredential",
  "activeModeSnapshot",
  "sessionActive",
  "recordingRequested",
  "requestRevision",
  "requestedEntryPoint",
  "activeRequestId",
  "keyboardRequestId",
  "partialTranscript",
  "finalResultId",
  "finalRequestId",
  "finalTranscript",
  "transcriptRevision",
  "consumedResultId",
  "nativeResultEnvelope",
  "nativeResultRevision",
  "nativeResultConsumedRevision",
] as const;

type BridgeKey = (typeof bridgeKeys)[number];

function initializeAppGroupBridge() {
  // App Shortcuts ship with the installed app and are immediately available.
  // This flag represents that capability, not whether the user has run it yet.
  writeBridgeBoolean("shortcutAvailable", true);
  if (readBridgeNumber("bridgeSchemaVersion") >= BRIDGE_SCHEMA_VERSION) return;
  // V1 results had no request ownership, so promoting one could paste stale text.
  storage.remove("pendingTranscript");
  storage.remove("finalResultId");
  storage.remove("finalRequestId");
  storage.remove("finalTranscript");
  storage.remove("consumedResultId");
  writeBridgeNumber("bridgeSchemaVersion", BRIDGE_SCHEMA_VERSION);
  seedBoolean("keyboardHapticsEnabled", true);
  seedBoolean("keyboardSoundEnabled", true);
  seedBoolean("keyboardPredictionsEnabled", true);
  seedBoolean("keyboardAutocorrectEnabled", true);
  seedBoolean("keyboardSwipeEnabled", true);
}

function readBridgeBoolean(key: BridgeKey) {
  return normalizeBridgeBoolean(storage.get(key));
}

function normalizeBridgeBoolean(value: unknown) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value > 0;
  if (typeof value !== "string") return false;
  const normalized = value.trim().toLowerCase();
  return normalized === "true" || normalized === "yes" || normalized === "1";
}

function readBridgeNumber(key: BridgeKey) {
  return normalizeBridgeNumber(storage.get(key));
}

function normalizeBridgeNumber(value: unknown) {
  if (value === true || value === "true" || value === "yes") return 1;
  if (value === false || value === "false" || value === "no") return 0;
  const number = Number(value ?? 0);
  return Number.isFinite(number) ? number : 0;
}

function readBridgeString(key: BridgeKey) {
  const value = storage.get(key);
  return typeof value === "string" ? value : "";
}

function writeBridgeBoolean(key: BridgeKey, value: boolean) {
  storage.set(key, value ? 1 : 0);
}

function writeBridgeNumber(key: BridgeKey, value: number) {
  storage.set(key, value);
}

function writeBridgeString(key: BridgeKey, value: string) {
  storage.set(key, value);
}

function removeBridgeValue(key: BridgeKey) {
  storage.remove(key);
}

function seedBoolean(key: BridgeKey, value: boolean) {
  if (storage.get(key) === null || storage.get(key) === undefined) {
    writeBridgeBoolean(key, value);
  }
}

export {
  APP_GROUP,
  BRIDGE_SCHEMA_VERSION,
  bridgeKeys,
  initializeAppGroupBridge,
  normalizeBridgeBoolean,
  normalizeBridgeNumber,
  readBridgeBoolean,
  readBridgeNumber,
  readBridgeString,
  removeBridgeValue,
  writeBridgeBoolean,
  writeBridgeNumber,
  writeBridgeString,
};
export type { BridgeKey };
