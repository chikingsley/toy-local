import {
  readBridgeNumber,
  readBridgeString,
  writeBridgeNumber,
  writeBridgeString,
} from "@/features/keyboard/app-group-bridge";
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

function readPersonalVocabulary() {
  return parsePersonalVocabulary(readBridgeString("keyboardPersonalVocabulary"))
    .entries;
}

function writePersonalVocabulary(entries: PersonalVocabularyEntry[]) {
  writeBridgeString(
    "keyboardPersonalVocabulary",
    serializePersonalVocabulary(entries),
  );
  writeBridgeNumber(
    "keyboardPersonalVocabularyRevision",
    readBridgeNumber("keyboardPersonalVocabularyRevision") + 1,
  );
  return entries;
}

function addPinnedPersonalValue(value: string) {
  return writePersonalVocabulary(
    pinPersonalValue(readPersonalVocabulary(), value),
  );
}

function addAutomaticPersonalEntry(value: string) {
  return writePersonalVocabulary(
    addAutomaticPersonalValue(readPersonalVocabulary(), value),
  );
}

function movePersonalEntry(value: string, destinationIndex: number) {
  return writePersonalVocabulary(
    movePersonalValue(readPersonalVocabulary(), value, destinationIndex),
  );
}

function resumeAutomaticPersonalEntry(value: string) {
  return writePersonalVocabulary(
    resumeAutomaticPersonalValue(readPersonalVocabulary(), value),
  );
}

function removePersonalEntry(value: string) {
  return writePersonalVocabulary(
    removePersonalValue(readPersonalVocabulary(), value),
  );
}

export {
  addAutomaticPersonalEntry,
  addPinnedPersonalValue,
  movePersonalEntry,
  readPersonalVocabulary,
  removePersonalEntry,
  resumeAutomaticPersonalEntry,
};
