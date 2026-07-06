import Foundation
import Testing

@testable import TimberVoxCore

@Suite struct TranscriptStoreTests {
  private static let referenceDate = Date(timeIntervalSince1970: 1_782_500_000)

  private func makeRecord(
    id: String = UUID().uuidString,
    createdAt: Date = referenceDate,
    rawText: String = "raw transcript text",
    finalText: String = "final transcript text"
  ) -> TranscriptRecord {
    TranscriptRecord(
      id: id,
      createdAt: createdAt,
      duration: 4.2,
      rawText: rawText,
      finalText: finalText,
      sourceAppBundleID: "com.apple.dt.Xcode",
      sourceAppName: "Xcode",
      audioPath: "/tmp/recording.wav"
    )
  }

  @Test func insertAndFetchRoundTrips() throws {
    let store = try TranscriptStore.inMemory()
    let record = makeRecord()
    try store.insert(record)
    #expect(try store.record(id: record.id) == record)
    #expect(try store.count() == 1)
  }

  @Test func recordsReturnNewestFirst() throws {
    let store = try TranscriptStore.inMemory()
    let older = makeRecord(createdAt: Self.referenceDate.addingTimeInterval(-3600))
    let newer = makeRecord(createdAt: Self.referenceDate)
    try store.insert(older)
    try store.insert(newer)
    let records = try store.records()
    #expect(records.map(\.id) == [newer.id, older.id])
  }

  @Test func searchMatchesRawAndFinalText() throws {
    let store = try TranscriptStore.inMemory()
    try store.insert(makeRecord(rawText: "parakeet dictation run", finalText: "cleaned output"))
    try store.insert(makeRecord(rawText: "unrelated", finalText: "release notes follow-up"))
    #expect(try store.search("parakeet").count == 1)
    #expect(try store.search("release").count == 1)
    #expect(try store.search("nothing-here").isEmpty)
    #expect(try store.search("  ").count == 2)
  }

  @Test func deleteReturnsRemovedRecord() throws {
    let store = try TranscriptStore.inMemory()
    let record = makeRecord()
    try store.insert(record)
    let removed = try store.delete(id: record.id)
    #expect(removed == record)
    #expect(try store.count() == 0)
  }

  @Test func sweepRemovesOnlyExpiredRecords() throws {
    let store = try TranscriptStore.inMemory()
    let now = Self.referenceDate
    let fresh = makeRecord(createdAt: now)
    let stale = makeRecord(createdAt: now.addingTimeInterval(-60 * 86_400))
    try store.insert(fresh)
    try store.insert(stale)

    let removed = try store.sweep(retention: .oneMonth, now: now)
    #expect(removed.map(\.id) == [stale.id])
    #expect(try store.records().map(\.id) == [fresh.id])

    let untouched = try store.sweep(retention: .forever, now: now)
    #expect(untouched.isEmpty)
  }

  @Test func legacyImportIsIdempotent() throws {
    let store = try TranscriptStore.inMemory()
    let transcript = Transcript(
      timestamp: Self.referenceDate,
      text: "hello from the old history",
      audioPath: URL(fileURLWithPath: "/tmp/a.wav"),
      duration: 2.0,
      sourceAppBundleID: "com.apple.Notes",
      sourceAppName: "Notes"
    )
    #expect(try store.importLegacy([transcript]) == 1)
    #expect(try store.importLegacy([transcript]) == 0)
    let record = try store.record(id: transcript.id.uuidString)
    #expect(record?.finalText == "hello from the old history")
    #expect(record?.rawText == "hello from the old history")
  }

  @Test func updatePersistsTitleEdits() throws {
    let store = try TranscriptStore.inMemory()
    var record = makeRecord()
    try store.insert(record)
    record.title = "Renamed recording"
    try store.update(record)
    #expect(try store.record(id: record.id)?.title == "Renamed recording")
  }
}
