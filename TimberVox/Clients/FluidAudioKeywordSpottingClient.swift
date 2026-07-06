import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  actor FluidAudioKeywordSpottingClient {
    private var models: CtcModels?
    private var spotter: CtcKeywordSpotter?

    func isModelAvailable() -> Bool {
      CtcModels.modelsExist(at: CtcModels.defaultCacheDirectory(for: .ctc110m))
    }

    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      if models != nil, spotter != nil { return }
      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      let loaded = try await CtcModels.downloadAndLoad(variant: .ctc110m)
      self.models = loaded
      self.spotter = CtcKeywordSpotter(models: loaded)

      p.completedUnitCount = 100
      progress(p)
    }

    func spotKeywords(audioSamples: [Float], vocabulary: CustomVocabularyContext) async throws -> CtcKeywordSpotter.SpotKeywordsResult {
      guard let spotter else {
        throw NSError(domain: "FluidAudioKeywordSpotting", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keyword spotter not initialized"])
      }
      return try await spotter.spotKeywordsWithLogProbs(audioSamples: audioSamples, customVocabulary: vocabulary)
    }

    func deleteCaches() throws {
      let dir = CtcModels.defaultCacheDirectory(for: .ctc110m)
      if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
      }
      models = nil
      spotter = nil
    }
  }

#else

  actor FluidAudioKeywordSpottingClient {
    func isModelAvailable() -> Bool { false }
    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(domain: "FluidAudioKeywordSpotting", code: -2, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func deleteCaches() throws {}
  }

#endif
