import Foundation
import GRDB

public final class TranscriptStore: Sendable {
  private let queue: DatabaseQueue

  public init(databaseURL: URL) throws {
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    queue = try DatabaseQueue(path: databaseURL.path)
    try Self.migrator.migrate(queue)
  }

  public static func inMemory() throws -> TranscriptStore {
    try TranscriptStore(queue: DatabaseQueue())
  }

  private init(queue: DatabaseQueue) throws {
    self.queue = queue
    try Self.migrator.migrate(queue)
  }

  private static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_recording") { db in
      try db.create(table: "recording") { table in
        table.primaryKey("id", .text)
        table.column("createdAt", .datetime).notNull().indexed()
        table.column("duration", .double).notNull()
        table.column("title", .text)
        table.column("rawText", .text).notNull()
        table.column("finalText", .text).notNull()
        table.column("modeName", .text)
        table.column("sourceAppBundleID", .text).indexed()
        table.column("sourceAppName", .text)
        table.column("audioPath", .text)
        table.column("contextJSON", .blob)
      }
      try db.create(virtualTable: "recording_ft", using: FTS5()) { table in
        table.synchronize(withTable: "recording")
        table.column("title")
        table.column("rawText")
        table.column("finalText")
      }
    }
    return migrator
  }

  public func insert(_ record: TranscriptRecord) throws {
    try queue.write { db in
      try record.save(db)
    }
  }

  public func delete(id: String) throws -> TranscriptRecord? {
    try queue.write { db in
      guard let record = try TranscriptRecord.fetchOne(db, key: id) else { return nil }
      try record.delete(db)
      return record
    }
  }

  public func update(_ record: TranscriptRecord) throws {
    try queue.write { db in
      try record.update(db)
    }
  }

  public func record(id: String) throws -> TranscriptRecord? {
    try queue.read { db in
      try TranscriptRecord.fetchOne(db, key: id)
    }
  }

  public func records(limit: Int? = nil) throws -> [TranscriptRecord] {
    try queue.read { db in
      var request = TranscriptRecord.order(Column("createdAt").desc)
      if let limit {
        request = request.limit(limit)
      }
      return try request.fetchAll(db)
    }
  }

  public func count() throws -> Int {
    try queue.read { db in
      try TranscriptRecord.fetchCount(db)
    }
  }

  public func search(_ text: String) throws -> [TranscriptRecord] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return try records() }
    return try queue.read { db in
      let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed)
      let sql = """
        SELECT recording.*
        FROM recording
        JOIN recording_ft ON recording_ft.rowid = recording.rowid
        WHERE recording_ft MATCH ?
        ORDER BY recording.createdAt DESC
        """
      return try TranscriptRecord.fetchAll(db, sql: sql, arguments: [pattern])
    }
  }

  @discardableResult
  public func sweep(retention: RecordingRetention, now: Date = Date()) throws -> [TranscriptRecord] {
    guard let cutoff = retention.cutoffDate(from: now) else { return [] }
    return try queue.write { db in
      let expired =
        try TranscriptRecord
        .filter(Column("createdAt") < cutoff)
        .fetchAll(db)
      try TranscriptRecord
        .filter(Column("createdAt") < cutoff)
        .deleteAll(db)
      return expired
    }
  }

  @discardableResult
  public func importLegacy(_ transcripts: [Transcript]) throws -> Int {
    try queue.write { db in
      var imported = 0
      for transcript in transcripts {
        let record = TranscriptRecord(legacy: transcript)
        if try TranscriptRecord.fetchOne(db, key: record.id) == nil {
          try record.insert(db)
          imported += 1
        }
      }
      return imported
    }
  }
}
