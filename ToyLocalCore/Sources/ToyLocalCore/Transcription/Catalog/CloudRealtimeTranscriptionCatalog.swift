import Foundation

public enum CloudRealtimeTranscriptionModels {
  public static let mistralVoxtralMiniRealtime = TranscriptionModelSpec(
    id: "mistral-voxtral-mini-transcribe-realtime-2602",
    displayName: "Mistral Voxtral Mini Realtime",
    provider: .mistral,
    runtime: .cloud,
    capabilities: TranscriptionCapabilities(
      languageDetection: true,
      languageHint: true,
      partialResults: true,
      realtime: true,
      streamingInput: true,
      wordTimestamps: true
    )
  )

  public static let all: [TranscriptionModelSpec] = [
    mistralVoxtralMiniRealtime
  ]

  public static func model(id: String) -> TranscriptionModelSpec? {
    all.first { $0.id == id }
  }
}
