import { useSQLiteContext } from "expo-sqlite";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import {
  deleteStoredDictation,
  loadStoredDictations,
} from "@/features/dictation/dictation-repository";
import { applyAudioRetention } from "@/features/history/history-storage";

export type DictationHistoryItem = {
  audioUri: string | null;
  createdAt: string;
  durationMs: number;
  entryPoint: "app" | "keyboard" | "shortcut";
  id: string;
  language: string | null;
  model: string;
  status: "failed" | "no_speech" | "succeeded";
  text: string;
  wordCount: number;
};

type HistoryValue = {
  items: DictationHistoryItem[];
  reload: () => Promise<void>;
  remove: (item: DictationHistoryItem) => Promise<void>;
};

const HistoryContext = createContext<HistoryValue | null>(null);

export function HistoryProvider({ children }: PropsWithChildren) {
  const database = useSQLiteContext();
  const [items, setItems] = useState<DictationHistoryItem[]>([]);

  const reload = useCallback(async () => {
    setItems(await loadHistory(database));
  }, [database]);

  useEffect(() => {
    let mounted = true;
    void applyAudioRetention(database)
      .then(() => loadHistory(database))
      .then((stored) => {
        if (mounted) setItems(stored);
      });
    return () => {
      mounted = false;
    };
  }, [database]);

  const remove = useCallback(
    async (item: DictationHistoryItem) => {
      await deleteStoredDictation(database, item.id);
      setItems((current) =>
        current.filter((candidate) => candidate.id !== item.id),
      );
    },
    [database],
  );

  const value = useMemo(
    () => ({ items, reload, remove }),
    [items, reload, remove],
  );
  return (
    <HistoryContext.Provider value={value}>{children}</HistoryContext.Provider>
  );
}

export function useHistory() {
  const value = useContext(HistoryContext);
  if (!value) throw new Error("useHistory must be used inside HistoryProvider");
  return value;
}

async function loadHistory(database: ReturnType<typeof useSQLiteContext>) {
  const normalized = await loadStoredDictations(database);
  return normalized.map((row): DictationHistoryItem => ({
    audioUri: row.audioUri,
    createdAt: row.createdAt,
    durationMs: row.durationMs,
    entryPoint: row.entryPoint,
    id: row.id,
    language: row.language,
    model: row.modelId,
    status: row.status,
    text: row.text,
    wordCount: row.wordCount,
  }));
}
