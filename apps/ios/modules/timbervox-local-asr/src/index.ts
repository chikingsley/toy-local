import { requireNativeModule } from "expo";

type LocalPackageState = {
  downloaded: boolean;
  downloadedBytes: number;
};

type LocalAsrNativeModule = {
  addListener: (
    event: "onDownloadProgress" | "onPartialTranscript",
    listener: (event: Record<string, unknown>) => void,
  ) => { remove: () => void };
  cancelRealtime: () => Promise<void>;
  deletePackage: () => Promise<LocalPackageState>;
  downloadPackage: () => Promise<LocalPackageState>;
  finishRealtime: () => Promise<string>;
  getPackageState: () => Promise<LocalPackageState>;
  sendRealtimeAudio: (audio: Uint8Array) => Promise<void>;
  startRealtime: () => Promise<void>;
  transcribeBatch: (audio: Uint8Array) => Promise<string>;
};

let cachedModule: LocalAsrNativeModule | null = null;

function localAsrModule() {
  cachedModule ??= requireNativeModule<LocalAsrNativeModule>(
    "TimberVoxLocalAsr",
  );
  return cachedModule;
}

export { localAsrModule };
export type { LocalAsrNativeModule, LocalPackageState };
