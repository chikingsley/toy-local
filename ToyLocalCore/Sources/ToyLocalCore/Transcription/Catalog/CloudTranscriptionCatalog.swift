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

  public static let deepgramNova2Meeting = TranscriptionModelSpec(
    id: "deepgram-nova-2-meeting",
    displayName: "Deepgram Nova 2 Meeting",
    provider: .deepgram,
    runtime: .cloud,
    capabilities: TranscriptionCapabilities(
      batch: true,
      contextBiasing: true,
      diarization: true,
      fileInput: true,
      languageDetection: true,
      languageHint: true,
      segmentTimestamps: true,
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
    deepgramNova2Meeting,
    mistralVoxtralMiniLatest,
  ]

  public static let all: [TranscriptionModelSpec] = batchASR

  public static func model(id: String) -> TranscriptionModelSpec? {
    all.first { $0.id == id }
  }
}
