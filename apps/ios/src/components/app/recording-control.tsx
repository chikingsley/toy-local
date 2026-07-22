import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import type { DictationStage } from "@/features/dictation/dictation-types";
import { SymbolView } from "expo-symbols";
import { ActivityIndicator } from "react-native";

type RecordingControlProps = {
  disabled?: boolean;
  onPress: () => void;
  stage: DictationStage;
};

function RecordingControl({
  disabled = false,
  onPress,
  stage,
}: RecordingControlProps) {
  const presentation = recordingControlPresentation(stage);

  return (
    <Button
      accessibilityLabel={presentation.accessibilityLabel}
      className="h-14 w-full rounded-2xl"
      disabled={disabled || presentation.disabled}
      onPress={onPress}
      testID="recording-control"
      variant={presentation.variant}
    >
      {presentation.busy ? (
        <ActivityIndicator
          color={stage === "connecting" ? "#261500" : "#281334"}
          size="small"
        />
      ) : (
        <SymbolView
          name={presentation.icon}
          size={24}
          tintColor={stage === "result" ? "#092214" : "#ffffff"}
        />
      )}
      <Text className="text-base font-bold">{presentation.label}</Text>
    </Button>
  );
}

function recordingControlPresentation(stage: DictationStage) {
  switch (stage) {
    case "connecting":
      return {
        accessibilityLabel: "Connecting dictation",
        busy: true,
        disabled: false,
        icon: "ellipsis" as const,
        label: "Connecting…",
        variant: "connecting" as const,
      };
    case "listening":
      return {
        accessibilityLabel: "Stop dictation",
        busy: false,
        disabled: false,
        icon: "stop.fill" as const,
        label: "Stop",
        variant: "destructive" as const,
      };
    case "finalizing":
      return {
        accessibilityLabel: "Processing dictation",
        busy: true,
        disabled: true,
        icon: "ellipsis" as const,
        label: "Processing…",
        variant: "processing" as const,
      };
    case "result":
      return {
        accessibilityLabel: "Dictation copied",
        busy: false,
        disabled: true,
        icon: "checkmark" as const,
        label: "Copied",
        variant: "success" as const,
      };
    case "error":
    case "idle":
    case "ready":
      return {
        accessibilityLabel: "Start dictation",
        busy: false,
        disabled: false,
        icon: "mic.fill" as const,
        label: "Record",
        variant: "default" as const,
      };
  }
}

export { RecordingControl, recordingControlPresentation };
