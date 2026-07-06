extension FluidAudioModelMetrics {
  static let parakeetEou160 = parakeetEou(
    modelID: FluidAudioModels.parakeetEou160.id,
    subdirectory: "160ms",
    latencyMilliseconds: 160
  )
  static let parakeetEou320 = parakeetEou(
    modelID: FluidAudioModels.parakeetEou320.id,
    subdirectory: "320ms",
    latencyMilliseconds: 320
  )
  static let parakeetEou1280 = parakeetEou(
    modelID: FluidAudioModels.parakeetEou1280.id,
    subdirectory: "1280ms",
    latencyMilliseconds: 1280
  )

  static let nemotron560 = nemotron(
    modelID: FluidAudioModels.nemotron560.id,
    subdirectory: "560ms",
    latencyMilliseconds: 560,
    wordErrorRate: 2.28,
    realTimeFactor: 42.1
  )
  static let nemotron1120 = nemotron(
    modelID: FluidAudioModels.nemotron1120.id,
    subdirectory: "1120ms",
    latencyMilliseconds: 1120,
    wordErrorRate: 2.28,
    realTimeFactor: 65.0
  )
  static let nemotron2240 = nemotron(
    modelID: FluidAudioModels.nemotron2240.id,
    subdirectory: "2240ms",
    latencyMilliseconds: 2240,
    wordErrorRate: 2.46,
    realTimeFactor: 93.6
  )

  static let nemotronMultilingual560 = nemotronMultilingual(
    modelID: FluidAudioModels.nemotronMultilingual560.id,
    subdirectory: "560ms",
    latencyMilliseconds: 560,
    averageErrorRate: 12.1,
    realTimeFactor: 16.8
  )
  static let nemotronMultilingual1120 = nemotronMultilingual(
    modelID: FluidAudioModels.nemotronMultilingual1120.id,
    subdirectory: "1120ms",
    latencyMilliseconds: 1120,
    averageErrorRate: 11.4,
    realTimeFactor: 22.0
  )
  static let nemotronMultilingual2240 = nemotronMultilingual(
    modelID: FluidAudioModels.nemotronMultilingual2240.id,
    subdirectory: "2240ms",
    latencyMilliseconds: 2240,
    averageErrorRate: 11.4,
    realTimeFactor: 22.0,
    notes: [
      "Current benchmark table reports 320/560/1120 ms builds.",
      "2240 ms is documented as recommended, but no separate 2240 ms row is present.",
    ]
  )

  private static func parakeetEou(
    modelID: String,
    subdirectory: String,
    latencyMilliseconds: Double
  ) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .localCoreML,
      provider: "FluidAudio / NVIDIA",
      clientName: "StreamingParakeetClient",
      download: download(
        repo: "FluidInference/parakeet-realtime-eou-120m-coreml",
        subdirectory: subdirectory,
        approximateSizeMB: 200,
        cacheDirectory: "FluidAudio/Models/parakeet-eou-streaming/\(subdirectory)",
        source: huggingFace("FluidInference/parakeet-realtime-eou-120m-coreml")
      ),
      officialMetrics: [
        metric(.latencyMilliseconds, latencyMilliseconds, unit: "ms", provenance: .modelConfiguration, source: modelDocs),
        metric(.parameterCountMillions, 120, unit: "million parameters", provenance: .modelConfiguration, source: modelDocs),
      ],
      sources: [modelDocs, huggingFace("FluidInference/parakeet-realtime-eou-120m-coreml")],
      notes: [
        "English-only streaming ASR with end-of-utterance detection.",
        "Published WER/RTFx for these EOU tiers is not recorded in the current inventory.",
      ]
    )
  }

  private static func nemotron(
    modelID: String,
    subdirectory: String,
    latencyMilliseconds: Double,
    wordErrorRate: Double,
    realTimeFactor: Double
  ) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .localCoreML,
      provider: "FluidAudio / NVIDIA",
      clientName: "StreamingNemotronClient",
      download: download(
        repo: "FluidInference/nemotron-speech-streaming-en-0.6b-coreml",
        subdirectory: subdirectory,
        approximateSizeMB: 600,
        cacheDirectory: "FluidAudio/Models/nemotron-streaming/\(subdirectory)",
        source: huggingFace("FluidInference/nemotron-speech-streaming-en-0.6b-coreml")
      ),
      officialMetrics: [
        metric(
          .wordErrorRatePercent, wordErrorRate,
          unit: "percent", dataset: "LibriSpeech test-clean, 100 files",
          hardware: "Apple M5 Pro", source: nemotronDocs
        ),
        metric(
          .realTimeFactor, realTimeFactor,
          unit: "x", dataset: "LibriSpeech test-clean, 100 files",
          hardware: "Apple M5 Pro", source: nemotronDocs
        ),
        metric(.latencyMilliseconds, latencyMilliseconds, unit: "ms", provenance: .modelConfiguration, source: nemotronDocs),
        metric(.parameterCountMillions, 600, unit: "million parameters", provenance: .modelConfiguration, source: modelDocs),
      ],
      sources: [modelDocs, nemotronDocs, huggingFace("FluidInference/nemotron-speech-streaming-en-0.6b-coreml")],
      notes: ["English-only streaming RNNT. The 2240 ms tier is the documented default."]
    )
  }

  private static func nemotronMultilingual(
    modelID: String,
    subdirectory: String,
    latencyMilliseconds: Double,
    averageErrorRate: Double,
    realTimeFactor: Double,
    notes: [String] = []
  ) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .localCoreML,
      provider: "FluidAudio / NVIDIA",
      clientName: "StreamingNemotronClient",
      download: download(
        repo: "FluidInference/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML",
        subdirectory: "<language>/\(subdirectory)",
        approximateSizeMB: 1400,
        cacheDirectory: "FluidAudio/Models/nemotron-multilingual/<language>/\(subdirectory)",
        source: huggingFace("FluidInference/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML")
      ),
      officialMetrics: [
        metric(
          .wordErrorRatePercent, averageErrorRate,
          unit: "percent", dataset: "FLEURS average, WER for spaced scripts and CER for CJK",
          hardware: "Apple M2", source: nemotronMultilingualDocs
        ),
        metric(
          .realTimeFactor, realTimeFactor,
          unit: "x", dataset: "FLEURS average",
          hardware: "Apple M2", source: nemotronMultilingualDocs
        ),
        metric(
          .latencyMilliseconds, latencyMilliseconds,
          unit: "ms", provenance: .modelConfiguration,
          source: nemotronMultilingualDocs
        ),
        metric(.parameterCountMillions, 600, unit: "million parameters", provenance: .modelConfiguration, source: modelDocs),
      ],
      sources: [
        modelDocs,
        nemotronMultilingualDocs,
        huggingFace("FluidInference/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML"),
      ],
      notes: notes
    )
  }
}
