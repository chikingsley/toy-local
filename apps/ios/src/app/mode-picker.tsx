import { useRouter } from "expo-router";
import { AppFormSheetScroll } from "@/components/app/app-form-sheet";
import { ModeRow } from "@/features/modes/mode-row";
import { useModes } from "@/features/modes/mode-provider";

export default function ModePickerScreen() {
  const router = useRouter();
  const modes = useModes();
  return (
    <AppFormSheetScroll>
      {modes.modes.map((mode) => (
        <ModeRow
          accessibilityLabel={`Use ${mode.name}`}
          key={mode.id}
          mode={mode}
          onPress={() => {
            void modes.activateMode(mode.id).then(() => router.back());
          }}
        />
      ))}
    </AppFormSheetScroll>
  );
}
