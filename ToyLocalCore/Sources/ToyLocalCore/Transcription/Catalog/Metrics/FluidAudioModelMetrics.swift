public enum FluidAudioModelMetrics {
  public static let profiles: [ModelMetricProfile] = [
    parakeetTdtV3,
    parakeetTdtCtc110m,
    cohereTranscribe,
    parakeetEou160,
    parakeetEou320,
    parakeetEou1280,
    nemotron560,
    nemotron1120,
    nemotron2240,
    nemotronMultilingual560,
    nemotronMultilingual1120,
    nemotronMultilingual2240,
    customVocabularyCtc110m,
    sileroVad,
    sortformer,
    lsEendAmi,
    lsEendCallHome,
    lsEendDihard2,
    lsEendDihard3,
  ]

  public static func profile(for modelID: String) -> ModelMetricProfile? {
    profilesByID[modelID]
  }

  private static let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.modelID, $0) })
}
