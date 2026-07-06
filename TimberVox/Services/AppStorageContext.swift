import Foundation

enum AppStorageContext {
  private static var environment: [String: String] {
    ProcessInfo.processInfo.environment
  }

  static var isRunningForPreviews: Bool {
    environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
      || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
  }

  static var isRunningForTests: Bool {
    environment["XCTestConfigurationFilePath"] != nil
  }

  static var usesTemporarySettingsFiles: Bool {
    isRunningForPreviews || isRunningForTests
  }

  static var usesInMemoryTranscriptStore: Bool {
    isRunningForPreviews || isRunningForTests
  }
}
