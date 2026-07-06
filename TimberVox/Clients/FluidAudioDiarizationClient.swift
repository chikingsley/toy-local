@preconcurrency import AVFoundation
import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  actor FluidAudioDiarizationClient {
    private var sortformer: SortformerDiarizer?
    private var lsEend: LSEENDDiarizer?

    func isModelAvailable(modelName: String) -> Bool {
      guard let variant = DiarizationVariant(modelName: modelName) else { return false }
      return FileManager.default.fileExists(atPath: variant.cacheDirectory.path)
    }

    func ensureLoaded(modelName: String, progress: @Sendable @escaping (Progress) -> Void) async throws {
      guard let variant = DiarizationVariant(modelName: modelName) else {
        throw unsupported(modelName)
      }

      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      switch variant {
      case .sortformer:
        let diarizer = SortformerDiarizer()
        let modelPath = try await variant.ensureSortformerModel(progress: progress, progressState: p)
        try await diarizer.initialize(mainModelPath: modelPath)
        self.sortformer = diarizer
      case .lsEend(let value):
        let diarizer = LSEENDDiarizer()
        try await diarizer.initialize(variant: value) { downloadProgress in
          p.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
          progress(p)
        }
        self.lsEend = diarizer
      }

      p.completedUnitCount = 100
      progress(p)
    }

    func process(samples: [Float], modelName: String, sourceSampleRate: Double = 16_000) async throws -> DiarizerTimelineUpdate? {
      guard let variant = DiarizationVariant(modelName: modelName) else {
        throw unsupported(modelName)
      }

      switch variant {
      case .sortformer:
        guard let sortformer else { throw notLoaded(modelName) }
        try sortformer.addAudio(samples, sourceSampleRate: sourceSampleRate)
        return try sortformer.process()
      case .lsEend:
        guard let lsEend else { throw notLoaded(modelName) }
        try lsEend.addAudio(samples, sourceSampleRate: sourceSampleRate)
        return try lsEend.process()
      }
    }

    func finalize(modelName: String) throws -> DiarizerTimelineUpdate? {
      guard let variant = DiarizationVariant(modelName: modelName) else {
        throw unsupported(modelName)
      }

      switch variant {
      case .sortformer:
        return try sortformer?.finalizeSession()
      case .lsEend:
        return try lsEend?.finalizeSession()
      }
    }

    func deleteCaches(modelName: String) throws {
      guard let variant = DiarizationVariant(modelName: modelName) else { return }
      let dir = variant.cacheDirectory
      if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
      }
      sortformer = nil
      lsEend = nil
    }

    private func unsupported(_ modelName: String) -> NSError {
      NSError(domain: "FluidAudioDiarization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported diarization model: \(modelName)"])
    }

    private func notLoaded(_ modelName: String) -> NSError {
      NSError(domain: "FluidAudioDiarization", code: -2, userInfo: [NSLocalizedDescriptionKey: "Diarization model not loaded: \(modelName)"])
    }
  }

  private enum DiarizationVariant {
    case sortformer
    case lsEend(LSEENDVariant)

    init?(modelName: String) {
      switch modelName {
      case FluidAudioModels.sortformer.id:
        self = .sortformer
      case FluidAudioModels.lsEendAmi.id:
        self = .lsEend(.ami)
      case FluidAudioModels.lsEendCallhome.id:
        self = .lsEend(.callhome)
      case FluidAudioModels.lsEendDihard2.id:
        self = .lsEend(.dihard2)
      case FluidAudioModels.lsEendDihard3.id:
        self = .lsEend(.dihard3)
      default:
        return nil
      }
    }

    var cacheDirectory: URL {
      switch self {
      case .sortformer:
        return modelsBaseDirectory().appendingPathComponent(Repo.sortformer.folderName, isDirectory: true)
      case .lsEend(let variant):
        return modelsBaseDirectory().appendingPathComponent(variant.repo.folderName, isDirectory: true)
      }
    }

    func ensureSortformerModel(
      progress: @Sendable @escaping (Progress) -> Void,
      progressState: Progress
    ) async throws -> URL {
      let base = modelsBaseDirectory()
      try await DownloadUtils.downloadRepo(.sortformer, to: base) { downloadProgress in
        progressState.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
        progress(progressState)
      }

      let candidates = [
        cacheDirectory.appendingPathComponent("Sortformer_v2.1.mlmodelc"),
        cacheDirectory.appendingPathComponent("Sortformer_v2.mlmodelc"),
        cacheDirectory.appendingPathComponent("SortformerNvidiaHigh_v2.1.mlmodelc"),
        cacheDirectory.appendingPathComponent("SortformerNvidiaLow_v2.1.mlmodelc"),
      ]
      if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
        return path
      }
      throw NSError(
        domain: "FluidAudioDiarization", code: -3, userInfo: [NSLocalizedDescriptionKey: "Sortformer model file not found in \(cacheDirectory.path)"])
    }

    private func modelsBaseDirectory() -> URL {
      (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true))
        .appendingPathComponent("FluidAudio", isDirectory: true)
        .appendingPathComponent("Models", isDirectory: true)
    }
  }

#else

  actor FluidAudioDiarizationClient {
    func isModelAvailable(modelName: String) -> Bool { false }
    func ensureLoaded(modelName: String, progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(domain: "FluidAudioDiarization", code: -4, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func deleteCaches(modelName: String) throws {}
  }

#endif
