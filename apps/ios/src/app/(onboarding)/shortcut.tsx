import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { ScrollView, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { AppSection } from "@/components/app/app-section";
import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { ShortcutsButton } from "@/features/setup/shortcuts-button";
import { useSetupState } from "@/features/setup/setup-state";

export default function ShortcutScreen() {
  const router = useRouter();
  const setup = useSetupState();

  const finish = () => {
    setup.complete();
    router.replace("/record");
  };

  return (
    <SafeAreaView
      className="bg-background flex-1"
      edges={["top", "right", "bottom", "left"]}
    >
      <ScrollView
        className="flex-1"
        contentContainerClassName="grow gap-5 px-[18px] pt-6 pb-[18px]"
      >
        <View className="gap-4">
          <View className="bg-primary size-16 items-center justify-center rounded-[20px]">
            <SymbolView name="square.grid.2x2" size={30} tintColor="#ffffff" />
          </View>
          <View className="gap-2">
            <Text className="text-[32px] font-extrabold">
              Add Toggle TimberVox Dictation
            </Text>
            <Text className="text-muted-foreground text-base leading-6">
              Add the signed TimberVox shortcut, then connect it to Back Tap,
              the Action Button, Siri, or another automation.
            </Text>
          </View>
        </View>

        <AppSection>
          <View className="flex-row items-center gap-3 py-4">
            <View className="bg-primary/15 size-11 items-center justify-center rounded-xl">
              <SymbolView name="waveform" size={22} tintColor="#208AEF" />
            </View>
            <View className="min-w-0 flex-1 gap-1">
              <Text className="font-bold">Toggle TimberVox Dictation</Text>
              <Text className="text-muted-foreground text-sm">
                Runs Record Dictation to start or stop
              </Text>
            </View>
            <View className="flex-row items-center gap-2">
              <View className="bg-success size-2 rounded-full" />
              <Text className="text-success text-sm font-semibold">Signed</Text>
            </View>
          </View>
        </AppSection>

        <View className="gap-2">
          <Text className="text-muted-foreground ml-1.5 text-xs font-extrabold tracking-widest uppercase">
            TimberVox Shortcuts
          </Text>
          <ShortcutsButton className="h-14 w-full" />
        </View>

        <View className="mt-auto gap-2 pt-2">
          <Button
            className="h-14 rounded-2xl"
            onPress={finish}
            testID="finish-setup"
          >
            <Text className="text-base font-bold">Finish setup</Text>
          </Button>
          <Button
            className="h-11"
            onPress={() => router.back()}
            testID="shortcut-back"
            variant="ghost"
          >
            <Text>Back</Text>
          </Button>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
