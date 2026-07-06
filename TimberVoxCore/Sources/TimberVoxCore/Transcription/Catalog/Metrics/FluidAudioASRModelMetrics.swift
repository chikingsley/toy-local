extension FluidAudioModelMetrics {
  static let parakeetTdtV3 = ModelMetricProfile(
    modelID: FluidAudioModels.parakeetTdtV3.id,
    runtime: .localCoreML,
    provider: "FluidAudio / NVIDIA",
    clientName: "ParakeetClient",
    download: download(
      repo: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
      approximateSizeMB: 650,
      cacheDirectory: "FluidAudio/Models/parakeet-tdt-0.6b-v3",
      source: huggingFace("FluidInference/parakeet-tdt-0.6b-v3-coreml")
    ),
    officialMetrics: [
      metric(
        .wordErrorRatePercent, 14.7,
        unit: "percent", dataset: "FLEURS multilingual average",
        hardware: "M4 Pro, macOS Tahoe 26.0", source: benchmarkDocs
      ),
      metric(
        .characterErrorRatePercent, 4.7,
        unit: "percent", dataset: "FLEURS multilingual average",
        hardware: "M4 Pro, macOS Tahoe 26.0", source: benchmarkDocs
      ),
      metric(
        .realTimeFactor, 209.8,
        unit: "x", dataset: "FLEURS multilingual average",
        hardware: "M4 Pro, macOS Tahoe 26.0", source: benchmarkDocs
      ),
      metric(
        .wordErrorRatePercent, 2.5,
        unit: "percent", dataset: "LibriSpeech test-clean",
        hardware: "M4 Pro, macOS Tahoe 26.0", source: benchmarkDocs
      ),
      metric(
        .realTimeFactor, 155.6,
        unit: "x", dataset: "LibriSpeech test-clean",
        hardware: "M4 Pro, macOS Tahoe 26.0", source: benchmarkDocs
      ),
      metric(.parameterCountMillions, 600, unit: "million parameters", provenance: .modelCard, source: modelDocs),
    ],
    sources: [modelDocs, benchmarkDocs, huggingFace("FluidInference/parakeet-tdt-0.6b-v3-coreml")],
    notes: [
      "Default multilingual batch ASR model.",
      "The model card reports roughly 110x RTF on M4 Pro; benchmark docs contain fuller runs.",
    ]
  )

  static let parakeetTdtCtc110m = ModelMetricProfile(
    modelID: FluidAudioModels.parakeetTdtCtc110m.id,
    runtime: .localCoreML,
    provider: "FluidAudio / NVIDIA",
    clientName: "ParakeetClient",
    download: download(
      repo: "FluidInference/parakeet-tdt-ctc-110m-coreml",
      approximateSizeMB: 350,
      cacheDirectory: "FluidAudio/Models/parakeet-tdt-ctc-110m",
      source: huggingFace("FluidInference/parakeet-tdt-ctc-110m-coreml")
    ),
    officialMetrics: [
      metric(
        .wordErrorRatePercent, 3.01,
        unit: "percent", dataset: "LibriSpeech test-clean",
        hardware: "Apple M2", source: tdtCtcDocs
      ),
      metric(
        .characterErrorRatePercent, 1.09,
        unit: "percent", dataset: "LibriSpeech test-clean",
        hardware: "Apple M2", source: tdtCtcDocs
      ),
      metric(
        .realTimeFactor, 96.5,
        unit: "x", dataset: "LibriSpeech test-clean",
        hardware: "Apple M2", source: tdtCtcDocs
      ),
      metric(.parameterCountMillions, 110, unit: "million parameters", provenance: .modelConfiguration, source: modelDocs),
    ],
    sources: [modelDocs, tdtCtcDocs, huggingFace("FluidInference/parakeet-tdt-ctc-110m-coreml")],
    notes: ["English batch ASR model with a fused preprocessor and encoder."]
  )

  static let cohereTranscribe = ModelMetricProfile(
    modelID: FluidAudioModels.cohereTranscribe.id,
    runtime: .localCoreML,
    provider: "FluidAudio / Cohere",
    clientName: "CohereTranscribeClient",
    download: download(
      repo: "FluidInference/cohere-transcribe-03-2026-coreml",
      subdirectory: "q8",
      approximateSizeMB: 2200,
      cacheDirectory: "FluidAudio/Models/cohere-transcribe/q8",
      source: huggingFace("FluidInference/cohere-transcribe-03-2026-coreml")
    ),
    officialMetrics: [
      metric(
        .wordErrorRatePercent, 1.77,
        unit: "percent", dataset: "LibriSpeech test-clean",
        hardware: "Apple M2, macOS Tahoe 26.0", source: cohereDocs
      ),
      metric(
        .characterErrorRatePercent, 0.60,
        unit: "percent", dataset: "LibriSpeech test-clean",
        hardware: "Apple M2, macOS Tahoe 26.0", source: cohereDocs
      ),
      metric(
        .realTimeFactor, 1.72,
        unit: "x", dataset: "LibriSpeech test-clean total audio/compute",
        hardware: "Apple M2, macOS Tahoe 26.0", source: cohereDocs
      ),
      metric(.maxAudioSeconds, 35, unit: "seconds", provenance: .modelConfiguration, source: cohereDocs),
    ],
    sources: [modelDocs, cohereDocs, huggingFace("FluidInference/cohere-transcribe-03-2026-coreml")],
    notes: [
      "Language must be specified explicitly.",
      "Cold ANE compile dominates first run; warm calls are documented separately.",
    ]
  )
}
