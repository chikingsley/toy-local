import ActivityKit
import AppIntents
import Foundation

enum TimberVoxNativeBridge {
  static let appGroup = "group.com.chiejimofor.timbervox"
  static let schemaVersion = 3

  static var defaults: UserDefaults {
    guard let defaults = UserDefaults(suiteName: appGroup) else {
      preconditionFailure("TimberVox App Group is unavailable")
    }
    return defaults
  }

  static func publishStopRequest() {
    defaults.set(false, forKey: "recordingRequested")
    defaults.set(defaults.integer(forKey: "requestRevision") + 1, forKey: "requestRevision")
  }
}

struct TimberVoxNativeModeSnapshot: Codable, Hashable, Sendable {
  let asrModelId: String
  let batchModelId: String
  let description: String
  let iconKey: String
  let id: String
  let identifySpeakers: Bool
  let language: String?
  let name: String
  let presetKind: String
  let processingInstructions: String?
  let processingModelId: String?
  let realtimeModel: String

  static let fallback = TimberVoxNativeModeSnapshot(
    asrModelId: "mistral-voxtral-mini-latest",
    batchModelId: "mistral-voxtral-mini-latest",
    description: "Turn your voice into punctuated text with no AI post-processing.",
    iconKey: "person.wave.2.fill",
    id: "mode_voice_default",
    identifySpeakers: false,
    language: nil,
    name: "Voice to Text",
    presetKind: "voice",
    processingInstructions: nil,
    processingModelId: nil,
    realtimeModel: "mistral-voxtral-mini-transcribe-realtime-2602"
  )

  static func active(from defaults: UserDefaults) -> TimberVoxNativeModeSnapshot {
    guard let value = defaults.string(forKey: "activeModeSnapshot"),
      let data = value.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(Self.self, from: data)
    else { return fallback }
    return decoded
  }
}

struct TimberVoxRecordingAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let phase: String
  }

  let modeName: String
  let requestId: String
  let startedAt: Date
}

struct StopTimberVoxRecordingIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Stop TimberVox Recording"
  static let description = IntentDescription("Finish the active TimberVox dictation.")
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    TimberVoxNativeBridge.publishStopRequest()
    return .result()
  }
}
