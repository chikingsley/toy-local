import Foundation

struct RunIndexOutput: Codable {
  let generatedAt: Date
  let outputRoot: String
  let runCount: Int
  let runs: [RunIndexEntry]
}

struct RunIndexEntry: Codable {
  let name: String
  let path: String
  let command: String?
  let modelID: String?
  let status: String?
  let audioPath: String?
  let options: [String: String]?
  let hasInput: Bool
  let hasResult: Bool
  let hasRaw: Bool
  let hasDiagnostics: Bool
  let hasProgressLog: Bool
  let modifiedAt: Date?
}

enum RunIndex {
  static func build(outputRoot: URL) throws -> RunIndexOutput {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: outputRoot, withIntermediateDirectories: true)

    let urls = try fileManager.contentsOfDirectory(
      at: outputRoot,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )

    let runs = urls.compactMap { url -> RunIndexEntry? in
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
      guard values?.isDirectory == true else { return nil }
      return entry(for: url, modifiedAt: values?.contentModificationDate)
    }
    .sorted { lhs, rhs in
      if lhs.name == rhs.name { return lhs.path < rhs.path }
      return lhs.name < rhs.name
    }

    return RunIndexOutput(
      generatedAt: Date(),
      outputRoot: outputRoot.path,
      runCount: runs.count,
      runs: runs
    )
  }

  private static func entry(for url: URL, modifiedAt: Date?) -> RunIndexEntry {
    let summaryURL = url.appendingPathComponent("summary.json")
    let inputURL = url.appendingPathComponent("input.json")
    let summary = try? decodeSummary(at: summaryURL)
    let input = try? decodeInput(at: inputURL)
    let status = summary?.status ?? (input == nil ? nil : "interrupted")
    return RunIndexEntry(
      name: url.lastPathComponent,
      path: url.path,
      command: summary?.command ?? input?.command,
      modelID: summary?.modelID ?? input?.modelID,
      status: status,
      audioPath: input?.audioPath,
      options: input?.options,
      hasInput: exists("input.json", in: url),
      hasResult: exists("result.json", in: url),
      hasRaw: exists("raw.json", in: url),
      hasDiagnostics: exists("diagnostics.json", in: url),
      hasProgressLog: exists("progress.jsonl", in: url),
      modifiedAt: modifiedAt
    )
  }

  private static func exists(_ filename: String, in directory: URL) -> Bool {
    FileManager.default.fileExists(atPath: directory.appendingPathComponent(filename).path)
  }

  private static func decodeSummary(at url: URL) throws -> RunSummary {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(RunSummary.self, from: data)
  }

  private static func decodeInput(at url: URL) throws -> RunInput {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(RunInput.self, from: data)
  }
}
