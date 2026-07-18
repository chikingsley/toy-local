import { getRecordingPermissionsAsync } from "expo-audio";
import * as Linking from "expo-linking";
import { useCallback, useEffect, useState } from "react";
import { AppState } from "react-native";

import {
  initializeAppGroupBridge,
  readBridgeBoolean,
  writeBridgeBoolean,
} from "@/features/keyboard/app-group-bridge";

export type SetupState = {
  completed: boolean;
  fullAccessVerified: boolean;
  keyboardEnabled: boolean;
  keyboardVerified: boolean;
  microphoneGranted: boolean;
  shortcutAvailable: boolean;
};

export function useSetupState() {
  initializeAppGroupBridge();
  const [state, setState] = useState<SetupState>(() => readSetupState(false));
  const refreshBridgeState = useCallback(() => {
    setState((current) => readSetupState(current.microphoneGranted));
  }, []);
  const refresh = useCallback(async () => {
    const microphone = await getRecordingPermissionsAsync();
    setState(readSetupState(microphone.granted));
  }, []);

  useEffect(() => {
    let mounted = true;
    void getRecordingPermissionsAsync().then((microphone) => {
      if (mounted) setState(readSetupState(microphone.granted));
    });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState === "active") void refresh();
    });
    return () => subscription.remove();
  }, [refresh]);

  useEffect(() => {
    const interval = setInterval(refreshBridgeState, 400);
    return () => clearInterval(interval);
  }, [refreshBridgeState]);

  const complete = useCallback(() => {
    writeBridgeBoolean("onboardingComplete", true);
    setState((current) => ({ ...current, completed: true }));
  }, []);

  const restart = useCallback(() => {
    writeBridgeBoolean("onboardingComplete", false);
    setState((current) => ({ ...current, completed: false }));
  }, []);

  const openKeyboardSettings = useCallback(() => {
    // iOS exposes keyboard enablement and Full Access only to the running
    // keyboard extension. Invalidate the extension's last observation before
    // opening Settings so the containing app never presents stale access as
    // current. The keyboard republishes both values the next time it appears.
    writeBridgeBoolean("keyboardSeen", false);
    writeBridgeBoolean("keyboardHasFullAccess", false);
    setState((current) => ({
      ...current,
      fullAccessVerified: false,
      keyboardEnabled: false,
      keyboardVerified: false,
    }));
    return Linking.openSettings();
  }, []);

  return {
    ...state,
    complete,
    openKeyboardSettings,
    openSettings: () => Linking.openSettings(),
    refresh,
    refreshBridgeState,
    restart,
  };
}

function readSetupState(microphoneGranted: boolean): SetupState {
  const keyboardEnabled = readBridgeBoolean("keyboardSeen");
  const fullAccessVerified = readBridgeBoolean("keyboardHasFullAccess");
  return {
    completed: readBridgeBoolean("onboardingComplete"),
    fullAccessVerified,
    keyboardEnabled,
    keyboardVerified: keyboardEnabled && fullAccessVerified,
    microphoneGranted,
    shortcutAvailable: readBridgeBoolean("shortcutAvailable"),
  };
}
