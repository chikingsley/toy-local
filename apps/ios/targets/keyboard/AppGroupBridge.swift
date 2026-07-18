import Foundation

enum BridgeKey: String, CaseIterable {
  case bridgeSchemaVersion
  case keyboardSeen
  case keyboardHasFullAccess
  case shortcutAvailable
  case activeModeId
  case keyboardHapticsEnabled
  case keyboardSoundEnabled
  case keyboardPredictionsEnabled
  case keyboardAutocorrectEnabled
  case keyboardSwipeEnabled
  case onboardingComplete
  case apiBaseURL
  case apiCredential
  case activeModeSnapshot
  case sessionActive
  case recordingRequested
  case requestRevision
  case requestedEntryPoint
  case activeRequestId
  case keyboardRequestId
  case partialTranscript
  case finalResultId
  case finalRequestId
  case finalTranscript
  case transcriptRevision
  case consumedResultId
  case nativeResultEnvelope
  case nativeResultRevision
  case nativeResultConsumedRevision
}

enum KeyboardBridge {
  static let group = "group.com.chiejimofor.timbervox"
  static let schemaVersion = 3

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: group)
  }

  static func initialize() {
    guard integer(for: .bridgeSchemaVersion) < schemaVersion else { return }
    defaults?.removeObject(forKey: "pendingTranscript")
    remove(.finalResultId)
    remove(.finalRequestId)
    remove(.finalTranscript)
    remove(.consumedResultId)
    set(schemaVersion, for: .bridgeSchemaVersion)
    seed(true, for: .keyboardHapticsEnabled)
    seed(true, for: .keyboardSoundEnabled)
    seed(true, for: .keyboardPredictionsEnabled)
    seed(true, for: .keyboardAutocorrectEnabled)
    seed(true, for: .keyboardSwipeEnabled)
  }

  static func bool(for key: BridgeKey) -> Bool {
    defaults?.bool(forKey: key.rawValue) ?? false
  }

  static func integer(for key: BridgeKey) -> Int {
    defaults?.integer(forKey: key.rawValue) ?? 0
  }

  static func string(for key: BridgeKey) -> String? {
    defaults?.string(forKey: key.rawValue)
  }

  static func set(_ value: Bool, for key: BridgeKey) {
    defaults?.set(value, forKey: key.rawValue)
  }

  static func set(_ value: Int, for key: BridgeKey) {
    defaults?.set(value, forKey: key.rawValue)
  }

  static func set(_ value: String, for key: BridgeKey) {
    defaults?.set(value, forKey: key.rawValue)
  }

  static func remove(_ key: BridgeKey) {
    defaults?.removeObject(forKey: key.rawValue)
  }

  private static func seed(_ value: Bool, for key: BridgeKey) {
    guard defaults?.object(forKey: key.rawValue) == nil else { return }
    set(value, for: key)
  }
}
