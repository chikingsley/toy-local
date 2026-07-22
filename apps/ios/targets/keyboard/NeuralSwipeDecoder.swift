import Foundation
import OSLog

final class NeuralSwipeDecoder: SwipeDecoding {
  private let fallback = GeometricSwipeDecoder()
  private let baseTrieDecoder = CTCTrieDecoder()
  private let contextualTrieDecoder = CTCTrieDecoder(
    scoring: .futoEncoderRefinerAndContext
  )
  private let bundle: Bundle
  private let runtime: FutoSwipeRuntime?
  private var didLogNeuralSuccess = false
  private var lastPublishedStatus: String?
  private let statusLock = NSLock()
  private let logger = Logger(
    subsystem: "studio.peacockery.timbervox.keyboard",
    category: "SwipeDecoder"
  )

  init(bundle: Bundle = .main) {
    self.bundle = bundle
    do {
      let loadedRuntime = try FutoSwipeRuntime(bundle: bundle)
      runtime = loadedRuntime
      publishStatus("futo-loaded")
    } catch {
      runtime = nil
      publishStatus("geometric-fallback-load:\(error.localizedDescription)")
      logger.error("FUTO Swipe failed to load: \(error.localizedDescription, privacy: .public)")
    }
  }

  func prepareContext() {
    runtime?.beginLoadingContext(bundle: bundle) { [weak self] result in
      switch result {
      case .success:
        self?.publishStatus("futo-context-loaded")
      case .failure(let error):
        self?.publishStatus("futo-context-failed:\(error.localizedDescription)")
      }
    }
  }

  func releaseContext() {
    runtime?.releaseContextModel()
  }

  func predictions(
    for samples: [SwipePoint],
    layout: KeyLayout,
    vocabulary: [SwipeVocabularyEntry],
    contextWords: [String]
  ) -> [String] {
    guard let runtime else {
      publishStatus("geometric-fallback-load")
      return fallback.predictions(
        for: samples,
        layout: layout,
        vocabulary: vocabulary,
        contextWords: contextWords
      )
    }
    do {
      let emissions = try runtime.emissions(for: samples, layout: layout)
      let predictions: [String]
      if runtime.supportsContext, !contextWords.isEmpty {
        let candidates = contextualTrieDecoder.candidates(
          for: emissions,
          vocabulary: vocabulary,
          limit: 16
        )
        let languageModelScores = try runtime.contextScores(
          contextWords: contextWords,
          candidates: candidates.map(\.word)
        )
        predictions = ContextCandidateReranker.predictions(
          candidates: candidates,
          languageModelScores: languageModelScores
        )
      } else {
        predictions = baseTrieDecoder.predictions(
          for: emissions,
          vocabulary: vocabulary
        )
      }
      guard !predictions.isEmpty else {
        publishStatus("geometric-fallback-empty")
        return fallback.predictions(
          for: samples,
          layout: layout,
          vocabulary: vocabulary,
          contextWords: contextWords
        )
      }
      if !didLogNeuralSuccess {
        didLogNeuralSuccess = true
        logger.info(
          "FUTO Swipe inference succeeded with \(predictions.count, privacy: .public) predictions."
        )
      }
      publishStatus(
        runtime.supportsContext && !contextWords.isEmpty
          ? "futo-neural-context" : "futo-neural"
      )
      return predictions
    } catch {
      publishStatus("geometric-fallback-inference:\(error.localizedDescription)")
      logger.error("FUTO Swipe inference failed: \(error.localizedDescription, privacy: .public)")
      return fallback.predictions(
        for: samples,
        layout: layout,
        vocabulary: vocabulary,
        contextWords: contextWords
      )
    }
  }

  private func publishStatus(_ status: String) {
    statusLock.lock()
    defer { statusLock.unlock() }
    guard status != lastPublishedStatus else { return }
    lastPublishedStatus = status
    KeyboardBridge.set(status, for: .swipeDecoderStatus)
    KeyboardBridge.synchronize()
  }
}
