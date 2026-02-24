@preconcurrency import AVFoundation
import CoreML
import Foundation
import ToyLocalCore

#if canImport(FluidAudio)
import FluidAudio

actor StreamingParakeetClient {
	private var manager: StreamingEouAsrManager?
	private var currentChunkSize: StreamingChunkSize?
	private let logger = ToyLocalLog.streaming

	private var partialContinuation: AsyncStream<String>.Continuation?
	private var utteranceContinuation: AsyncStream<String>.Continuation?

	func isModelAvailable() async -> Bool {
		if manager != nil { return true }
		// Check if model files exist on disk even if not loaded in memory
		let fm = FileManager.default
		guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return false }
		let modelDir = appSupport.appendingPathComponent("FluidAudio/Models/parakeet-eou-streaming/160ms", isDirectory: true)
		let vocabPath = modelDir.appendingPathComponent("vocab.json").path
		let encoderPath = modelDir.appendingPathComponent("streaming_encoder.mlmodelc").path
		return fm.fileExists(atPath: vocabPath) && fm.fileExists(atPath: encoderPath)
	}

	func ensureLoaded(chunkSize: StreamingChunkSize = .ms160, progress: @Sendable @escaping (Progress) -> Void) async throws {
		if currentChunkSize == chunkSize, manager != nil { return }

		// Reset if switching chunk size
		if currentChunkSize != chunkSize {
			manager = nil
		}

		let t0 = Date()
		logger.notice("Starting streaming EOU model load chunkSize=\(String(describing: chunkSize))")

		let p = Progress(totalUnitCount: 100)
		p.completedUnitCount = 1
		progress(p)

		// Determine repo and base directory.
		// downloadRepo(repo, to: baseDir) stores files at baseDir/<repo.folderName>/
		// For .parakeetEou160, folderName = "parakeet-eou-streaming/160ms"
		let repo: Repo = (chunkSize == .ms160) ? .parakeetEou160 : .parakeetEou320
		let fm = FileManager.default
		guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
			throw NSError(domain: "StreamingParakeet", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot locate Application Support directory"])
		}

		let baseDir = appSupport.appendingPathComponent("FluidAudio/Models", isDirectory: true)
		let subdirectory = chunkSize == .ms160 ? "160ms" : "320ms"
		let modelDir = baseDir.appendingPathComponent("parakeet-eou-streaming/\(subdirectory)", isDirectory: true)

		// Skip download if model files already exist on disk
		let vocabExists = fm.fileExists(atPath: modelDir.appendingPathComponent("vocab.json").path)
		let encoderExists = fm.fileExists(atPath: modelDir.appendingPathComponent("streaming_encoder.mlmodelc").path)
		if vocabExists && encoderExists {
			logger.notice("Streaming model files already on disk, skipping download")
			p.completedUnitCount = 90
			progress(p)
		} else {
			// Progress polling while downloading
			let pollTask = Task {
				while p.completedUnitCount < 90 {
					try? await Task.sleep(nanoseconds: 500_000_000)
					if let size = directorySize(modelDir) {
						let target: Double = 200 * 1024 * 1024 // ~200MB
						let frac = max(0.0, min(1.0, Double(size) / target))
						p.completedUnitCount = Int64(5 + frac * 85)
						progress(p)
					}
					if Task.isCancelled { break }
				}
			}
			defer { pollTask.cancel() }

			// Download models — files land at baseDir/parakeet-eou-streaming/<chunk>/
			try await DownloadUtils.downloadRepo(repo, to: baseDir)
			p.completedUnitCount = 90
			progress(p)
		}

		// Initialize manager
		let config = MLModelConfiguration()
		config.computeUnits = .all

		let mgr = StreamingEouAsrManager(
			configuration: config,
			chunkSize: chunkSize,
			eouDebounceMs: 1280
		)
		try await mgr.loadModels(modelDir: modelDir)

		self.manager = mgr
		self.currentChunkSize = chunkSize

		p.completedUnitCount = 100
		progress(p)
		logger.notice("Streaming EOU model loaded in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
	}

	func setupCallbacks() async -> (partials: AsyncStream<String>, utterances: AsyncStream<String>) {
		guard let manager else {
			return (AsyncStream { $0.finish() }, AsyncStream { $0.finish() })
		}

		// Finish any previous continuations
		partialContinuation?.finish()
		utteranceContinuation?.finish()

		let (partialStream, partialCont) = AsyncStream.makeStream(of: String.self)
		let (utteranceStream, utteranceCont) = AsyncStream.makeStream(of: String.self)

		self.partialContinuation = partialCont
		self.utteranceContinuation = utteranceCont

		// Callbacks are @Sendable (String) -> Void — capture continuations directly
		await manager.setPartialCallback { partial in
			partialCont.yield(partial)
		}

		await manager.setEouCallback { utterance in
			utteranceCont.yield(utterance)
		}

		return (partialStream, utteranceStream)
	}

	func processBuffer(_ buffer: AVAudioPCMBuffer) async throws {
		guard let manager else {
			throw NSError(domain: "StreamingParakeet", code: -2, userInfo: [NSLocalizedDescriptionKey: "Streaming model not initialized"])
		}
		_ = try await manager.process(audioBuffer: buffer)
	}

	func finish() async throws -> String {
		guard let manager else { return "" }
		return try await manager.finish()
	}

	func reset() async {
		await manager?.reset()
	}

	func teardown() {
		partialContinuation?.finish()
		utteranceContinuation?.finish()
		partialContinuation = nil
		utteranceContinuation = nil
		manager = nil
		currentChunkSize = nil
		logger.notice("Streaming client torn down")
	}

	func deleteCaches() throws {
		let fm = FileManager.default
		guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
		let streamingDir = appSupport.appendingPathComponent("FluidAudio/Models/parakeet-eou-streaming", isDirectory: true)
		if fm.fileExists(atPath: streamingDir.path) {
			try fm.removeItem(at: streamingDir)
		}
		manager = nil
		currentChunkSize = nil
	}

	private func directorySize(_ dir: URL) -> UInt64? {
		let fm = FileManager.default
		guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: .skipsHiddenFiles) else { return nil }
		var total: UInt64 = 0
		for case let url as URL in en {
			if let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), vals.isRegularFile == true {
				total &+= UInt64(vals.fileSize ?? 0)
			}
		}
		return total
	}
}

#else

actor StreamingParakeetClient {
	func isModelAvailable() async -> Bool { false }
	func ensureLoaded(chunkSize: Any? = nil, progress: @Sendable @escaping (Progress) -> Void) async throws {
		throw NSError(
			domain: "StreamingParakeet",
			code: -3,
			userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked. Streaming ASR unavailable."]
		)
	}
	func setupCallbacks() async -> (partials: AsyncStream<String>, utterances: AsyncStream<String>) { (.finished, .finished) }
	func processBuffer(_ buffer: Any) async throws {}
	func finish() async throws -> String { "" }
	func reset() async {}
	func teardown() {}
	func deleteCaches() throws {}
}

#endif
