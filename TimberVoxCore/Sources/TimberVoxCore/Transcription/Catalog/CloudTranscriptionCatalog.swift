import Foundation

public enum CloudTranscriptionModels {
  public static let deepgramNova3 = TranscriptionModelSpec(
    id: "deepgram-nova-3",
    displayName: "Deepgram Nova 3",
    provider: .deepgram,
    runtime: .cloud,
    capabilities: TranscriptionCapabilities(
      batch: true,
      contextBiasing: true,
      diarization: true,
      fileInput: true,
      languageDetection: true,
      languageHint: true,
      partialResults: true,
      realtime: true,
      segmentTimestamps: true,
      streamingInput: true,
      voiceActivityDetection: true,
      wordTimestamps: true
    )
  )

  public static let deepgramNova2 = TranscriptionModelSpec(
    id: "deepgram-nova-2",
    displayName: "Deepgram Nova 2",
    provider: .deepgram,
    runtime: .cloud,
    capabilities: TranscriptionCapabilities(
      batch: true,
      contextBiasing: true,
      diarization: true,
      fileInput: true,
      languageDetection: true,
      languageHint: true,
      partialResults: true,
      realtime: true,
      segmentTimestamps: true,
      streamingInput: true,
      voiceActivityDetection: true,
      wordTimestamps: true
    )
  )

  public static let mistralVoxtralMiniLatest = TranscriptionModelSpec(
    id: "mistral-voxtral-mini-latest",
    displayName: "Mistral Voxtral Mini",
    provider: .mistral,
    runtime: .cloud,
    capabilities: TranscriptionCapabilities(
      batch: true,
      fileInput: true,
      languageDetection: true,
      languageHint: true,
      segmentTimestamps: true
    )
  )

  public static let batchASR: [TranscriptionModelSpec] = [
    deepgramNova3,
    deepgramNova2,
    mistralVoxtralMiniLatest,
  ]

  public static let all: [TranscriptionModelSpec] = batchASR

  public static func model(id: String) -> TranscriptionModelSpec? {
    all.first { $0.id == id }
  }
}
