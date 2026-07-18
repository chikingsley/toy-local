import { render, screen } from "@testing-library/react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { RecordingControl } from "@/components/app/recording-control";
import { Text } from "@/components/ui/text";

describe("foundation components", () => {
  it("provides one shared surface for bottom actions", () => {
    render(
      <SafeAreaProvider
        initialMetrics={{
          frame: { height: 844, width: 390, x: 0, y: 0 },
          insets: { bottom: 34, left: 0, right: 0, top: 47 },
        }}
      >
        <AppBottomActionBar>
          <Text>Primary action</Text>
        </AppBottomActionBar>
      </SafeAreaProvider>,
    );

    expect(screen.getByText("Primary action")).toBeTruthy();
  });

  it.each([
    { label: "Start dictation", stage: "ready" as const, text: "Record" },
    {
      label: "Connecting dictation",
      stage: "connecting" as const,
      text: "Connecting…",
    },
    { label: "Stop dictation", stage: "listening" as const, text: "Stop" },
    {
      label: "Processing dictation",
      stage: "finalizing" as const,
      text: "Processing…",
    },
    {
      label: "Dictation copied",
      stage: "result" as const,
      text: "Copied",
    },
  ])("renders the $text recording control state", ({ label, stage, text }) => {
    render(<RecordingControl onPress={jest.fn()} stage={stage} />);

    expect(screen.getByLabelText(label)).toBeTruthy();
    expect(screen.getByText(text)).toBeTruthy();
  });
});
