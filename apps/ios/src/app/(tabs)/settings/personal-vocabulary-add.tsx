import { useRouter } from "expo-router";
import { useState } from "react";

import { AppFormSheetScroll } from "@/components/app/app-form-sheet";
import { AppSection } from "@/components/app/app-section";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Text } from "@/components/ui/text";
import { isValidPersonalValue } from "@/features/keyboard/personal-vocabulary-contract";
import {
  addAutomaticPersonalEntry,
  addPinnedPersonalValue,
} from "@/features/keyboard/personal-vocabulary";

export default function AddPersonalVocabularyScreen() {
  const router = useRouter();
  const [value, setValue] = useState("");
  const [validationMessage, setValidationMessage] = useState("");

  const save = (placement: "automatic" | "top") => {
    if (!isValidPersonalValue(value)) {
      setValidationMessage(
        "Enter one word, username, or email address without spaces.",
      );
      return;
    }
    if (placement === "top") addPinnedPersonalValue(value);
    else addAutomaticPersonalEntry(value);
    router.back();
  };

  return (
    <AppFormSheetScroll keyboardShouldPersistTaps="handled">
      <AppSection contentClassName="gap-3 py-4" title="Word or completion">
        <Input
          autoCapitalize="none"
          autoCorrect={false}
          autoFocus
          onChangeText={(nextValue) => {
            setValue(nextValue);
            if (validationMessage) setValidationMessage("");
          }}
          onSubmitEditing={() => save("automatic")}
          placeholder="Nickname, username, or email"
          returnKeyType="done"
          testID="personal-vocabulary-add-input"
          value={value}
        />
        {validationMessage ? (
          <Text className="text-destructive text-xs leading-4">
            {validationMessage}
          </Text>
        ) : (
          <Text className="text-muted-foreground text-xs leading-4">
            Automatic ranking adapts to use. Move to Top keeps this completion
            in the first matching slot.
          </Text>
        )}
      </AppSection>

      <Button
        className="h-12 rounded-2xl"
        disabled={!value.trim()}
        onPress={() => save("automatic")}
        testID="personal-vocabulary-add-automatic"
      >
        <Text className="font-bold">Add Automatically</Text>
      </Button>
      <Button
        className="h-12 rounded-2xl"
        disabled={!value.trim()}
        onPress={() => save("top")}
        testID="personal-vocabulary-add-top"
        variant="secondary"
      >
        <Text className="font-bold">Move to Top</Text>
      </Button>
    </AppFormSheetScroll>
  );
}
