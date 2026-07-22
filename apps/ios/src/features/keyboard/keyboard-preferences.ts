import { useCallback, useState } from "react";

import {
  initializeAppGroupBridge,
  readBridgeBoolean,
  writeBridgeBoolean,
  type BridgeKey,
} from "@/features/keyboard/app-group-bridge";

type KeyboardPreferenceKey =
  | "keyboardHapticsEnabled"
  | "keyboardAutocorrectEnabled"
  | "keyboardPredictionsEnabled"
  | "keyboardSoundEnabled"
  | "keyboardSwipeEnabled"
  | "streamingInsertionEnabled";

type KeyboardPreferences = {
  autocorrect: boolean;
  haptics: boolean;
  predictions: boolean;
  sound: boolean;
  streamingInsertion: boolean;
  swipe: boolean;
};

function useKeyboardPreferences() {
  initializeAppGroupBridge();
  const [preferences, setPreferences] = useState(readPreferences);

  const update = useCallback(
    (key: keyof KeyboardPreferences, value: boolean) => {
      writeBridgeBoolean(preferenceBridgeKey(key), value);
      setPreferences((current) => ({ ...current, [key]: value }));
    },
    [],
  );

  return { preferences, update };
}

function readPreferences(): KeyboardPreferences {
  return {
    autocorrect: readBridgeBoolean("keyboardAutocorrectEnabled"),
    haptics: readBridgeBoolean("keyboardHapticsEnabled"),
    predictions: readBridgeBoolean("keyboardPredictionsEnabled"),
    sound: readBridgeBoolean("keyboardSoundEnabled"),
    streamingInsertion: readBridgeBoolean("streamingInsertionEnabled"),
    swipe: readBridgeBoolean("keyboardSwipeEnabled"),
  };
}

function preferenceBridgeKey(
  key: keyof KeyboardPreferences,
): KeyboardPreferenceKey & BridgeKey {
  switch (key) {
    case "autocorrect":
      return "keyboardAutocorrectEnabled";
    case "haptics":
      return "keyboardHapticsEnabled";
    case "predictions":
      return "keyboardPredictionsEnabled";
    case "sound":
      return "keyboardSoundEnabled";
    case "streamingInsertion":
      return "streamingInsertionEnabled";
    case "swipe":
      return "keyboardSwipeEnabled";
  }
}

export { useKeyboardPreferences };
export type { KeyboardPreferences };
