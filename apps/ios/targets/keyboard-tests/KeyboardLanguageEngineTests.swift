import Foundation
import XCTest

@testable import TimberVoxSwipeDecoder

@MainActor
final class KeyboardLanguageEngineTests: XCTestCase {
  func testLearnedProperNamesBecomeSwipeCandidatesWithPreferredCasing() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let engine = fixture.engine

    engine.learn(word: "Chibuzor", after: "is", atSentenceStart: false)
    engine.learn(word: "Ejimofor", after: "chibuzor", atSentenceStart: false)
    engine.learn(word: "Kingsley", after: "ejimofor", atSentenceStart: false)

    let chibuzor = engine.swipeVocabulary(first: "c", last: "r", previousWord: "is")
      .first(where: { $0.word == "chibuzor" })
    XCTAssertNotNil(chibuzor)
    XCTAssertGreaterThan(chibuzor?.frequency ?? 0, 1_000_000)
    XCTAssertTrue(
      engine.swipeVocabulary(first: "e", last: "r", previousWord: "chibuzor")
        .contains(where: { $0.word == "ejimofor" })
    )
    XCTAssertTrue(
      engine.swipeVocabulary(first: "k", last: "y", previousWord: "ejimofor")
        .contains(where: { $0.word == "kingsley" })
    )
    engine.learn(word: "Chi", after: "call", atSentenceStart: false)
    XCTAssertEqual(engine.predictions(textBeforeCursor: "Chi").first, "Chi")
    XCTAssertEqual(engine.predictions(textBeforeCursor: "Chib").first, "Chibuzor")
    XCTAssertEqual(engine.predictions(textBeforeCursor: "Chibuzor ").first, "Ejimofor")
  }

  func testEmailAndUsernameWaitForStrongerPrefixes() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let engine = fixture.engine

    engine.learn(
      word: "chibuzor.ejimofor@gmail.com",
      after: nil,
      atSentenceStart: false
    )
    engine.learn(word: "chikingsley", after: nil, atSentenceStart: false)

    XCTAssertFalse(
      engine.predictions(textBeforeCursor: "Chi")
        .contains("chibuzor.ejimofor@gmail.com")
    )
    XCTAssertTrue(
      engine.predictions(textBeforeCursor: "chibu")
        .contains("chibuzor.ejimofor@gmail.com")
    )
    XCTAssertTrue(engine.predictions(textBeforeCursor: "chik").contains("chikingsley"))
    XCTAssertEqual(
      KeyboardContext(textBeforeCursor: "Email chibuzor.ej").currentCompletionText,
      "chibuzor.ej"
    )
  }

  func testPinnedSlotsAnchorMatchingPersonalValuesAroundAutomaticUsage() throws {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let document = KeyboardPersonalVocabularyDocument(entries: [
      KeyboardPersonalVocabularyEntry(
        value: "Chibuzor",
        usageCount: 50,
        pinnedSlot: 1
      ),
      KeyboardPersonalVocabularyEntry(
        value: "chibuzor.ejimofor@gmail.com",
        usageCount: 1,
        pinnedSlot: 0
      ),
    ])
    let data = try JSONEncoder().encode(document)
    fixture.defaults.set(
      String(decoding: data, as: UTF8.self),
      forKey: KeyboardLanguageEngine.personalVocabularyKey
    )
    fixture.defaults.set(1, forKey: KeyboardLanguageEngine.personalVocabularyRevisionKey)
    let engine = makeEngine(defaults: fixture.defaults)

    XCTAssertEqual(
      engine.predictions(textBeforeCursor: "Chib").first,
      "chibuzor.ejimofor@gmail.com"
    )
  }

  func testPinnedSlotLeavesAutomaticEntriesRankedInTheGaps() {
    let ranked = KeyboardLanguageEngine.rankedPersonalEntries([
      KeyboardPersonalVocabularyEntry(value: "Chibuzor", usageCount: 6),
      KeyboardPersonalVocabularyEntry(
        value: "chikingsley",
        usageCount: 2,
        pinnedSlot: 1
      ),
      KeyboardPersonalVocabularyEntry(value: "Ejimofor", usageCount: 10),
    ])

    XCTAssertEqual(ranked.map(\.value), ["Ejimofor", "chikingsley", "Chibuzor"])
  }

  func testLegacyManualRankDecodesAsPinnedSlot() throws {
    let data = Data(
      #"{"lastUsedAt":0,"manualRank":2,"usageCount":4,"value":"Chibuzor"}"#.utf8
    )

    let entry = try JSONDecoder().decode(KeyboardPersonalVocabularyEntry.self, from: data)

    XCTAssertEqual(entry.pinnedSlot, 2)
    let encoded = String(decoding: try JSONEncoder().encode(entry), as: UTF8.self)
    XCTAssertTrue(encoded.contains("pinnedSlot"))
    XCTAssertFalse(encoded.contains("manualRank"))
  }

  func testLearnedVocabularyAndPreferredCasingPersist() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    var engine = fixture.engine
    engine.learn(word: "Chibuzor", after: nil, atSentenceStart: true)
    engine.flushPendingLearning()

    engine = makeEngine(defaults: fixture.defaults)

    XCTAssertEqual(engine.displayForm(for: "chibuzor", capitalized: false), "Chibuzor")
    XCTAssertTrue(
      engine.swipeVocabulary(first: "c", last: "r", previousWord: nil)
        .contains(where: { $0.word == "chibuzor" })
    )
  }

  func testDuplicateBaseVocabularyEntriesKeepTheFirstOccurrence() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let engine = KeyboardLanguageEngine(
      defaults: fixture.defaults,
      vocabulary: [
        SwipeVocabularyEntry(frequency: 1_000_000, word: "cheap"),
        SwipeVocabularyEntry(frequency: 500, word: "cheap"),
      ]
    )

    let entries = engine.swipeVocabulary(first: "c", last: "p", previousWord: nil)
      .filter { $0.word == "cheap" }

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.frequency, 1_000_000)
  }

  func testSupplementaryWordsJoinSwipeVocabularyWithoutTraining() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let engine = fixture.engine

    engine.addSupplementaryWords(["Ejimofor"])

    XCTAssertEqual(engine.displayForm(for: "ejimofor", capitalized: false), "Ejimofor")
    XCTAssertTrue(
      engine.swipeVocabulary(first: "e", last: "r", previousWord: nil)
        .contains(where: { $0.word == "ejimofor" })
    )
  }

  func testSentenceCapitalizationDoesNotPermanentlyCapitalizeBaseWords() {
    let fixture = makeFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let engine = fixture.engine

    engine.learn(word: "The", after: nil, atSentenceStart: true)

    XCTAssertEqual(engine.displayForm(for: "the", capitalized: false), "the")
    XCTAssertEqual(engine.displayForm(for: "the", capitalized: true), "The")
  }

  private func makeFixture() -> (
    defaults: UserDefaults,
    engine: KeyboardLanguageEngine,
    suiteName: String
  ) {
    let suiteName = "KeyboardLanguageEngineTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, makeEngine(defaults: defaults), suiteName)
  }

  private func makeEngine(defaults: UserDefaults) -> KeyboardLanguageEngine {
    KeyboardLanguageEngine(
      defaults: defaults,
      vocabulary: [
        SwipeVocabularyEntry(frequency: 1_000_000, word: "cheap"),
        SwipeVocabularyEntry(frequency: 2_000_000, word: "the"),
      ]
    )
  }
}
