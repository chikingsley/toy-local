extension FluidAudioModelMetrics {
  static let customVocabularyCtc110m = ModelMetricProfile(
    modelID: FluidAudioModels.customVocabularyCtc110m.id,
    runtime: .localCoreML,
    provider: "FluidAudio / NVIDIA",
    clientName: "FluidAudioKeywordSpottingClient",
    download: download(
      repo: "FluidInference/parakeet-ctc-110m-coreml",
      approximateSizeMB: 120,
      cacheDirectory: "FluidAudio/Models/parakeet-ctc-110m-coreml",
      source: huggingFace("FluidInference/parakeet-ctc-110m-coreml")
    ),
    officialMetrics: [
      metric(.vocabularyPrecisionPercent, 99.3, unit: "percent", dataset: "Earnings22-KWS", source: benchmarkDocs),
      metric(.vocabularyRecallPercent, 85.2, unit: "percent", dataset: "Earnings22-KWS", source: benchmarkDocs),
      metric(.vocabularyFScorePercent, 91.7, unit: "percent", dataset: "Earnings22-KWS", source: benchmarkDocs),
      metric(.realTimeFactor, 63.36, unit: "x", dataset: "Earnings22-KWS", source: benchmarkDocs),
      metric(.parameterCountMillions, 110, unit: "million parameters", provenance: .modelConfiguration, source: customVocabularyDocs),
    ],
    sources: [modelDocs, customVocabularyDocs, benchmarkDocs, huggingFace("FluidInference/parakeet-ctc-110m-coreml")],
    notes: ["Support model for custom vocabulary and keyword spotting; not a standalone ASR selection."]
  )

  static let sileroVad = ModelMetricProfile(
    modelID: FluidAudioModels.sileroVad.id,
    runtime: .localCoreML,
    provider: "FluidAudio / Silero",
    clientName: "FluidAudioVadClient",
    download: download(
      repo: "FluidInference/silero-vad-coreml",
      approximateSizeMB: 5,
      cacheDirectory: "FluidAudio/Models/silero-vad-coreml",
      source: huggingFace("FluidInference/silero-vad-coreml")
    ),
    officialMetrics: [
      metric(.vadAccuracyPercent, 96.0, unit: "percent", dataset: "VOiCES subset", source: benchmarkDocs),
      metric(.vadPrecisionPercent, 100.0, unit: "percent", dataset: "VOiCES subset", source: benchmarkDocs),
      metric(.vadRecallPercent, 95.8, unit: "percent", dataset: "VOiCES subset", source: benchmarkDocs),
      metric(.vadF1Percent, 97.9, unit: "percent", dataset: "VOiCES subset", source: benchmarkDocs),
      metric(.realTimeFactor, 1230.6, unit: "x", dataset: "VOiCES subset", source: benchmarkDocs),
      metric(.latencyMilliseconds, 256, unit: "ms", provenance: .modelConfiguration, source: vadDocs),
    ],
    sources: [modelDocs, vadDocs, benchmarkDocs, huggingFace("FluidInference/silero-vad-coreml")],
    notes: ["Support model for speech/silence segmentation. FluidAudio docs state this is Silero VAD v6."]
  )

  static let sortformer = ModelMetricProfile(
    modelID: FluidAudioModels.sortformer.id,
    runtime: .localCoreML,
    provider: "FluidAudio / NVIDIA",
    clientName: "FluidAudioDiarizationClient",
    download: download(
      repo: "FluidInference/diar-streaming-sortformer-coreml",
      approximateSizeMB: 300,
      cacheDirectory: "FluidAudio/Models/sortformer",
      source: huggingFace("FluidInference/diar-streaming-sortformer-coreml")
    ),
    officialMetrics: [
      metric(
        .diarizationErrorRatePercent, 20.57,
        unit: "percent", dataset: "AMI SDM",
        provenance: .upstreamBenchmark, source: sortformerCard
      ),
      metric(.diarizationErrorRatePercent, 20.6, unit: "percent", dataset: "AMI SDM", source: sortformerDocs),
      metric(.latencyMilliseconds, 1040, unit: "ms", provenance: .modelConfiguration, source: sortformerDocs),
      metric(.maxSpeakers, 4, unit: "speakers", provenance: .modelConfiguration, source: sortformerDocs),
    ],
    sources: [modelDocs, sortformerDocs, sortformerCard],
    notes: ["Sortformer has a hard 4-speaker limit and baked-in static CoreML shapes."]
  )

  static let lsEendAmi = lsEend(
    modelID: FluidAudioModels.lsEendAmi.id,
    subdirectory: "optimized/ami",
    cacheDirectory: "FluidAudio/Models/ls-eend/ami",
    dataset: "AMI test set",
    diarizationErrorRate: 20.76,
    maxSpeakers: 4
  )
  static let lsEendCallHome = lsEend(
    modelID: FluidAudioModels.lsEendCallhome.id,
    subdirectory: "optimized/ch",
    cacheDirectory: "FluidAudio/Models/ls-eend/ch",
    dataset: "CALLHOME test set",
    diarizationErrorRate: 12.11,
    maxSpeakers: 7
  )
  static let lsEendDihard2 = lsEend(
    modelID: FluidAudioModels.lsEendDihard2.id,
    subdirectory: "optimized/dih2",
    cacheDirectory: "FluidAudio/Models/ls-eend/dih2",
    dataset: "DIHARD II test set",
    diarizationErrorRate: 27.58,
    maxSpeakers: 10
  )
  static let lsEendDihard3 = lsEend(
    modelID: FluidAudioModels.lsEendDihard3.id,
    subdirectory: "optimized/dih3",
    cacheDirectory: "FluidAudio/Models/ls-eend/dih3",
    dataset: "DIHARD III test set",
    diarizationErrorRate: 19.61,
    maxSpeakers: 10
  )

  private static func lsEend(
    modelID: String,
    subdirectory: String,
    cacheDirectory: String,
    dataset: String,
    diarizationErrorRate: Double,
    maxSpeakers: Double
  ) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .localCoreML,
      provider: "FluidAudio / Westlake University",
      clientName: "FluidAudioDiarizationClient",
      download: download(
        repo: "FluidInference/ls-eend-coreml",
        subdirectory: subdirectory,
        approximateSizeMB: 120,
        cacheDirectory: cacheDirectory,
        source: huggingFace("FluidInference/ls-eend-coreml")
      ),
      officialMetrics: [
        metric(.diarizationErrorRatePercent, diarizationErrorRate, unit: "percent", dataset: dataset, source: lsEendDocs),
        metric(.latencyMilliseconds, 100, unit: "ms", provenance: .modelConfiguration, source: lsEendDocs),
        metric(.maxSpeakers, maxSpeakers, unit: "speakers", provenance: .modelConfiguration, source: lsEendDocs),
      ],
      sources: [modelDocs, lsEendDocs, huggingFace("FluidInference/ls-eend-coreml")],
      notes: [
        "Domain-specialized LS-EEND diarization variant.",
        "FluidAudio docs recommend choosing the variant by recording domain.",
      ]
    )
  }
}
