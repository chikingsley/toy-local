import TimberVoxCore
import Foundation

// MARK: - URL Extensions

extension URL {
  /// Returns the Application Support directory for TimberVox, creating it if needed.
  static var timberVoxApplicationSupport: URL {
    get throws {
      let fm = FileManager.default
      let appSupport = try fm.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      let timberVoxDir = appSupport.appending(component: "com.chiejimofor.timbervox")
      try fm.createDirectory(at: timberVoxDir, withIntermediateDirectories: true)
      return timberVoxDir
    }
  }
}

// MARK: - FileManager Extensions

extension FileManager {
  /// Removes an item only if it exists, swallowing any errors.
  func removeItemIfExists(at url: URL) {
    guard fileExists(atPath: url.path) else { return }
    try? removeItem(at: url)
  }
}

// MARK: - SettingsManager

private let logger = TimberVoxLog.settings

/// Owns app settings, history, and transient UI state.
///
/// File-persisted properties (`settings`, `transcriptionHistory`) are saved to JSON
/// with a 0.5 s debounce. In-memory properties (hotkey-edit flags, bootstrap state,
/// permission state) live only for the lifetime of the process.
@MainActor
@Observable
final class SettingsManager {

  // MARK: - File-Persisted State

  var settings: TimberVoxCore.TimberVoxSettings {
    didSet { scheduleSaveSettings() }
  }

  var transcriptionHistory: TranscriptionHistory {
    didSet { scheduleSaveHistory() }
  }

  // MARK: - In-Memory State

  var isSettingHotKey: Bool = false
  var isSettingPasteLastTranscriptHotkey: Bool = false
  var isSettingAlwaysOnPasteHotkey: Bool = false
  var isSettingAlwaysOnDumpHotkey: Bool = false
  var isRemappingScratchpadFocused: Bool = false
  var modelBootstrapState: ModelBootstrapState = .init()
  var hotkeyPermissionState: HotkeyPermissionState = .init()

  var isSettingAnyHotKey: Bool {
    isSettingHotKey
      || isSettingPasteLastTranscriptHotkey
      || isSettingAlwaysOnPasteHotkey
      || isSettingAlwaysOnDumpHotkey
  }

  // MARK: - Private

  private var saveSettingsTask: Task<Void, Never>?
  private var saveHistoryTask: Task<Void, Never>?

  private let settingsURL: URL
  private let historyURL: URL

  // MARK: - Init

  init() {
    if AppStorageContext.usesTemporarySettingsFiles {
      let directorySuffix = AppStorageContext.isRunningForTests ? "test.\(UUID().uuidString)" : "preview"
      let transientDirectory = URL.temporaryDirectory.appendingPathComponent(
        "com.chiejimofor.timbervox.\(directorySuffix)",
        isDirectory: true
      )
      try? FileManager.default.createDirectory(at: transientDirectory, withIntermediateDirectories: true)

      self.settingsURL = transientDirectory.appendingPathComponent("settings.json")
      self.historyURL = transientDirectory.appendingPathComponent("transcription_history.json")
      self.settings = .init()
      self.transcriptionHistory = .init()

      logger.info("SettingsManager initialized in transient mode. Settings URL: \(self.settingsURL.path)")
      return
    }

    // Resolve file URLs.
    let resolvedSettingsURL: URL
    let resolvedHistoryURL: URL

    do {
      let appSupport = try URL.timberVoxApplicationSupport

      resolvedSettingsURL = appSupport.appending(component: "settings.json")
      resolvedHistoryURL = appSupport.appending(component: "transcription_history.json")
    } catch {
      logger.error("Failed to resolve Application Support directory: \(error.localizedDescription)")
      resolvedSettingsURL = URL.temporaryDirectory.appending(component: "timbervox-settings.json")
      resolvedHistoryURL = URL.temporaryDirectory.appending(component: "timbervox-transcription-history.json")
    }

    self.settingsURL = resolvedSettingsURL
    self.historyURL = resolvedHistoryURL

    // Load settings from disk (or use defaults).
    self.settings = Self.load(TimberVoxCore.TimberVoxSettings.self, from: resolvedSettingsURL) ?? .init()
    self.transcriptionHistory = Self.load(TranscriptionHistory.self, from: resolvedHistoryURL) ?? .init()

    logger.info("SettingsManager initialized. Settings URL: \(resolvedSettingsURL.path)")
    logger.info("Loaded \(self.settings.wordRemappings.count) word remappings from disk")
  }

  // MARK: - Persistence Helpers

  private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      logger.error("Failed to load \(String(describing: T.self)) from \(url.path): \(error.localizedDescription)")
      return nil
    }
  }

  private static func save<T: Encodable>(_ value: T, to url: URL) {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(value)
      try data.write(to: url, options: .atomic)
    } catch {
      logger.error("Failed to save \(String(describing: T.self)) to \(url.path): \(error.localizedDescription)")
    }
  }

  // MARK: - Debounced Save

  private func scheduleSaveSettings() {
    saveSettingsTask?.cancel()
    saveSettingsTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled, let self else { return }
      Self.save(self.settings, to: self.settingsURL)
    }
  }

  private func scheduleSaveHistory() {
    saveHistoryTask?.cancel()
    saveHistoryTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled, let self else { return }
      Self.save(self.transcriptionHistory, to: self.historyURL)
    }
  }
}
