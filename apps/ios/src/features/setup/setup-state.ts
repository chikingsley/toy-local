import { getRecordingPermissionsAsync } from "expo-audio";
import * as Linking from "expo-linking";
import { useCallback, useEffect, useState } from "react";
import { AppState } from "react-native";

import {
  initializeAppGroupBridge,
  readBridgeBoolean,
  writeBridgeBoolean,
} from "@/features/keyboard/app-group-bridge";
import {
  getKeyboardStatus,
  markKeyboardVerificationRequired,
  startKeyboardStatusObserver,
  type KeyboardStatus,
} from "timbervox-system";

export type SetupState = {
  completed: boolean;
  fullAccessVerified: boolean;
  keyboardEnabled: boolean;
  keyboardVerified: boolean;
  keyboardVerificationPending: boolean;
  microphoneGranted: boolean;
  shortcutAvailable: boolean;
};

export function useSetupState() {
  initializeAppGroupBridge();
  startKeyboardStatusObserver();
  const [state, setState] = useState<SetupState>(() => readSetupState(false));
  const refreshBridgeState = useCallback(() => {
    setState((current) => {
      const next = readSetupState(current.microphoneGranted, getKeyboardStatus());
      // The poll runs forever; keep the previous object identity when nothing
      // changed so consumers do not re-render at the poll frequency.
      return setupStatesEqual(current, next) ? current : next;
    });
  }, []);
  const refresh = useCallback(async () => {
    const microphone = await getRecordingPermissionsAsync();
    setState((current) => {
      const next = readSetupState(microphone.granted, getKeyboardStatus());
      return setupStatesEqual(current, next) ? current : next;
    });
  }, []);

  useEffect(() => {
    let mounted = true;
    void getRecordingPermissionsAsync().then((microphone) => {
      if (mounted) {
        setState(readSetupState(microphone.granted, getKeyboardStatus()));
      }
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
    // iOS exposes these values only to the running keyboard extension. Keep
    // the last verified values in storage, but require a fresh extension
    // observation after Settings before presenting them as current.
    markKeyboardVerificationRequired();
    setState((current) => ({
      ...current,
      keyboardVerificationPending: true,
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

function setupStatesEqual(left: SetupState, right: SetupState) {
  return (
    left.completed === right.completed &&
    left.fullAccessVerified === right.fullAccessVerified &&
    left.keyboardEnabled === right.keyboardEnabled &&
    left.keyboardVerified === right.keyboardVerified &&
    left.keyboardVerificationPending === right.keyboardVerificationPending &&
    left.microphoneGranted === right.microphoneGranted &&
    left.shortcutAvailable === right.shortcutAvailable
  );
}

function readSetupState(
  microphoneGranted: boolean,
  keyboardStatus?: KeyboardStatus,
): SetupState {
  const keyboardEnabled =
    keyboardStatus?.keyboardSeen ?? readBridgeBoolean("keyboardSeen");
  const fullAccessVerified =
    keyboardStatus?.fullAccess ?? readBridgeBoolean("keyboardHasFullAccess");
  const keyboardVerificationPending =
    keyboardStatus?.verificationRequired ??
    readBridgeBoolean("keyboardVerificationRequired");
  return {
    completed: readBridgeBoolean("onboardingComplete"),
    fullAccessVerified,
    keyboardEnabled,
    keyboardVerificationPending,
    keyboardVerified:
      !keyboardVerificationPending && keyboardEnabled && fullAccessVerified,
    microphoneGranted,
    shortcutAvailable: readBridgeBoolean("shortcutAvailable"),
  };
}
