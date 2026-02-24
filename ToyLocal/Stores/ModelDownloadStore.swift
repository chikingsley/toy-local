import AppKit
import Foundation
import ToyLocalCore

// MARK: - Data Models

public struct ModelInfo: Equatable, Identifiable, Sendable {
	public let name: String
	public var isDownloaded: Bool

	public var id: String { name }
	public init(name: String, isDownloaded: Bool) {
		self.name = name
		self.isDownloaded = isDownloaded
	}
}

public struct CuratedModelInfo: Equatable, Identifiable, Codable {
	public let displayName: String
	public let internalName: String
	public let size: String
	public let accuracyStars: Int
	public let speedStars: Int
	public let storageSize: String
	public var isDownloaded: Bool
	public var id: String { internalName }

	public var badge: String? {
		if internalName == "parakeet-tdt-0.6b-v2-coreml" {
			return "BEST FOR ENGLISH"
		} else if internalName == "parakeet-tdt-0.6b-v3-coreml" {
			return "BEST FOR MULTILINGUAL"
		}
		return nil
	}

	public init(
		displayName: String,
		internalName: String,
		size: String,
		accuracyStars: Int,
		speedStars: Int,
		storageSize: String,
		isDownloaded: Bool
	) {
		self.displayName = displayName
		self.internalName = internalName
		self.size = size
		self.accuracyStars = accuracyStars
		self.speedStars = speedStars
		self.storageSize = storageSize
		self.isDownloaded = isDownloaded
	}

	private enum CodingKeys: String, CodingKey {
		case displayName, internalName, size, accuracyStars, speedStars, storageSize
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		displayName = try c.decode(String.self, forKey: .displayName)
		internalName = try c.decode(String.self, forKey: .internalName)
		size = try c.decode(String.self, forKey: .size)
		accuracyStars = try c.decode(Int.self, forKey: .accuracyStars)
		speedStars = try c.decode(Int.self, forKey: .speedStars)
		storageSize = try c.decode(String.self, forKey: .storageSize)
		isDownloaded = false
	}
}

private enum CuratedModelLoader {
	static func load() -> [CuratedModelInfo] {
		guard let url = Bundle.main.url(forResource: "models", withExtension: "json") ??
			Bundle.main.url(forResource: "models", withExtension: "json", subdirectory: "Data")
		else {
			assertionFailure("models.json not found in bundle")
			return []
		}
		do { return try JSONDecoder().decode([CuratedModelInfo].self, from: Data(contentsOf: url)) } catch {
			assertionFailure("Failed to decode models.json – \(error)"); return []
		}
	}
}

// MARK: - Model Download Store

@MainActor @Observable
final class ModelDownloadStore {
	// MARK: - State

	var availableModels: [ModelInfo] = []
	var curatedModels: [CuratedModelInfo] = []
	var recommendedModel: String = ""
	var showAllModels = false
	var isDownloading = false
	var downloadProgress: Double = 0
	var downloadError: String?
	var downloadingModelName: String?

	private var activeDownloadTask: Task<Void, Never>?

	// MARK: - Dependencies

