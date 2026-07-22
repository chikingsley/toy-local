import { useRouter } from "expo-router";
import { Fragment } from "react";
import { AppFormSheetScroll } from "@/components/app/app-form-sheet";
import { AppSection } from "@/components/app/app-section";
import { Separator } from "@/components/ui/separator";
import { Text } from "@/components/ui/text";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import {
  modelDisplayName,
  selectedRoute,
  transcriptionModelDetail,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { PickerOption } from "@/features/modes/picker-option";
import { ProviderIcon } from "@/features/modes/provider-icon";
import { useLocalModelPackage } from "@/features/dictation/local-model-package";

export default function ModelPickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  const localPackage = useLocalModelPackage();
  const { catalog } = useModes();
  const groups = [
    {
      models:
        catalog?.transcriptionModels.filter(
          (model) => model.runtime === "cloud",
        ) ?? [],
      title: "Cloud",
    },
    {
      models:
        catalog?.transcriptionModels.filter(
          (model) => model.runtime === "local",
        ) ?? [],
      title: "On device",
    },
  ];
  return (
    <AppFormSheetScroll contentClassName="gap-5">
      {groups.map((group) => (
        <AppSection
          contentClassName="px-0"
          key={group.title}
          title={group.title}
        >
          {group.models.map((model, index) => (
            <Fragment key={model.id}>
              {index > 0 ? <Separator className="mx-4 w-auto" /> : null}
              <PickerOption
                detail={
                  model.runtime === "local"
                    ? localModelDetail(
                        localPackage.status,
                        localPackage.progress,
                      )
                    : transcriptionModelDetail(model)
                }
                grouped
                label={modelDisplayName(model)}
                leading={<ProviderIcon provider={model.provider} />}
                live={Boolean(model.realtime)}
                onPress={() => {
                  if (model.runtime === "local" && !localPackage.ready) {
                    if (localPackage.status !== "downloading") {
                      void localPackage.download();
                    }
                    return;
                  }
                  const realtimeEnabled = Boolean(
                    model.realtime &&
                    ((model.batch && editor.draft?.realtimeEnabled) ||
                      !model.batch),
                  );
                  const route = selectedRoute(model, realtimeEnabled);
                  editor.patch({
                    asrModelId: model.id,
                    identifySpeakers: route?.supportsDiarization
                      ? (editor.draft?.identifySpeakers ?? false)
                      : false,
                    language: route?.supportsAutomaticLanguage
                      ? null
                      : (route?.supportedLanguages[0] ?? null),
                    realtimeEnabled,
                  });
                  router.back();
                }}
                selected={editor.draft?.asrModelId === model.id}
                testID={`model-option-${model.id}`}
              />
            </Fragment>
          ))}
        </AppSection>
      ))}
      <Text className="text-muted-foreground px-1 text-xs leading-4">
        Cloud WER is provider-published: Deepgram uses mixed-domain audio and
        Voxtral uses English FLEURS at 240 ms. Local WER uses FluidAudio
        LibriSpeech test-clean. Results are not directly comparable.
      </Text>
    </AppFormSheetScroll>
  );
}

function localModelDetail(status: string, progress: number) {
  switch (status) {
    case "ready":
      return "On device · Ready";
    case "downloading":
      return `Downloading · ${Math.round(progress * 100)}%`;
    case "error":
      return "Download failed · Tap to retry";
    case "checking":
      return "Checking download…";
    default:
      return "~452 MB · Tap to download";
  }
}
