import {
  addAutomaticPersonalValue,
  movePersonalValue,
  parsePersonalVocabulary,
  pinPersonalValue,
  removePersonalValue,
  resumeAutomaticPersonalValue,
  serializePersonalVocabulary,
  type PersonalVocabularyEntry,
} from "@/features/keyboard/personal-vocabulary-contract";

const learnedEntries: PersonalVocabularyEntry[] = [
  {
    lastUsedAt: 20,
    pinnedSlot: null,
    usageCount: 6,
    value: "Chibuzor",
  },
  {
    lastUsedAt: 10,
    pinnedSlot: null,
    usageCount: 2,
    value: "chikingsley",
  },
];

describe("personal vocabulary contract", () => {
  it("adds a new value to automatic ranking", () => {
    const entries = addAutomaticPersonalValue(learnedEntries, "Ejimofor");

    expect(entries.map((entry) => entry.value)).toEqual([
      "Chibuzor",
      "chikingsley",
      "Ejimofor",
    ]);
    expect(entries[2]).toMatchObject({ pinnedSlot: null, usageCount: 0 });
  });

  it("resumes automatic ranking when an existing value is added automatically", () => {
    const pinned = pinPersonalValue(learnedEntries, "chikingsley");
    const entries = addAutomaticPersonalValue(pinned, "chikingsley");

    expect(entries.map((entry) => entry.value)).toEqual([
      "Chibuzor",
      "chikingsley",
    ]);
    expect(entries[1]).toMatchObject({ pinnedSlot: null, usageCount: 2 });
  });

  it("pins an email first without discarding learned counts", () => {
    const entries = pinPersonalValue(
      learnedEntries,
      "chibuzor.ejimofor@gmail.com",
    );

    expect(entries.map((entry) => entry.value)).toEqual([
      "chibuzor.ejimofor@gmail.com",
      "Chibuzor",
      "chikingsley",
    ]);
    expect(entries.map((entry) => entry.pinnedSlot)).toEqual([0, null, null]);
    expect(entries[1].usageCount).toBe(6);
  });

  it("pins only the moved result and leaves automatic ranking active", () => {
    const entries = movePersonalValue(learnedEntries, "chikingsley", 0);

    expect(entries.map((entry) => entry.value)).toEqual([
      "chikingsley",
      "Chibuzor",
    ]);
    expect(entries.map((entry) => entry.pinnedSlot)).toEqual([0, null]);
  });

  it("keeps a fixed slot while automatic entries rank in the gaps", () => {
    const entries = movePersonalValue(
      [
        ...learnedEntries,
        {
          lastUsedAt: 30,
          pinnedSlot: null,
          usageCount: 10,
          value: "Ejimofor",
        },
      ],
      "chikingsley",
      1,
    );

    expect(entries.map((entry) => entry.value)).toEqual([
      "Ejimofor",
      "chikingsley",
      "Chibuzor",
    ]);
    expect(entries.map((entry) => entry.pinnedSlot)).toEqual([null, 1, null]);
  });

  it("resumes automatic ranking using the retained usage count", () => {
    const pinned = movePersonalValue(learnedEntries, "chikingsley", 0);
    const entries = resumeAutomaticPersonalValue(pinned, "chikingsley");

    expect(entries.map((entry) => entry.value)).toEqual([
      "Chibuzor",
      "chikingsley",
    ]);
    expect(entries.map((entry) => entry.pinnedSlot)).toEqual([null, null]);
    expect(entries[1].usageCount).toBe(2);
  });

  it("migrates legacy manual ranks into fixed pinned slots", () => {
    const document = parsePersonalVocabulary(
      JSON.stringify({
        entries: [
          { ...learnedEntries[0], manualRank: 1, pinnedSlot: undefined },
          { ...learnedEntries[1], manualRank: null, pinnedSlot: undefined },
        ],
        version: 1,
      }),
    );

    expect(document.version).toBe(2);
    expect(document.entries.map((entry) => entry.value)).toEqual([
      "chikingsley",
      "Chibuzor",
    ]);
    expect(document.entries.map((entry) => entry.pinnedSlot)).toEqual([
      null,
      1,
    ]);
  });

  it("round-trips valid entries and rejects malformed values", () => {
    const json = serializePersonalVocabulary([
      ...learnedEntries,
      {
        lastUsedAt: 0,
        pinnedSlot: 0,
        usageCount: 0,
        value: "Chi",
      },
    ]);
    const document = parsePersonalVocabulary(json);

    expect(document.entries[0].value).toBe("Chi");
    expect(
      parsePersonalVocabulary(
        JSON.stringify({
          entries: [{ value: "two words", usageCount: 1 }],
          version: 2,
        }),
      ).entries,
    ).toEqual([]);
  });

  it("forgets one personal value case-insensitively", () => {
    expect(removePersonalValue(learnedEntries, "CHIBUZOR")).toEqual([
      learnedEntries[1],
    ]);
  });
});
