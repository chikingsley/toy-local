@preconcurrency import AVFoundation
import Foundation
import ToyLocalCore
@preconcurrency import WhisperKit

private let transcriptionLogger = ToyLocalLog.transcription
private let modelsLogger = ToyLocalLog.models
private let parakeetLogger = ToyLocalLog.parakeet

/// An actor that manages WhisperKit models by downloading (from Hugging Face),
/// loading them into memory, and then performing transcriptions.
actor TranscriptionClientLive {
	// MARK: - Stored Properties

	/// The current in-memory `WhisperKit` instance, if any.
	private var whisperKit: WhisperKit?

	/// The name of the currently loaded model, if any.
	private var currentModelName: String?
	private var parakeet: ParakeetClient = ParakeetClient()
	private var streamingParakeet: StreamingParakeetClient = StreamingParakeetClient()

	/// The base folder under which we store model data (e.g., ~/Library/Application Support/...).
	private lazy var modelsBaseFolder: URL = {
		do {
			let appSupportURL = try FileManager.default.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let ourAppFolder = appSupportURL.appendingPathComponent("com.chiejimofor.toylocal", isDirectory: true)
			let baseURL = ourAppFolder.appendingPathComponent("models", isDirectory: true)
			try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
			return baseURL
		} catch {
			fatalError("Could not create Application Support folder: \(error)")
		}
	}()

	// MARK: - Public Methods

	/// Ensures the given `variant` model is downloaded and loaded, reporting
	/// overall progress (0%–50% for downloading, 50%–100% for loading).
	func downloadAndLoadModel(variant: String, progressCallback: @Sendable @escaping (Progress) -> Void) async throws {
		// Streaming Parakeet models use StreamingParakeetClient
		if isStreamingParakeet(variant) {
			try await streamingParakeet.ensureLoaded(progress: progressCallback)
			return
		}
		// If batch Parakeet, use ParakeetClient path
		if isParakeet(variant) {
			try await parakeet.ensureLoaded(modelName: variant, progress: progressCallback)
			currentModelName = variant
			return
		}
		// Resolve wildcard patterns (e.g., "distil*large-v3") to a concrete variant
		let variant = await resolveVariant(variant)
		if variant.isEmpty {
			throw NSError(
				domain: "TranscriptionClient",
				code: -3,
				userInfo: [
					NSLocalizedDescriptionKey: "Cannot download model: Empty model name"
				]
			)
		}

		let overallProgress = Progress(totalUnitCount: 100)
		overallProgress.completedUnitCount = 0
		progressCallback(overallProgress)

		modelsLogger.info("Preparing model download and load for \(variant)")

		// 1) Model download phase (0-50% progress)
		if !(await isModelDownloaded(variant)) {
			try await downloadModelIfNeeded(variant: variant) { downloadProgress in
				let fraction = downloadProgress.fractionCompleted * 0.5
				overallProgress.completedUnitCount = Int64(fraction * 100)
				progressCallback(overallProgress)
			}
		} else {
			overallProgress.completedUnitCount = 50
			progressCallback(overallProgress)
		}

		// 2) Model loading phase (50-100% progress)
		try await loadWhisperKitModel(variant) { loadingProgress in
			let fraction = 0.5 + (loadingProgress.fractionCompleted * 0.5)
			overallProgress.completedUnitCount = Int64(fraction * 100)
			progressCallback(overallProgress)
		}

		overallProgress.completedUnitCount = 100
		progressCallback(overallProgress)
	}

	/// Deletes a model from disk if it exists
	func deleteModel(variant: String) async throws {
		if isStreamingParakeet(variant) {
			try await streamingParakeet.deleteCaches()
			return
		}
		if isParakeet(variant) {
			try await parakeet.deleteCaches(modelName: variant)
			if currentModelName == variant { unloadCurrentModel() }
			return
		}
		let modelFolder = modelPath(for: variant)

		guard FileManager.default.fileExists(atPath: modelFolder.path) else {
			return
		}

		if currentModelName == variant {
			unloadCurrentModel()
		}

		try FileManager.default.removeItem(at: modelFolder)
		modelsLogger.info("Deleted model \(variant)")
	}

	/// Returns `true` if the model is already downloaded to the local folder.
	func isModelDownloaded(_ modelName: String) async -> Bool {
		if isStreamingParakeet(modelName) {
			let available = await streamingParakeet.isModelAvailable()
			parakeetLogger.debug("Streaming Parakeet available? \(available)")
			return available
		}
		if isParakeet(modelName) {
			let available = await parakeet.isModelAvailable(modelName)
			parakeetLogger.debug("Parakeet available? \(available)")
			return available
		}
		let modelFolderPath = modelPath(for: modelName).path
		let fileManager = FileManager.default

		guard fileManager.fileExists(atPath: modelFolderPath) else {
			return false
		}

		do {
			let contents = try fileManager.contentsOfDirectory(atPath: modelFolderPath)
			guard !contents.isEmpty else {
				return false
			}

			let hasModelFiles = contents.contains { $0.hasSuffix(".mlmodelc") || $0.contains("model") }
			let tokenizerFolderPath = tokenizerPath(for: modelName).path
			let hasTokenizer = fileManager.fileExists(atPath: tokenizerFolderPath)

			return hasModelFiles && hasTokenizer
		} catch {
			return false
		}
	}

	/// Returns a list of recommended models based on current device hardware.
	func getRecommendedModels() async -> ModelSupport {
		await WhisperKit.recommendedRemoteModels()
	}

	/// Lists all model variants available in the `argmaxinc/whisperkit-coreml` repository.
	func getAvailableModels() async throws -> [String] {
		var names = try await WhisperKit.fetchAvailableModels()
		#if canImport(FluidAudio)
		for model in ParakeetModel.allCases.reversed() where !names.contains(model.identifier) {
			names.insert(model.identifier, at: 0)
		}
		#endif
		return names
	}

	/// Transcribes the audio file at `url` using a `model` name.
	func transcribe(
		url: URL,
		model: String,
		options: DecodingOptions,
		progressCallback: @Sendable @escaping (Progress) -> Void
	) async throws -> String {
		let startAll = Date()
		if isParakeet(model) {
			transcriptionLogger.notice("Transcribing with Parakeet model=\(model) file=\(url.lastPathComponent)")
			let startLoad = Date()
			try await downloadAndLoadModel(variant: model) { p in
				progressCallback(p)
			}
			transcriptionLogger.info("Parakeet ensureLoaded took \(String(format: "%.2f", Date().timeIntervalSince(startLoad)))s")
			let preparedClip = try ParakeetClipPreparer.ensureMinimumDuration(url: url, logger: parakeetLogger)
			defer { preparedClip.cleanup() }
			let startTx = Date()
			let text = try await parakeet.transcribe(preparedClip.url)
			transcriptionLogger.info("Parakeet transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
			transcriptionLogger.info("Parakeet request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
			return text
		}
		let model = await resolveVariant(model)
		if whisperKit == nil || model != currentModelName {
			unloadCurrentModel()
			let startLoad = Date()
			try await downloadAndLoadModel(variant: model) { p in
				progressCallback(p)
			}
			let loadDuration = Date().timeIntervalSince(startLoad)
			transcriptionLogger.info("WhisperKit ensureLoaded model=\(model) took \(String(format: "%.2f", loadDuration))s")
		}

		guard let whisperKit = whisperKit else {
			throw NSError(
				domain: "TranscriptionClient",
				code: -1,
				userInfo: [
					NSLocalizedDescriptionKey: "Failed to initialize WhisperKit for model: \(model)"
				]
			)
		}

		transcriptionLogger.notice("Transcribing with WhisperKit model=\(model) file=\(url.lastPathComponent)")
		let startTx = Date()
		let results = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
		transcriptionLogger.info("WhisperKit transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
		transcriptionLogger.info("WhisperKit request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")

		let text = results.map(\.text).joined(separator: " ")
		return text
	}

	// MARK: - Private Helpers

	private func resolveVariant(_ variant: String) async -> String {
		guard variant.contains("*") || variant.contains("?") else { return variant }

		let names: [String]
		do { names = try await WhisperKit.fetchAvailableModels() } catch { return variant }

		var models: [(name: String, isDownloaded: Bool)] = []
		for name in names where ModelPatternMatcher.matches(variant, name) {
			models.append((name, await isModelDownloaded(name)))
		}

		return ModelPatternMatcher.resolvePattern(variant, from: models) ?? variant
	}

	private func isParakeet(_ name: String) -> Bool {
		guard let model = ParakeetModel(rawValue: name) else { return false }
		return !model.isStreaming
	}

	private func isStreamingParakeet(_ name: String) -> Bool {
		guard let model = ParakeetModel(rawValue: name) else { return false }
		return model.isStreaming
	}

	private func modelPath(for variant: String) -> URL {
		let sanitizedVariant = variant.components(separatedBy: CharacterSet(charactersIn: "./\\")).joined(separator: "_")
		return modelsBaseFolder
			.appendingPathComponent("argmaxinc")
			.appendingPathComponent("whisperkit-coreml")
			.appendingPathComponent(sanitizedVariant, isDirectory: true)
	}

	private func tokenizerPath(for variant: String) -> URL {
		modelPath(for: variant).appendingPathComponent("tokenizer", isDirectory: true)
	}

	private func unloadCurrentModel() {
		whisperKit = nil
		currentModelName = nil
	}

	private func downloadModelIfNeeded(
		variant: String,
		progressCallback: @Sendable @escaping (Progress) -> Void
	) async throws {
		let modelFolder = modelPath(for: variant)

		let isDownloaded = await isModelDownloaded(variant)
		if FileManager.default.fileExists(atPath: modelFolder.path), !isDownloaded {
			try FileManager.default.removeItem(at: modelFolder)
		}

		if isDownloaded {
			return
		}

		modelsLogger.info("Downloading model \(variant)")

		let parentDir = modelFolder.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

		do {
			let tempFolder = try await WhisperKit.download(
				variant: variant,
				downloadBase: nil,
				useBackgroundSession: false
			) { progress in
				progressCallback(progress)
			}

			try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
			try moveContents(of: tempFolder, to: modelFolder)

			modelsLogger.info("Downloaded model to \(modelFolder.path)")
		} catch {
			FileManager.default.removeItemIfExists(at: modelFolder)
			modelsLogger.error("Error downloading model \(variant): \(error.localizedDescription)")
			throw error
		}
	}

	private func loadWhisperKitModel(
		_ modelName: String,
		progressCallback: @Sendable @escaping (Progress) -> Void
	) async throws {
		let loadingProgress = Progress(totalUnitCount: 100)
		loadingProgress.completedUnitCount = 0
		progressCallback(loadingProgress)

		let modelFolder = modelPath(for: modelName)
		let tokenizerFolder = tokenizerPath(for: modelName)

		let config = WhisperKitConfig(
			model: modelName,
			modelFolder: modelFolder.path,
			tokenizerFolder: tokenizerFolder,
			prewarm: false,
			load: true
		)

		whisperKit = try await WhisperKit(config)
		currentModelName = modelName

		loadingProgress.completedUnitCount = 100
		progressCallback(loadingProgress)

		modelsLogger.info("Loaded WhisperKit model \(modelName)")
	}

	private func moveContents(of sourceFolder: URL, to destFolder: URL) throws {
		let fileManager = FileManager.default
		let items = try fileManager.contentsOfDirectory(atPath: sourceFolder.path)
		for item in items {
			let src = sourceFolder.appendingPathComponent(item)
			let dst = destFolder.appendingPathComponent(item)
			try fileManager.moveItem(at: src, to: dst)
		}
	}
}
