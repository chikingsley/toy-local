import TimberVoxCore
import Foundation

struct AppControl {
  let target: Target

  var stateURL: URL {
    URL.timberVoxApplicationSupport.appendingPathComponent("debug-state.json")
  }

  func launch() throws {
    var arguments = [
      "-g",
      "-a",
      try appBundleURL().path,
    ]
    var environment = EnvironmentFile.loadForLaunch()
    environment["TIMBERVOX_DISABLE_SPARKLE"] = "1"
    for key in environment.keys.sorted() {
      guard let value = environment[key] else { continue }
      arguments.append("--env")
      arguments.append("\(key)=\(value)")
    }

    try runProcess(
      "/usr/bin/open",
      arguments
    )
  }

  func quit() {
    _ = try? runProcess(
      "/usr/bin/osascript",
      ["-e", "tell application id \"\(target.bundleIdentifier)\" to quit"],
      allowFailure: true
    )
  }

  func openURL(_ url: String) throws {
    try runProcess("/usr/bin/open", [url])
  }

  @discardableResult
  func requestState(timeout: TimeInterval = 5) throws -> DebugStateSnapshot {
    try FileManager.default.createDirectory(
      at: URL.timberVoxApplicationSupport,
      withIntermediateDirectories: true
    )
    let previousModification = stateModificationDate()
    try openURL("timbervox-debug://state")
    try waitForStateChange(after: previousModification, timeout: timeout)
    return try readState()
  }

  func readState() throws -> DebugStateSnapshot {
    let data = try Data(contentsOf: stateURL)
    return try JSONDecoder().decode(DebugStateSnapshot.self, from: data)
  }

  func resetTCC(services: [TCCService]) {
    for service in services {
      print("Resetting \(service.rawValue) for \(target.bundleIdentifier)")
      _ = try? runProcess(
        "/usr/bin/tccutil",
        ["reset", service.rawValue, target.bundleIdentifier],
        allowFailure: true
      )
    }
  }

  private func appBundleURL() throws -> URL {
    let derivedData = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
    let enumerator = FileManager.default.enumerator(
      at: derivedData,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var candidates: [URL] = []
    while let url = enumerator?.nextObject() as? URL {
      guard url.lastPathComponent == "TimberVox.app",
        url.path.contains("/Build/Products/\(target.configuration)/"),
        !url.path.contains("/Index.noindex/")
      else {
        continue
      }
      candidates.append(url)
    }

    guard let app = candidates.max(by: { $0.path < $1.path }) else {
      throw DriverError(
        "No \(target.configuration) timbervox.app found in DerivedData. Build the app first."
      )
    }
    return app
  }

  private func stateModificationDate() -> Date? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: stateURL.path) else {
      return nil
    }
    return attributes[.modificationDate] as? Date
  }

  private func waitForStateChange(after previous: Date?, timeout: TimeInterval) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let current = stateModificationDate()
      if previous == nil, current != nil {
        return
      }
      if let previous, let current, current > previous {
        return
      }
      Thread.sleep(forTimeInterval: 0.2)
    }
    throw DriverError("Timed out waiting for debug state at \(stateURL.path)")
  }
}

enum TCCService: String, CaseIterable {
  case microphone = "Microphone"
  case accessibility = "Accessibility"
  case screenCapture = "ScreenCapture"
  case audioCapture = "AudioCapture"
  case appleEvents = "AppleEvents"
  case listenEvent = "ListenEvent"
}
