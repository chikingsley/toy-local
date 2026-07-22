const PERSONAL_VOCABULARY_VERSION = 2;
const MAX_PERSONAL_ENTRIES = 500;

type PersonalVocabularyEntry = {
  lastUsedAt: number;
  pinnedSlot: number | null;
  usageCount: number;
  value: string;
};

type PersonalVocabularyDocument = {
  entries: PersonalVocabularyEntry[];
  version: number;
};

function emptyPersonalVocabulary(): PersonalVocabularyDocument {
  return { entries: [], version: PERSONAL_VOCABULARY_VERSION };
}

function normalizePersonalValue(value: string) {
  return value.trim();
}

function personalValueKey(value: string) {
  return normalizePersonalValue(value).toLocaleLowerCase();
}

function isValidPersonalValue(value: string) {
  const normalized = normalizePersonalValue(value);
  return (
    normalized.length >= 2 &&
    normalized.length <= 254 &&
    /[\p{L}\p{N}]/u.test(normalized) &&
    /^[\p{L}\p{N}'@._+%\-]+$/u.test(normalized)
  );
}

function compareAutomaticEntries(
  left: PersonalVocabularyEntry,
  right: PersonalVocabularyEntry,
) {
  if (left.usageCount !== right.usageCount) {
    return right.usageCount - left.usageCount;
  }
  if (left.lastUsedAt !== right.lastUsedAt) {
    return right.lastUsedAt - left.lastUsedAt;
  }
  return left.value.localeCompare(right.value, undefined, {
    sensitivity: "base",
  });
}

function orderPersonalEntries(entries: PersonalVocabularyEntry[]) {
  if (entries.length < 2) return [...entries];

  const slots: (PersonalVocabularyEntry | undefined)[] = Array.from({
    length: entries.length,
  });
  const pinned = entries
    .filter((entry) => entry.pinnedSlot !== null)
    .sort((left, right) => {
      const slotDifference = (left.pinnedSlot ?? 0) - (right.pinnedSlot ?? 0);
      return slotDifference || compareAutomaticEntries(left, right);
    });

  for (const entry of pinned) {
    let slot = Math.min(entry.pinnedSlot ?? 0, slots.length - 1);
    while (slot < slots.length && slots[slot]) slot += 1;
    if (slot >= slots.length) {
      slot = slots.findLastIndex((candidate) => !candidate);
    }
    if (slot >= 0) slots[slot] = entry;
  }

  const automatic = entries
    .filter((entry) => entry.pinnedSlot === null)
    .sort(compareAutomaticEntries);
  let automaticIndex = 0;
  return slots.map((entry) => entry ?? automatic[automaticIndex++]);
}

function canonicalizePersonalEntries(entries: PersonalVocabularyEntry[]) {
  const pinnedKeys = new Set(
    entries
      .filter((entry) => entry.pinnedSlot !== null)
      .map((entry) => personalValueKey(entry.value)),
  );
  return orderPersonalEntries(entries).map((entry, index) => ({
    ...entry,
    pinnedSlot: pinnedKeys.has(personalValueKey(entry.value)) ? index : null,
  }));
}

function preferredPersonalEntry(
  left: PersonalVocabularyEntry,
  right: PersonalVocabularyEntry,
) {
  if (left.pinnedSlot !== null && right.pinnedSlot === null) return left;
  if (right.pinnedSlot !== null && left.pinnedSlot === null) return right;
  if (left.pinnedSlot !== null && right.pinnedSlot !== null) {
    if (left.pinnedSlot !== right.pinnedSlot) {
      return left.pinnedSlot < right.pinnedSlot ? left : right;
    }
  }
  return compareAutomaticEntries(left, right) <= 0 ? left : right;
}

function parsePersonalVocabulary(json: string): PersonalVocabularyDocument {
  if (!json) return emptyPersonalVocabulary();
  try {
    const parsed = JSON.parse(json) as {
      entries?: unknown[];
      version?: unknown;
    };
    if (!Array.isArray(parsed.entries)) return emptyPersonalVocabulary();
    const entriesByKey = new Map<string, PersonalVocabularyEntry>();
    for (const candidate of parsed.entries) {
      if (!candidate || typeof candidate !== "object") continue;
      const record = candidate as Record<string, unknown>;
      const value =
        typeof record.value === "string"
          ? normalizePersonalValue(record.value)
          : "";
      if (!isValidPersonalValue(value)) continue;
      const pinnedSlotCandidate =
        typeof record.pinnedSlot === "number"
          ? record.pinnedSlot
          : record.manualRank;
      const entry: PersonalVocabularyEntry = {
        lastUsedAt:
          typeof record.lastUsedAt === "number" &&
          Number.isFinite(record.lastUsedAt)
            ? record.lastUsedAt
            : 0,
        pinnedSlot:
          typeof pinnedSlotCandidate === "number" &&
          Number.isInteger(pinnedSlotCandidate) &&
          pinnedSlotCandidate >= 0
            ? pinnedSlotCandidate
            : null,
        usageCount:
          typeof record.usageCount === "number" &&
          Number.isInteger(record.usageCount) &&
          record.usageCount >= 0
            ? record.usageCount
            : 0,
        value,
      };
      const key = personalValueKey(value);
      const current = entriesByKey.get(key);
      entriesByKey.set(
        key,
        current ? preferredPersonalEntry(entry, current) : entry,
      );
    }
    return {
      entries: canonicalizePersonalEntries(
        [...entriesByKey.values()].slice(0, MAX_PERSONAL_ENTRIES),
      ),
      version: PERSONAL_VOCABULARY_VERSION,
    };
  } catch {
    return emptyPersonalVocabulary();
  }
}

function serializePersonalVocabulary(entries: PersonalVocabularyEntry[]) {
  return JSON.stringify({
    entries: canonicalizePersonalEntries(
      entries.slice(0, MAX_PERSONAL_ENTRIES),
    ),
    version: PERSONAL_VOCABULARY_VERSION,
  } satisfies PersonalVocabularyDocument);
}

function placePersonalValue(
  entries: PersonalVocabularyEntry[],
  value: string,
  destinationIndex: number,
) {
  const normalized = normalizePersonalValue(value);
  if (!isValidPersonalValue(normalized)) {
    return canonicalizePersonalEntries(entries);
  }

  const key = personalValueKey(normalized);
  const existing = entries.find(
    (entry) => personalValueKey(entry.value) === key,
  );
  const ordered = orderPersonalEntries(
    existing
      ? entries
      : [
          ...entries,
          {
            lastUsedAt: Date.now() / 1000,
            pinnedSlot: null,
            usageCount: 0,
            value: normalized,
          },
        ],
  );
  const sourceIndex = ordered.findIndex(
    (entry) => personalValueKey(entry.value) === key,
  );
  if (sourceIndex < 0) return canonicalizePersonalEntries(entries);

  const pinnedKeys = new Set(
    entries
      .filter((entry) => entry.pinnedSlot !== null)
      .map((entry) => personalValueKey(entry.value)),
  );
  pinnedKeys.add(key);
  const [selected] = ordered.splice(sourceIndex, 1);
  const destination = Math.max(0, Math.min(destinationIndex, ordered.length));
  ordered.splice(destination, 0, { ...selected, value: normalized });
  return ordered.map((entry, index) => ({
    ...entry,
    pinnedSlot: pinnedKeys.has(personalValueKey(entry.value)) ? index : null,
  }));
}

function pinPersonalValue(entries: PersonalVocabularyEntry[], value: string) {
  return placePersonalValue(entries, value, 0);
}

function addAutomaticPersonalValue(
  entries: PersonalVocabularyEntry[],
  value: string,
) {
  const normalized = normalizePersonalValue(value);
  if (!isValidPersonalValue(normalized)) {
    return canonicalizePersonalEntries(entries);
  }

  const key = personalValueKey(normalized);
  const existing = entries.find(
    (entry) => personalValueKey(entry.value) === key,
  );
  return canonicalizePersonalEntries(
    existing
      ? entries.map((entry) =>
          personalValueKey(entry.value) === key
            ? { ...entry, pinnedSlot: null, value: normalized }
            : entry,
        )
      : [
          ...entries,
          {
            lastUsedAt: Date.now() / 1_000,
            pinnedSlot: null,
            usageCount: 0,
            value: normalized,
          },
        ],
  );
}

function movePersonalValue(
  entries: PersonalVocabularyEntry[],
  value: string,
  destinationIndex: number,
) {
  return placePersonalValue(entries, value, destinationIndex);
}

function resumeAutomaticPersonalValue(
  entries: PersonalVocabularyEntry[],
  value: string,
) {
  const key = personalValueKey(value);
  return canonicalizePersonalEntries(
    entries.map((entry) =>
      personalValueKey(entry.value) === key
        ? { ...entry, pinnedSlot: null }
        : entry,
    ),
  );
}

function removePersonalValue(
  entries: PersonalVocabularyEntry[],
  value: string,
) {
  return canonicalizePersonalEntries(
    entries.filter(
      (entry) => personalValueKey(entry.value) !== personalValueKey(value),
    ),
  );
}

export {
  addAutomaticPersonalValue,
  emptyPersonalVocabulary,
  isValidPersonalValue,
  movePersonalValue,
  orderPersonalEntries,
  parsePersonalVocabulary,
  personalValueKey,
  pinPersonalValue,
  removePersonalValue,
  resumeAutomaticPersonalValue,
  serializePersonalVocabulary,
};
export type { PersonalVocabularyDocument, PersonalVocabularyEntry };
