import Foundation

struct CoverageOutput: Codable {
  let generatedAt: Date
  let inventoryCount: Int
  let runCount: Int
  let statusCounts: [CoverageStatusCount]
  let entries: [CoverageEntry]
}

struct CoverageStatusCount: Codable {
  let status: String
  let count: Int
}

struct CoverageEntry: Codable {
  let modelID: String
  let displayName: String
  let family: String
  let runtime: String
  let command: String?
  let coverageStatus: String
  let latestRunStatus: String?
  let latestRunPath: String?
  let latestRunName: String?
  let matchingRunCount: Int
  let okRunCount: Int
  let interruptedRunCount: Int
  let failedRunCount: Int
  let notes: String
}

enum Coverage {
  static func build(outputRoot: URL) throws -> CoverageOutput {
    let index = try RunIndex.build(outputRoot: outputRoot)
    let entries = ModelInventory.all.map { model in
      entry(for: model, runs: index.runs)
    }

    let statusCounts = Dictionary(grouping: entries, by: \.coverageStatus)
      .map { status, entries in CoverageStatusCount(status: status, count: entries.count) }
      .sorted { lhs, rhs in lhs.status < rhs.status }

    return CoverageOutput(
      generatedAt: Date(),
      inventoryCount: ModelInventory.all.count,
      runCount: index.runCount,
      statusCounts: statusCounts,
      entries: entries
    )
  }

  private static func entry(for model: PrototypeModel, runs: [RunIndexEntry]) -> CoverageEntry {
    let matchingRuns = runs.filter { matches(model: model, run: $0) }
      .sorted { lhs, rhs in
        let lhsDate = lhs.modifiedAt ?? .distantPast
        let rhsDate = rhs.modifiedAt ?? .distantPast
        if lhsDate == rhsDate { return lhs.name < rhs.name }
        return lhsDate < rhsDate
      }

    let latest = matchingRuns.last
    let okCount = matchingRuns.filter { $0.status == "ok" }.count
    let interruptedCount = matchingRuns.filter { $0.status == "interrupted" }.count
    let failedCount = matchingRuns.filter { $0.status == "failed" }.count
    let status = coverageStatus(latest: latest, okCount: okCount)

    return CoverageEntry(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: model.probeCommand,
      coverageStatus: status,
      latestRunStatus: latest?.status,
      latestRunPath: latest?.path,
      latestRunName: latest?.name,
      matchingRunCount: matchingRuns.count,
      okRunCount: okCount,
      interruptedRunCount: interruptedCount,
      failedRunCount: failedCount,
      notes: model.notes
    )
  }

  private static func matches(model: PrototypeModel, run: RunIndexEntry) -> Bool {
    guard run.command == model.probeCommand else { return false }

    switch model.id {
    case "deepgram-nova-3":
      return run.modelID == "nova-3" && bool(run.options?["diarize"]) != true
    case "deepgram-nova-3-diarized":
      return run.modelID == "nova-3" && bool(run.options?["diarize"]) == true
    default:
      return run.modelID == model.id
    }
  }

  private static func coverageStatus(latest: RunIndexEntry?, okCount: Int) -> String {
    guard let latest else { return "missing" }
    switch latest.status {
    case "ok":
      return "ok"
    case "interrupted":
      return okCount > 0 ? "regressed-interrupted" : "interrupted"
    case "failed":
      return okCount > 0 ? "regressed-failed" : "failed"
    default:
      return latest.status ?? "unknown"
    }
  }

  private static func bool(_ value: String?) -> Bool? {
    guard let value else { return nil }
    switch value.lowercased() {
    case "true", "1", "yes", "y": return true
    case "false", "0", "no", "n": return false
    default: return nil
    }
  }
}
