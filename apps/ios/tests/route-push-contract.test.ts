const fs = jest.requireActual("fs") as {
  readFileSync(filePath: string, encoding: string): string;
  readdirSync(
    dirPath: string,
    options: { recursive: true; encoding: "utf8" },
  ): string[];
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
  resolve(...parts: string[]): string;
};

const SOURCE_ROOTS = ["src/app", "src/features", "src/components"];

function sourceFiles(root: string): string[] {
  return fs
    .readdirSync(root, { recursive: true, encoding: "utf8" })
    .filter((entry) => /\.(ts|tsx)$/.test(entry))
    .map((entry) => path.join(root, entry));
}

describe("route push contract", () => {
  const projectRoot = path.resolve(".");

  it("never navigates with a relative href", () => {
    // Relative pushes resolve against the parent of an index route, so
    // "./personal-vocabulary" from /settings lands on Unmatched Route.
    // Every navigation call must use an absolute path.
    const offenders: string[] = [];

    for (const root of SOURCE_ROOTS) {
      for (const file of sourceFiles(path.join(projectRoot, root))) {
        const source = fs.readFileSync(file, "utf8");
        if (/router\.(push|navigate|replace)\(\s*["'`]\.{1,2}\//.test(source)) {
          offenders.push(file);
        }
      }
    }

    expect(offenders).toEqual([]);
  });

  it("routes the personal vocabulary pages through the settings stack", () => {
    const settingsIndex = fs.readFileSync(
      path.join(projectRoot, "src/app/(tabs)/settings/index.tsx"),
      "utf8",
    );
    const vocabularyPage = fs.readFileSync(
      path.join(projectRoot, "src/app/(tabs)/settings/personal-vocabulary.tsx"),
      "utf8",
    );

    expect(settingsIndex).toContain(
      'router.push("/settings/personal-vocabulary")',
    );
    expect(vocabularyPage).toContain(
      'router.push("/settings/personal-vocabulary-add")',
    );
  });
});
