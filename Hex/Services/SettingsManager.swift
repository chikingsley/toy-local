import Foundation
import HexCore

// Re-export types so the app target can use them without HexCore prefixes.
typealias RecordingAudioBehavior = HexCore.RecordingAudioBehavior
typealias HexSettings = HexCore.HexSettings

// MARK: - URL Extensions

extension URL {
	/// Returns the Application Support directory for Hex, creating it if needed.
	static var hexApplicationSupport: URL {
		get throws {
			let fm = FileManager.default
			let appSupport = try fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let hexDir = appSupport.appending(component: "com.kitlangton.Hex")
			try fm.createDirectory(at: hexDir, withIntermediateDirectories: true)
			return hexDir
		}
	}

	/// Legacy location in Documents (for migration).
	static var legacyDocumentsDirectory: URL {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
}

// MARK: - FileManager Extensions

extension FileManager {
	/// Copies a file from legacy location to new location if legacy exists and new doesn't.
	func migrateIfNeeded(from legacy: URL, to new: URL) {
		guard fileExists(atPath: legacy.path), !fileExists(atPath: new.path) else { return }
		try? copyItem(at: legacy, to: new)
	}

	/// Removes an item only if it exists, swallowing any errors.
	func removeItemIfExists(at url: URL) {
		guard fileExists(atPath: url.path) else { return }
		try? removeItem(at: url)
	}
}

// MARK: - SettingsManager

private let logger = HexLog.settings

/// Replaces all TCA `@Shared` state with a single `@Observable` owner.
///
/// File-persisted properties (`settings`, `transcriptionHistory`) are saved to JSON
/// with a 0.5 s debounce. In-memory properties (hotkey-edit flags, bootstrap state,
/// permission state) live only for the lifetime of the process.
@MainActor
@Observable
final class SettingsManager {

	// MARK: - File-Persisted State

	var settings: HexCore.HexSettings {
		didSet { scheduleSaveSettings() }
	}

	var transcriptionHistory: TranscriptionHistory {
		didSet { scheduleSaveHistory() }
	}

	// MARK: - In-Memory State

	var isSettingHotKey: Bool = false
	var isSettingPasteLastTranscriptHotkey: Bool = false
	var isRemappingScratchpadFocused: Bool = false
	var modelBootstrapState: ModelBootstrapState = .init()
	var hotkeyPermissionState: HotkeyPermissionState = .init()

	// MARK: - Private

	private var saveSettingsTask: Task<Void, Never>?
	private var saveHistoryTask: Task<Void, Never>?

	private let settingsURL: URL
	private let historyURL: URL

	// MARK: - Init

	init() {
		// Resolve file URLs (with legacy migration).
		let resolvedSettingsURL: URL
		let resolvedHistoryURL: URL

		do {
			let appSupport = try URL.hexApplicationSupport

			resolvedSettingsURL = appSupport.appending(component: "hex_settings.json")
			resolvedHistoryURL = appSupport.appending(component: "transcription_history.json")

			// Migrate from legacy Documents location if needed.
			let legacySettings = URL.legacyDocumentsDirectory.appending(component: "hex_settings.json")
			let legacyHistory = URL.legacyDocumentsDirectory.appending(component: "transcription_history.json")
			FileManager.default.migrateIfNeeded(from: legacySettings, to: resolvedSettingsURL)
			FileManager.default.migrateIfNeeded(from: legacyHistory, to: resolvedHistoryURL)
		} catch {
			logger.error("Failed to resolve Application Support directory: \(error.localizedDescription)")
			// Fall back to Documents.
			resolvedSettingsURL = URL.documentsDirectory.appending(component: "hex_settings.json")
			resolvedHistoryURL = URL.documentsDirectory.appending(component: "transcription_history.json")
		}

		self.settingsURL = resolvedSettingsURL
		self.historyURL = resolvedHistoryURL

		// Load settings from disk (or use defaults).
		self.settings = Self.load(HexCore.HexSettings.self, from: resolvedSettingsURL) ?? .init()
		self.transcriptionHistory = Self.load(TranscriptionHistory.self, from: resolvedHistoryURL) ?? .init()

		logger.info("SettingsManager initialized. Settings URL: \(resolvedSettingsURL.path)")
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