	private let settings: SettingsManager
	private let transcription: TranscriptionClientLive

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settings = services.settings
		self.transcription = services.transcription
	}

	// MARK: - Computed

	var hexSettings: ToyLocalSettings {
		get { settings.settings }
		set { settings.settings = newValue }
	}

	var modelBootstrapState: ModelBootstrapState {
		get { settings.modelBootstrapState }
		set { settings.modelBootstrapState = newValue }
	}

	var selectedModel: String { hexSettings.selectedModel }

	var selectedModelIsDownloaded: Bool {
		availableModels.first { $0.id == selectedModel }?.isDownloaded ?? false
	}

	var anyModelDownloaded: Bool {
		availableModels.contains { $0.isDownloaded }
	}

	var preferredParakeetIdentifier: String {
		(prefersEnglishParakeet ? ParakeetModel.englishV2 : ParakeetModel.multilingualV3).identifier
	}

	private var prefersEnglishParakeet: Bool {
		guard let language = hexSettings.outputLanguage?.lowercased(), !language.isEmpty else {
			return false
		}
		return language.hasPrefix("en")
	}

	// MARK: - Methods

	func fetchModels() {
		Task {
			do {
				let recommended = await transcription.getRecommendedModels().default
				let names = try await transcription.getAvailableModels()
				let infos = try await withThrowingTaskGroup(of: ModelInfo.self) { group -> [ModelInfo] in
					for name in names {
						group.addTask {
							ModelInfo(
								name: name,
								isDownloaded: await self.transcription.isModelDownloaded(name)
							)
						}
					}
					var results: [ModelInfo] = []
					for try await info in group {
						results.append(info)
					}
					return results
				}
				handleModelsLoaded(recommended: recommended, available: infos)
			} catch {
				handleModelsLoaded(recommended: "", available: [])
			}
		}
	}

	func selectModel(_ model: String) {
		let resolved = resolvePattern(model, from: availableModels) ?? model
		let isStreaming = ParakeetModel(rawValue: resolved)?.isStreaming == true
		hexSettings.selectedModel = resolved
		hexSettings.alwaysOnEnabled = isStreaming
		updateBootstrapState()
	}

	func toggleModelDisplay() {
		showAllModels.toggle()
	}

	func downloadSelectedModel() {
		guard !hexSettings.selectedModel.isEmpty else { return }
		downloadError = nil
		isDownloading = true
		let selected = hexSettings.selectedModel
		downloadingModelName = selected
		let displayName = curatedDisplayName(for: selected, curated: curatedModels)

		settings.modelBootstrapState.modelIdentifier = selected
		settings.modelBootstrapState.modelDisplayName = displayName
		settings.modelBootstrapState.isModelReady = false
		settings.modelBootstrapState.progress = 0
		settings.modelBootstrapState.lastError = nil

		activeDownloadTask?.cancel()
		activeDownloadTask = Task {
			do {
				try await transcription.downloadAndLoadModel(variant: selected) { [weak self] progress in
					Task { @MainActor [weak self] in
						self?.downloadProgress = progress.fractionCompleted
						if self?.downloadingModelName == self?.hexSettings.selectedModel {
							self?.settings.modelBootstrapState.progress = progress.fractionCompleted
						}
					}
				}
				handleDownloadCompleted(model: selected, error: nil)
			} catch {
				if !Task.isCancelled {
					handleDownloadCompleted(model: selected, error: error)
				}
			}
		}
	}

	func cancelDownload() {
		activeDownloadTask?.cancel()
		activeDownloadTask = nil
		isDownloading = false
		downloadingModelName = nil
		settings.modelBootstrapState.progress = 0
		settings.modelBootstrapState.isModelReady = false
		settings.modelBootstrapState.lastError = "Download cancelled"
	}

	func deleteSelectedModel() {
		guard !selectedModel.isEmpty else { return }
		settings.modelBootstrapState.isModelReady = false
		Task {
			do {
				try await transcription.deleteModel(variant: selectedModel)
				fetchModels()
			} catch {
				handleDownloadCompleted(model: selectedModel, error: error)
			}
		}
	}

	func openModelLocation() {
		Task.detached {
			let fm = FileManager.default
			let base = try fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			.appendingPathComponent("com.chiejimofor.toylocal/models", isDirectory: true)

			if !fm.fileExists(atPath: base.path) {
				try fm.createDirectory(at: base, withIntermediateDirectories: true)
			}
			_ = await MainActor.run {
				NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: base.path)
			}
			}
		}

	// MARK: - Private

	private func handleModelsLoaded(recommended: String, available: [ModelInfo]) {
		var availablePlus = available
		for model in ParakeetModel.allCases.reversed()
			where !availablePlus.contains(where: { $0.name == model.identifier }) {
			availablePlus.insert(ModelInfo(name: model.identifier, isDownloaded: false), at: 0)
		}

		if availablePlus.contains(where: { $0.name == preferredParakeetIdentifier }) {
			recommendedModel = preferredParakeetIdentifier
		} else {
			recommendedModel = recommended
		}
		availableModels = availablePlus

		// Resolve pattern if selected model contains wildcards
		if hexSettings.selectedModel.contains("*") || hexSettings.selectedModel.contains("?") {
			if let resolved = resolvePattern(hexSettings.selectedModel, from: available) {
				hexSettings.selectedModel = resolved
			}
		}

		// Merge curated + download status
		var curated = CuratedModelLoader.load()
		for idx in curated.indices {
			let internalName = curated[idx].internalName
			if let match = available.first(where: { ModelPatternMatcher.matches(internalName, $0.name) }) {
				curated[idx].isDownloaded = match.isDownloaded
			} else {
				curated[idx].isDownloaded = false
			}
		}
		curatedModels = curated

		updateBootstrapState()

		if !anyModelDownloaded && !hexSettings.hasCompletedModelBootstrap {
			let preferred = recommendedModel.isEmpty ? hexSettings.selectedModel : recommendedModel
			if !preferred.isEmpty {
				hexSettings.selectedModel = preferred
				updateBootstrapState()
			}
		}
	}

	private func handleDownloadCompleted(model: String, error: Error?) {
		isDownloading = false
		downloadingModelName = nil

		if let error {
			let message = Self.downloadErrorMessage(from: error)
			downloadError = message
			settings.modelBootstrapState.isModelReady = false
			settings.modelBootstrapState.lastError = message
			settings.modelBootstrapState.progress = 0
		} else {
			if let idx = availableModels.firstIndex(where: { $0.id == model }) {
				availableModels[idx].isDownloaded = true
			}
			if let idx = curatedModels.firstIndex(where: { $0.internalName == model }) {
				curatedModels[idx].isDownloaded = true
			}
			hexSettings.hasCompletedModelBootstrap = true
			downloadError = nil
			settings.modelBootstrapState.isModelReady = true
			settings.modelBootstrapState.lastError = nil
			settings.modelBootstrapState.progress = 1
		}
		updateBootstrapState()
	}

	static func downloadErrorMessage(from error: Error) -> String {
		let ns = error as NSError
		var message = ns.localizedDescription
		if let url = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL,
		   let host = url.host {
			message += " (\(host))"
		} else if let str = ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String,
		          let url = URL(string: str), let host = url.host {
			message += " (\(host))"
		}
		return message
	}

	static func resolveModelPattern(_ pattern: String, from available: [ModelInfo]) -> String? {
		ModelPatternMatcher.resolvePattern(pattern, from: available.map { ($0.name, $0.isDownloaded) })
	}

	static func modelDisplayName(for model: String, curated: [CuratedModelInfo]) -> String {
		if let match = curated.first(where: { ModelPatternMatcher.matches($0.internalName, model) }) {
			return match.displayName
		}
		return model
			.replacingOccurrences(of: "-", with: " ")
			.replacingOccurrences(of: "_", with: " ")
			.capitalized
	}

	private func resolvePattern(_ pattern: String, from available: [ModelInfo]) -> String? {
		Self.resolveModelPattern(pattern, from: available)
	}

	private func curatedDisplayName(for model: String, curated: [CuratedModelInfo]) -> String {
		Self.modelDisplayName(for: model, curated: curated)
	}

	private func updateBootstrapState() {
		let model = hexSettings.selectedModel
		guard !model.isEmpty else { return }
		let displayName = curatedDisplayName(for: model, curated: curatedModels)
		settings.modelBootstrapState.modelIdentifier = model
		settings.modelBootstrapState.modelDisplayName = displayName
		settings.modelBootstrapState.isModelReady = selectedModelIsDownloaded
		if selectedModelIsDownloaded {
			settings.modelBootstrapState.lastError = nil
			settings.modelBootstrapState.progress = 1
		}
	}
}
