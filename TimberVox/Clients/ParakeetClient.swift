import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  private struct SendableAsrManager: @unchecked Sendable {
    let value: AsrManager
  }

  actor ParakeetClient {
    private var asr: SendableAsrManager?
    private var models: AsrModels?
    private var currentVariant: FluidAudioModel?
    private let logger = TimberVoxLog.parakeet
    private var isTranscriptionInFlight = false
    private var transcriptionWaiters: [CheckedContinuation<Void, Never>] = []

    func isModelAvailable(_ modelName: String) async -> Bool {
      guard let variant = FluidAudioModels.model(id: modelName), variant.role == .slidingWindowASR else {
        logger.error("Unknown Parakeet variant requested: \(modelName)")
        return false
      }
      if currentVariant == variant, asr != nil { return true }

      logger.debug("Checking Parakeet availability variant=\(variant.id)")
      for dir in modelDirectories(variant) where directoryContainsMLModelC(dir) {
        logger.notice("Found Parakeet cache at \(dir.path)")
        return true
      }
      logger.debug("No Parakeet cache detected variant=\(variant.id)")
      return false
    }

    private func directoryContainsMLModelC(_ dir: URL) -> Bool {
      let fm = FileManager.default
      guard fm.fileExists(atPath: dir.path) else { return false }
      if let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
        for case let url as URL in en {
          if url.pathExtension == "mlmodelc" || url.lastPathComponent.hasSuffix(".mlmodelc") { return true }
        }
      }
      return false
    }

    func ensureLoaded(modelName: String, progress: @Sendable @escaping (Progress) -> Void) async throws {
      guard let variant = FluidAudioModels.model(id: modelName), variant.role == .slidingWindowASR else {
        throw NSError(
          domain: "Parakeet",
          code: -4,
          userInfo: [NSLocalizedDescriptionKey: "Unsupported Parakeet variant: \(modelName)"]
        )
      }
      guard let version = variant.asrVersion else {
        throw NSError(
          domain: "Parakeet",
          code: -5,
          userInfo: [NSLocalizedDescriptionKey: "Streaming models are not supported by batch ParakeetClient. Use StreamingParakeetClient instead."]
        )
      }
      if currentVariant == variant, asr != nil { return }
      if currentVariant != variant {
        asr = nil
        models = nil
      }
      let t0 = Date()
      logger.notice("Starting Parakeet load variant=\(variant.id)")
      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      // Best-effort progress polling while FluidAudio downloads
      let faDir = modelDirectories(variant).first
      let pollTask = Task {
        while p.completedUnitCount < 95 {
          try? await Task.sleep(nanoseconds: 250_000_000)
          if let dir = faDir, let size = directorySize(dir) {
            let target: Double = 650 * 1024 * 1024  // ~650MB
            let frac = max(0.0, min(1.0, Double(size) / target))
            p.completedUnitCount = Int64(5 + frac * 90)
            progress(p)
          }
          if Task.isCancelled { break }
        }
      }
      defer { pollTask.cancel() }

      // Download + load the requested variant (returns when all assets are present)
      let models = try await AsrModels.downloadAndLoad(version: version)
      self.models = models
      let manager = AsrManager(config: .init())
      try await manager.loadModels(models)
      self.asr = SendableAsrManager(value: manager)
      self.currentVariant = variant
      p.completedUnitCount = 100
      progress(p)
      logger.notice("Parakeet ensureLoaded completed in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    }

    private func directorySize(_ dir: URL) -> UInt64? {
      let fm = FileManager.default
      guard
        let en = fm.enumerator(
          at: dir,
          includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
          options: .skipsHiddenFiles
        )
      else { return nil }
      var total: UInt64 = 0
      for case let url as URL in en {
        if let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), vals.isRegularFile == true {
          total &+= UInt64(vals.fileSize ?? 0)
        }
      }
      return total
    }

    func transcribe(_ url: URL) async throws -> String {
      await acquireTranscriptionPermit()
      defer { releaseTranscriptionPermit() }
      guard let asr else { throw NSError(domain: "Parakeet", code: -1, userInfo: [NSLocalizedDescriptionKey: "Parakeet not initialized"]) }
      let t0 = Date()
      logger.notice("Transcribing with Parakeet file=\(url.lastPathComponent)")
      var decoderState = TdtDecoderState.make(decoderLayers: await asr.value.decoderLayerCount)
      let result = try await asr.value.transcribe(url, decoderState: &decoderState)
      logger.info("Parakeet transcription finished in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
      return result.text
    }

    // Delete cached Parakeet models from known locations and reset state
    func deleteCaches(modelName: String) async throws {
      guard let variant = FluidAudioModels.model(id: modelName), variant.role == .slidingWindowASR else { return }
      let fm = FileManager.default

      var removedAny = false
      for dir in modelDirectories(variant) where fm.fileExists(atPath: dir.path) {
        try? fm.removeItem(at: dir)
        removedAny = true
      }

      // Reset live objects so a future download can proceed cleanly
      if removedAny {
        self.asr = nil
        self.models = nil
        if currentVariant == variant {
          currentVariant = nil
        }
      }
    }

    private func acquireTranscriptionPermit() async {
      if !isTranscriptionInFlight {
        isTranscriptionInFlight = true
        return
      }

      await withCheckedContinuation { continuation in
        transcriptionWaiters.append(continuation)
      }
    }

    private func releaseTranscriptionPermit() {
      if let continuation = transcriptionWaiters.first {
        transcriptionWaiters.removeFirst()
        continuation.resume()
        return
      }

      isTranscriptionInFlight = false
    }

    private func modelDirectories(_ variant: FluidAudioModel) -> [URL] {
      let fm = FileManager.default
      var result: [URL] = []

      if let version = variant.asrVersion {
        result.append(AsrModels.defaultCacheDirectory(for: version))
      }

      for root in candidateRoots() {
        for vendor in ["FluidAudio/Models", "fluidaudio/Models"] {
          let base = root.appendingPathComponent(vendor, isDirectory: true)
          for directoryName in cacheDirectoryNames(for: variant) {
            result.append(base.appendingPathComponent(directoryName, isDirectory: true))
          }

          if let items = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
            for item in items where cacheDirectoryNames(for: variant).contains(where: { item.lastPathComponent.hasPrefix($0) }) {
              result.append(item)
            }
          }
        }
      }
      return uniqueURLs(result)
    }

    private func cacheDirectoryNames(for variant: FluidAudioModel) -> [String] {
      switch variant.id {
      case FluidAudioModels.parakeetTdtV3.id:
        return [variant.id, "parakeet-tdt-0.6b-v3"]
      case FluidAudioModels.parakeetTdtCtc110m.id:
        return [variant.id, "parakeet-tdt-ctc-110m"]
      default:
        return [variant.id]
      }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
      var seen: Set<String> = []
      var unique: [URL] = []
      for url in urls {
        let path = url.standardizedFileURL.path
        guard seen.insert(path).inserted else { continue }
        unique.append(url)
      }
      return unique
    }

    private func candidateRoots() -> [URL] {
      let fm = FileManager.default
      let xdg = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"].flatMap { URL(fileURLWithPath: $0, isDirectory: true) }
      let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
      let appCache = appSupport?.appendingPathComponent("com.chiejimofor.timbervox/cache", isDirectory: true)
      let userCache = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache", isDirectory: true)
      return [xdg, appCache, appSupport, userCache].compactMap { $0 }
    }
  }

  private extension FluidAudioModel {
    var asrVersion: AsrModelVersion? {
      switch id {
      case FluidAudioModels.parakeetTdtV3.id:
        return .v3
      case FluidAudioModels.parakeetTdtCtc110m.id:
        return .tdtCtc110m
      default:
        return nil
      }
    }
  }

#else

  actor ParakeetClient {
    func isModelAvailable(_ modelName: String) async -> Bool { false }
    func ensureLoaded(modelName: String, progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(
        domain: "Parakeet",
        code: -2,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Parakeet support not linked. Add Swift Package: https://github.com/FluidInference/FluidAudio.git and link FluidAudio to TimberVox."
        ]
      )
    }
    func transcribe(_ url: URL) async throws -> String {
      throw NSError(domain: "Parakeet", code: -3, userInfo: [NSLocalizedDescriptionKey: "Parakeet not available"])
    }
    func deleteCaches(modelName: String) async throws {}
  }

#endif
