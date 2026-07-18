import Foundation

actor APIConnectorAuthorization {
  static let shared = APIConnectorAuthorization(apiKey: configuredAPIKey())

  private let apiKey: String?

  init(apiKey: String?) {
    self.apiKey = apiKey
  }

  func credential() throws -> String {
    guard let apiKey, !apiKey.isEmpty else {
      throw APIConnectorError.configuration(
        "This build does not have a Peacockery Voice credential."
      )
    }
    return apiKey
  }

  private static func configuredAPIKey() -> String? {
    let environment = ProcessInfo.processInfo.environment
    let environmentValue = environment["PEACOCKERY_VOICE_API_KEY"]
    let bundledValue =
      Bundle.main.object(forInfoDictionaryKey: "PeacockeryVoiceAPIKey") as? String
    let developmentValue = UserDefaults.standard.string(forKey: "PeacockeryVoiceAPIKey")
    return [environmentValue, bundledValue, keychainDevelopmentAPIKey(), developmentValue]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first {
        !$0.isEmpty
          && !$0.contains("$(PEACOCKERY_VOICE_API_KEY)")
      }
  }

  private static func keychainDevelopmentAPIKey() -> String? {
    #if DEBUG
      let process = Process()
      let output = Pipe()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
      process.arguments = [
        "find-generic-password",
        "-a",
        "lab-api-key",
        "-s",
        "peacockery-voice",
        "-w",
      ]
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        return nil
      }
      guard process.terminationStatus == 0 else { return nil }
      let data = output.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8)
    #else
      return nil
    #endif
  }
}
