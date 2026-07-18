import { useRouter } from "expo-router";
import { Fragment } from "react";
import { AppFormSheetScroll } from "@/components/app/app-form-sheet";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import { PickerOption } from "@/features/modes/picker-option";
import {
  AVAILABLE_PRESETS,
  PRESET_DEFINITIONS,
} from "@/features/modes/preset-contracts";

export default function PresetPickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  return (
    <AppFormSheetScroll contentClassName="gap-0">
      <Card className="gap-0 rounded-[20px] border-0 py-0 shadow-none">
        <CardContent className="px-0">
          {AVAILABLE_PRESETS.map((presetKind, index) => {
            const preset = PRESET_DEFINITIONS[presetKind];
            return (
              <Fragment key={presetKind}>
                {index > 0 ? <Separator className="mx-4 w-auto" /> : null}
                <PickerOption
                  detail={preset.defaultDescription}
                  grouped
                  iconKey={preset.suggestedIcon}
                  label={preset.defaultName}
                  onPress={() => {
                    editor.choosePreset(presetKind);
                    router.back();
                  }}
                  selected={editor.draft?.presetKind === presetKind}
                />
              </Fragment>
            );
          })}
          <Separator className="mx-4 w-auto" />
          <PickerOption
            detail="Available when meeting capture and final-transcript processing exist."
            disabled
            grouped
            iconKey="person.3.fill"
            label="Meeting · Coming later"
            selected={false}
          />
        </CardContent>
      </Card>
    </AppFormSheetScroll>
  );
}
