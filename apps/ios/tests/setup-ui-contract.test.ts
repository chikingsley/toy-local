const fs = jest.requireActual("fs") as {
  readFileSync(filePath: string, encoding: string): string;
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
  resolve(...parts: string[]): string;
};

describe("iPhone setup UI contract", () => {
  const projectRoot = path.resolve(".");

  it("uses a dedicated, scrollable access screen with live keyboard verification", () => {
    const source = fs.readFileSync(
      path.join(projectRoot, "src/app/(onboarding)/welcome.tsx"),
      "utf8",
    );

    expect(source).toContain("<ScrollView");
    expect(source).toContain("automaticallyAdjustKeyboardInsets");
    expect(source).toContain('contentInsetAdjustmentBehavior="automatic"');
    expect(source).toContain('keyboardDismissMode="interactive"');
    expect(source).toContain('contentContainerClassName="grow');
    expect(source).toContain('edges={["top", "right", "bottom", "left"]}');
    expect(source).toContain('testID="keyboard-verification-field"');
    expect(source).toContain('Keyboard.addListener("keyboardDidShow"');
    expect(source).toContain("scrollView.current?.scrollToEnd");
    expect(source).not.toContain("verificationInput.current?.blur()");
    expect(source).toContain("Apps → TimberVox → Keyboards");
    expect(source).toContain('router.push("/shortcut")');
    expect(source).not.toContain('Linking.openURL("shortcuts://")');
  });

  it("opens the installed Apple-signed TimberVox App Shortcut", () => {
    const source = fs.readFileSync(
      path.join(projectRoot, "src/app/(onboarding)/shortcut.tsx"),
      "utf8",
    );
    const buttonSource = fs.readFileSync(
      path.join(projectRoot, "src/features/setup/shortcuts-button.tsx"),
      "utf8",
    );

    expect(source).toContain("<ShortcutsButton");
    expect(source).toContain('contentContainerClassName="grow');
    expect(source).toContain('edges={["top", "right", "bottom", "left"]}');
    expect(source).toContain("Add Toggle TimberVox Dictation");
    expect(buttonSource).toContain("NativeShortcutsButton");
    expect(buttonSource).not.toContain("https://www.icloud.com/shortcuts/");
    expect(buttonSource).not.toContain("Linking.openURL");
  });

  it("refreshes keyboard bridge state while the setup screen is active", () => {
    const source = fs.readFileSync(
      path.join(projectRoot, "src/features/setup/setup-state.ts"),
      "utf8",
    );

    expect(source).toContain("setInterval(refreshBridgeState, 400)");
  });
});
