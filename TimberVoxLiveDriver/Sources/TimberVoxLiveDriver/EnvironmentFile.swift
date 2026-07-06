import Foundation

enum EnvironmentFile {
  static func loadForLaunch() -> [String: String] {
    var environment: [String: String] = [:]
    for url in candidateURLs() where FileManager.default.fileExists(atPath: url.path) {
      environment.merge(parse(url: url)) { _, new in new }
    }
    return environment
  }

  private static func candidateURLs() -> [URL] {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return [
      cwd.appendingPathComponent(".env"),
      cwd.deletingLastPathComponent().appendingPathComponent(".env"),
    ]
  }

  private static func parse(url: URL) -> [String: String] {
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
    var values: [String: String] = [:]
    for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty, !line.hasPrefix("#") else { continue }
      let assignment = line.hasPrefix("export ") ? String(line.dropFirst("export ".count)) : line
      guard let separator = assignment.firstIndex(of: "=") else { continue }
      let key = assignment[..<separator].trimmingCharacters(in: .whitespaces)
      guard isSupportedKey(key) else { continue }
      let rawValue = assignment[assignment.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      values[key] = unquote(rawValue)
    }
    return values
  }

  private static func isSupportedKey(_ key: String) -> Bool {
    [
      "HF_TOKEN",
      "HUGGING_FACE_HUB_TOKEN",
      "HUGGINGFACEHUB_API_TOKEN",
      "REGISTRY_URL",
      "MODEL_REGISTRY_URL",
    ].contains(key)
  }

  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if value.first == "\"", value.last == "\"" {
      return String(value.dropFirst().dropLast())
    }
    if value.first == "'", value.last == "'" {
      return String(value.dropFirst().dropLast())
    }
    return value
  }
}
