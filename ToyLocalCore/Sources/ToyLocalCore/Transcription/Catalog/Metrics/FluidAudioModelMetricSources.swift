extension FluidAudioModelMetrics {
  static let modelDocs = ModelMetricSource(
    title: "FluidAudio Models",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Models.md",
    sourceType: .fluidAudioDocumentation
  )

  static let benchmarkDocs = ModelMetricSource(
    title: "FluidAudio Benchmarks",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md",
    sourceType: .fluidAudioDocumentation
  )

  static let tdtCtcDocs = ModelMetricSource(
    title: "FluidAudio Parakeet TDT-CTC-110M",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/TDT-CTC-110M.md",
    sourceType: .fluidAudioDocumentation
  )

  static let cohereDocs = ModelMetricSource(
    title: "FluidAudio Cohere Transcribe",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/Cohere.md",
    sourceType: .fluidAudioDocumentation
  )

  static let nemotronDocs = ModelMetricSource(
    title: "FluidAudio Nemotron Streaming",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/Nemotron.md",
    sourceType: .fluidAudioDocumentation
  )

  static let nemotronMultilingualDocs = ModelMetricSource(
    title: "FluidAudio Nemotron Multilingual Streaming",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/NemotronMultilingual.md",
    sourceType: .fluidAudioDocumentation
  )

  static let customVocabularyDocs = ModelMetricSource(
    title: "FluidAudio Custom Vocabulary",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/CustomVocabulary.md",
    sourceType: .fluidAudioDocumentation
  )

  static let vadDocs = ModelMetricSource(
    title: "FluidAudio VAD Getting Started",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/VAD/GettingStarted.md",
    sourceType: .fluidAudioDocumentation
  )

  static let sortformerDocs = ModelMetricSource(
    title: "FluidAudio Sortformer Diarization",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Diarization/Sortformer.md",
    sourceType: .fluidAudioDocumentation
  )

  static let lsEendDocs = ModelMetricSource(
    title: "FluidAudio LS-EEND Diarization",
    url: "https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Diarization/LS-EEND.md",
    sourceType: .fluidAudioDocumentation
  )

  static let sortformerCard = ModelMetricSource(
    title: "FluidInference Sortformer CoreML model card",
    url: "https://huggingface.co/FluidInference/diar-streaming-sortformer-coreml",
    sourceType: .huggingFaceModelCard
  )

  static func huggingFace(_ repo: String) -> ModelMetricSource {
    ModelMetricSource(
      title: "\(repo) model card",
      url: "https://huggingface.co/\(repo)",
      sourceType: .huggingFaceModelCard
    )
  }

  static func metric(
    _ name: PublishedMetricName,
    _ value: Double,
    unit: String,
    dataset: String? = nil,
    hardware: String? = nil,
    provenance: ModelMetricProvenance = .fluidAudioBenchmark,
    source: ModelMetricSource,
    note: String? = nil
  ) -> PublishedModelMetric {
    PublishedModelMetric(
      name: name,
      value: value,
      unit: unit,
      dataset: dataset,
      hardware: hardware,
      provenance: provenance,
      source: source,
      note: note
    )
  }

  static func download(
    repo: String?,
    subdirectory: String? = nil,
    approximateSizeMB: Double? = nil,
    cacheDirectory: String? = nil,
    source: ModelMetricSource,
    note: String? = nil
  ) -> ModelDownloadProfile {
    ModelDownloadProfile(
      repository: repo,
      subdirectory: subdirectory,
      requiresHuggingFaceToken: false,
      approximateSizeMB: approximateSizeMB,
      cacheDirectory: cacheDirectory,
      source: source,
      note: note
    )
  }
}
