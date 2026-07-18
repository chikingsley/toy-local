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
    expect(source).toContain('testID="keyboard-verification-field"');
    expect(source).toContain("Apps → TimberVox → Keyboards");
    expect(source).toContain('router.push("/shortcut")');
    expect(source).not.toContain('Linking.openURL("shortcuts://")');
  });

  it("opens the Apple-signed TimberVox shortcut import page", () => {
    const source = fs.readFileSync(
      path.join(projectRoot, "src/app/(onboarding)/shortcut.tsx"),
      "utf8",
    );
    const buttonSource = fs.readFileSync(
      path.join(
        projectRoot,
        "src/features/setup/shortcuts-button.tsx",
      ),
      "utf8",
    );

    expect(source).toContain("<ShortcutsButton");
    expect(source).toContain("Add Toggle TimberVox Dictation");
    expect(buttonSource).toContain("https://www.icloud.com/shortcuts/");
    expect(buttonSource).toContain("Linking.openURL(TIMBERVOX_SHORTCUT_URL)");
    expect(buttonSource).toContain("Add Shortcut");
  });

  it("refreshes keyboard bridge state while the setup screen is active", () => {
    const source = fs.readFileSync(
      path.join(projectRoot, "src/features/setup/setup-state.ts"),
      "utf8",
    );

    expect(source).toContain("setInterval(refreshBridgeState, 400)");
  });
});
