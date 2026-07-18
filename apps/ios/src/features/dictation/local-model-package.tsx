import { SymbolView } from "expo-symbols";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { ActivityIndicator, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { localAsrModule } from "timbervox-local-asr";

import { Text } from "@/components/ui/text";

type PackageStatus = "checking" | "missing" | "downloading" | "ready" | "error";

type LocalModelPackageValue = {
  download: () => Promise<void>;
  downloadedBytes: number;
  error: string | null;
  progress: number;
  ready: boolean;
  refresh: () => Promise<void>;
  remove: () => Promise<void>;
  status: PackageStatus;
};

const LocalModelPackageContext = createContext<LocalModelPackageValue | null>(
  null,
);

function LocalModelPackageProvider({ children }: PropsWithChildren) {
  const [status, setStatus] = useState<PackageStatus>("checking");
  const [progress, setProgress] = useState(0);
  const [downloadedBytes, setDownloadedBytes] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const state = await localAsrModule().getPackageState();
      setDownloadedBytes(state.downloadedBytes);
      setStatus(state.downloaded ? "ready" : "missing");
      setError(null);
    } catch (cause) {
      setStatus("error");
      setError(errorMessage(cause));
    }
  }, []);

  useEffect(() => {
    let active = true;
    void localAsrModule()
      .getPackageState()
      .then((state) => {
        if (!active) return;
        setDownloadedBytes(state.downloadedBytes);
        setStatus(state.downloaded ? "ready" : "missing");
        setError(null);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setStatus("error");
        setError(errorMessage(cause));
      });
    return () => {
      active = false;
    };
  }, []);

  const download = useCallback(async () => {
    setStatus("downloading");
    setProgress(0);
    setError(null);
    const subscription = localAsrModule().addListener(
      "onDownloadProgress",
      (event) => {
        if (typeof event.fraction === "number") {
          setProgress(Math.max(0, Math.min(1, event.fraction)));
        }
      },
    );
    try {
      const state = await localAsrModule().downloadPackage();
      setDownloadedBytes(state.downloadedBytes);
      setProgress(1);
      setStatus("ready");
    } catch (cause) {
      setStatus("error");
      setError(errorMessage(cause));
    } finally {
      subscription.remove();
    }
  }, []);

  const remove = useCallback(async () => {
    try {
      const state = await localAsrModule().deletePackage();
      setDownloadedBytes(state.downloadedBytes);
      setProgress(0);
      setStatus("missing");
      setError(null);
    } catch (cause) {
      setStatus("error");
      setError(errorMessage(cause));
    }
  }, []);

  const value = useMemo<LocalModelPackageValue>(
    () => ({
      download,
      downloadedBytes,
      error,
      progress,
      ready: status === "ready",
      refresh,
      remove,
      status,
    }),
    [download, downloadedBytes, error, progress, refresh, remove, status],
  );

  return (
    <LocalModelPackageContext.Provider value={value}>
      {children}
      {status === "downloading" ? (
        <LocalModelDownloadBanner progress={progress} />
      ) : null}
    </LocalModelPackageContext.Provider>
  );
}

function LocalModelDownloadBanner({ progress }: { progress: number }) {
  const insets = useSafeAreaInsets();
  return (
    <View
      className="bg-card border-border absolute right-4 left-4 z-50 flex-row items-center gap-3 rounded-2xl border px-4 py-3 shadow-lg"
      style={{ top: insets.top + 8 }}
    >
      <ActivityIndicator size="small" />
      <View className="flex-1 gap-1">
        <Text className="font-semibold">Downloading Parakeet Local</Text>
        <View className="bg-muted h-1.5 overflow-hidden rounded-full">
          <View
            className="bg-primary h-full rounded-full"
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </View>
      </View>
      <Text className="text-muted-foreground text-xs tabular-nums">
        {Math.round(progress * 100)}%
      </Text>
      <SymbolView name="iphone" size={17} tintColor="#8d95a2" />
    </View>
  );
}

function useLocalModelPackage() {
  const value = useContext(LocalModelPackageContext);
  if (!value) {
    throw new Error(
      "useLocalModelPackage must be used inside LocalModelPackageProvider",
    );
  }
  return value;
}

function errorMessage(error: unknown) {
  return error instanceof Error
    ? error.message
    : "TimberVox could not manage the local model package.";
}

export { LocalModelPackageProvider, useLocalModelPackage };
