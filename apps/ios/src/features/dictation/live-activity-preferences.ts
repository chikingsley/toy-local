import { useCallback, useState } from "react";

import {
  initializeAppGroupBridge,
  readBridgeString,
  writeBridgeString,
} from "@/features/keyboard/app-group-bridge";

type LiveActivityDisplayMode = "waveform" | "words";

function useLiveActivityPreferences() {
  initializeAppGroupBridge();
  const [displayMode, setDisplayModeState] = useState(readDisplayMode);

  const setDisplayMode = useCallback((value: LiveActivityDisplayMode) => {
    writeBridgeString("liveActivityDisplayMode", value);
    setDisplayModeState(value);
  }, []);

  return { displayMode, setDisplayMode };
}

function readDisplayMode(): LiveActivityDisplayMode {
  return readBridgeString("liveActivityDisplayMode") === "words"
    ? "words"
    : "waveform";
}

export { useLiveActivityPreferences };
export type { LiveActivityDisplayMode };
