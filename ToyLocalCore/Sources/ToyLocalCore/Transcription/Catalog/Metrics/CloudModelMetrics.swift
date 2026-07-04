import Foundation

public enum CloudModelMetrics {
  public static let profiles: [ModelMetricProfile] =
    transcriptionProfiles + languageProfiles

  public static func profile(for modelID: String) -> ModelMetricProfile? {
    profiles.first { $0.modelID == modelID }
  }

  private static let transcriptionProfiles: [ModelMetricProfile] =
    TranscriptionModelCatalog.cloud.map {
      cloudProfile(
        modelID: $0.id,
        provider: $0.provider.rawValue,
        note: "Cloud transcription availability is curated by Toy Local Cloud."
      )
    }

  private static let languageProfiles: [ModelMetricProfile] =
    CloudLanguageModels.all.map {
      cloudProfile(
        modelID: $0.id,
        provider: $0.provider.rawValue,
        note: "Cloud language-model availability is curated by Toy Local Cloud."
      )
    }

  private static let registrySource = ModelMetricSource(
    title: "Toy Local Cloud model routes",
    url: "ToyLocalCloudflareApi/src/ai/model-routes.ts",
    sourceType: .toyLocalCloudRegistry
  )

  private static func cloudProfile(
    modelID: String,
    provider: String,
    note: String
  ) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .cloud,
      provider: provider,
      clientName: "ToyLocalCloudClient",
      download: nil,
      sources: [registrySource],
      notes: [
        note,
        "Provider routing and upstream model strings stay behind the Toy Local Cloud API.",
        "No local speed or quality benchmark is recorded for this cloud model yet.",
      ]
    )
  }
}
