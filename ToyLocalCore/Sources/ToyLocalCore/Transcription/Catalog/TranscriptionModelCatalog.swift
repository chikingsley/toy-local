import Foundation

public enum TranscriptionModelCatalog {
  public static let local: [TranscriptionModelSpec] = FluidAudioModels.transcriptionModels
  public static let cloud: [TranscriptionModelSpec] =
    CloudTranscriptionModels.all + CloudRealtimeTranscriptionModels.all
  public static let all: [TranscriptionModelSpec] = local + cloud

  public static let userSelectableASR: [TranscriptionModelSpec] = all.filter {
    $0.assetRole == .primaryASR
  }

  public static func model(id: String) -> TranscriptionModelSpec? {
    all.first { $0.id == id }
  }

  public static func isSupportedModel(_ id: String) -> Bool {
    model(id: id) != nil
  }
}
