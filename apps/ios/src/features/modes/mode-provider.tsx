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
  fetchModelCatalog,
  selectedTranscriptionModel,
  type ModelCatalog,
} from "@/features/modes/model-catalog";
import {
  createMode,
  deleteMode,
  getMode,
  listModes,
  setActiveMode,
  updateMode,
} from "@/features/modes/mode-repository";
import type { Mode, ModeDraft } from "@/features/modes/mode-types";
import { writeBridgeString } from "@/features/keyboard/app-group-bridge";
import {
  draftsEqual,
  modeToDraft,
  normalizeModeDraft,
} from "@/features/modes/mode-validation";

type ModeContextValue = {
  activateMode: (id: string) => Promise<void>;
  activeMode: Mode | null;
  catalog: ModelCatalog | null;
  catalogError: string | null;
  deleteMode: (id: string, replacementId?: string) => Promise<void>;
  getMode: (id: string) => Promise<Mode | null>;
  loading: boolean;
  modes: Mode[];
  reload: () => Promise<void>;
  saveMode: (draft: ModeDraft) => Promise<Mode>;
};

const ModeContext = createContext<ModeContextValue | null>(null);

function ModeProvider({ children }: PropsWithChildren) {
  const database = useSQLiteContext();
  const [catalog, setCatalog] = useState<ModelCatalog | null>(null);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [modes, setModes] = useState<Mode[]>([]);

  const reload = useCallback(async () => {
    setModes(await listModes(database));
  }, [database]);

  useEffect(() => {
    const controller = new AbortController();
    let mounted = true;

    async function load() {
      setLoading(true);
      const storedModes = await listModes(database);
      if (mounted) setModes(storedModes);
      try {
        const nextCatalog = await fetchModelCatalog(controller.signal);
        for (const mode of storedModes) {
          const currentDraft = modeToDraft(mode);
          const normalized = normalizeModeDraft(currentDraft, nextCatalog);
          if (!draftsEqual(currentDraft, normalized)) {
            await updateMode(database, mode.id, normalized);
          }
        }
        if (!mounted) return;
        setCatalog(nextCatalog);
        setCatalogError(null);
        setModes(await listModes(database));
      } catch (error) {
        if (!mounted || controller.signal.aborted) return;
        setCatalogError(
          error instanceof Error
            ? error.message
            : "The model catalog failed to load.",
        );
      } finally {
        if (mounted) setLoading(false);
      }
    }

    void load();
    return () => {
      mounted = false;
      controller.abort();
    };
  }, [database]);

  const save = useCallback(
    async (draft: ModeDraft) => {
      if (!catalog) throw new Error("Wait for the model catalog to load.");
      const normalized = normalizeModeDraft(draft, catalog);
      const existing = await getMode(database, draft.id);
      const saved = existing
        ? await updateMode(database, draft.id, normalized)
        : await createMode(database, normalized);
      await reload();
      return saved;
    },
    [catalog, database, reload],
  );

  const activate = useCallback(
    async (id: string) => {
      await setActiveMode(database, id);
      await reload();
    },
    [database, reload],
  );

  const remove = useCallback(
    async (id: string, replacementId?: string) => {
      await deleteMode(database, id, replacementId);
      await reload();
    },
    [database, reload],
  );

  const read = useCallback((id: string) => getMode(database, id), [database]);
  const activeMode = modes.find((mode) => mode.isActive) ?? null;
  useEffect(() => {
    if (!activeMode || !catalog) return;
    writeBridgeString("activeModeId", activeMode.id);
    const selected = selectedTranscriptionModel(catalog, activeMode.asrModelId);
    const batchFallback = catalog.transcriptionModels.find(
      (model) => model.runtime === "cloud" && model.batch,
    );
    const batchModel =
      selected?.runtime === "cloud" && selected.batch
        ? selected.batch
        : batchFallback?.batch;
    if (!batchModel) return;
    writeBridgeString(
      "activeModeSnapshot",
      JSON.stringify({
        asrModelId: activeMode.asrModelId,
        batchModelId: batchModel.model,
        description: activeMode.description,
        iconKey: activeMode.iconKey,
        id: activeMode.id,
        identifySpeakers:
          batchModel.supportsDiarization && activeMode.identifySpeakers,
        language: batchModel.supportedLanguages.includes(
          activeMode.language ?? "",
        )
          ? activeMode.language
          : batchModel.supportsAutomaticLanguage
            ? null
            : batchModel.supportedLanguages[0],
        name: activeMode.name,
        presetKind: activeMode.presetKind,
        processingInstructions: activeMode.processingInstructions,
        processingModelId: activeMode.processingModelId,
        realtimeModel:
          selected?.realtime?.model ?? batchFallback?.realtime?.model ?? "",
      }),
    );
  }, [activeMode, catalog]);
  const value = useMemo<ModeContextValue>(
    () => ({
      activateMode: activate,
      activeMode,
      catalog,
      catalogError,
      deleteMode: remove,
      getMode: read,
      loading,
      modes,
      reload,
      saveMode: save,
    }),
    [
      activate,
      activeMode,
      catalog,
      catalogError,
      loading,
      modes,
      read,
      reload,
      remove,
      save,
    ],
  );

  return <ModeContext.Provider value={value}>{children}</ModeContext.Provider>;
}

function useModes() {
  const value = useContext(ModeContext);
  if (!value) throw new Error("useModes must be used inside ModeProvider");
  return value;
}

export { ModeProvider, useModes };
