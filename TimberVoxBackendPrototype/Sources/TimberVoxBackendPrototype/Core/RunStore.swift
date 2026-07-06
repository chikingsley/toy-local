import Foundation

struct RunStore {
  let outputRoot: URL

  init(outputRoot: URL) throws {
    self.outputRoot = outputRoot
    try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
  }

  func createRun(command: String, modelID: String) throws -> RunDirectory {
    let timestamp = RunStore.timestampFormatter.string(from: Date())
    let name = "\(timestamp)-\(command)-\(Self.slug(modelID))"
    let url = outputRoot.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return RunDirectory(url: url)
  }

  static func slug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(scalars).replacingOccurrences(of: "--", with: "-").lowercased()
  }

  static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
  }()
}

struct RunDirectory {
  let url: URL

  func writeJSON<T: Encodable>(_ value: T, filename: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    try writeData(data, filename: filename)
  }

  func writeData(_ data: Data, filename: String) throws {
    try data.write(to: url.appendingPathComponent(filename), options: .atomic)
  }
}

struct RunInput: Codable {
  let command: String
  let modelID: String
  let audioPath: String?
  let options: [String: String]
}

struct RunSummary: Codable {
  let command: String
  let modelID: String
  let status: String
  let resultPath: String
}

struct ProbeFailure: Codable {
  let status: String
  let command: String
  let modelID: String
  let message: String
  let errorType: String
}
