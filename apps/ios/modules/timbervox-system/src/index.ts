import { requireNativeModule, requireNativeView } from "expo";
import type { ComponentType } from "react";
import type { ViewProps } from "react-native";

const NativeShortcutsButton: ComponentType<ViewProps> =
  requireNativeView("TimberVoxSystem");

const TimberVoxSystem = requireNativeModule<{
  acknowledgeNativeResult: (filename: string) => void;
  getKeyboardStatus: () => KeyboardStatus;
  getNativeResultOutbox: () => NativeResultOutboxItem[];
  markKeyboardVerificationRequired: () => void;
  requestNativeSessionStop: () => void;
  startKeyboardStatusObserver: () => void;
}>("TimberVoxSystem");

type KeyboardStatus = {
  fullAccess: boolean;
  keyboardSeen: boolean;
  verificationRequired: boolean;
};

type NativeResultOutboxItem = {
  filename: string;
  json: string;
};

function acknowledgeNativeResult(filename: string) {
  TimberVoxSystem.acknowledgeNativeResult(filename);
}

function getKeyboardStatus() {
  return TimberVoxSystem.getKeyboardStatus();
}

function markKeyboardVerificationRequired() {
  TimberVoxSystem.markKeyboardVerificationRequired();
}

function getNativeResultOutbox() {
  return TimberVoxSystem.getNativeResultOutbox();
}

function requestNativeSessionStop() {
  TimberVoxSystem.requestNativeSessionStop();
}

function startKeyboardStatusObserver() {
  TimberVoxSystem.startKeyboardStatusObserver();
}

export {
  acknowledgeNativeResult,
  getKeyboardStatus,
  getNativeResultOutbox,
  markKeyboardVerificationRequired,
  NativeShortcutsButton,
  requestNativeSessionStop,
  startKeyboardStatusObserver,
};
export type { KeyboardStatus, NativeResultOutboxItem };
