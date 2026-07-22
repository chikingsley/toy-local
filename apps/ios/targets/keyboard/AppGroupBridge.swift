import Foundation

enum BridgeKey: String, CaseIterable {
  case bridgeSchemaVersion
  case keyboardSeen
  case keyboardHasFullAccess
  case keyboardStatusRevision
  case keyboardVerificationRequired
  case shortcutAvailable
  case activeModeId
  case keyboardHapticsEnabled
  case keyboardSoundEnabled
  case keyboardPredictionsEnabled
  case keyboardAutocorrectEnabled
  case keyboardSwipeEnabled
  case keyboardPersonalVocabulary
  case keyboardPersonalVocabularyRevision
  case liveActivityDisplayMode
  case streamingInsertionEnabled
  case swipeDecoderStatus
  case onboardingComplete
  case apiBaseURL
  case apiCredential
  case activeModeSnapshot
  case sessionActive
  case sessionOwner
  case sessionPhase
  case sessionErrorMessage
  case sessionHeartbeat
  case sessionStopRequested
  case sessionRevision
  case recordingRequested
  case requestRevision
  case requestedEntryPoint
  case activeRequestId
  case keyboardRequestId
  case partialTranscript
  case partialTranscriptRequestId
  case partialTranscriptRevision
  case finalResultId
  case finalRequestId
  case finalTranscript
  case finalResultStatus
  case transcriptRevision
  case consumedResultId
  case nativeResultEnvelope
  case nativeResultRevision
  case nativeResultConsumedRevision
}

enum KeyboardStatusNotifier {
  private static let fullAccessName = "studio.peacockery.timbervox.keyboard.full-access"
  private static let restrictedName = "studio.peacockery.timbervox.keyboard.restricted"

  static func post(hasFullAccess: Bool) {
    let name = hasFullAccess ? fullAccessName : restrictedName
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(name as CFString),
      nil,
      nil,
      true
    )
  }
}

enum KeyboardBridge {
  static let group = "group.studio.peacockery.timbervox"
  static let schemaVersion = 5

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: group)
  }

  static func initialize() {
    guard integer(for: .bridgeSchemaVersion) < schemaVersion else { return }
    defaults?.removeObject(forKey: "pendingTranscript")
    remove(.finalResultId)
    remove(.finalRequestId)
    remove(.finalTranscript)
    remove(.finalResultStatus)
    remove(.consumedResultId)
    remove(.sessionActive)
    remove(.sessionOwner)
    remove(.sessionPhase)
    remove(.sessionErrorMessage)
    remove(.sessionHeartbeat)
    remove(.sessionStopRequested)
    remove(.sessionRevision)
    remove(.recordingRequested)
    set(schemaVersion, for: .bridgeSchemaVersion)
    seed(true, for: .keyboardHapticsEnabled)
    seed(true, for: .keyboardSoundEnabled)
    seed(true, for: .keyboardPredictionsEnabled)
    seed(true, for: .keyboardAutocorrectEnabled)
    seed(true, for: .keyboardSwipeEnabled)
    seed("waveform", for: .liveActivityDisplayMode)
    seed(false, for: .streamingInsertionEnabled)
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

  static func synchronize() {
    defaults?.synchronize()
  }

  private static func seed(_ value: Bool, for key: BridgeKey) {
    guard defaults?.object(forKey: key.rawValue) == nil else { return }
    set(value, for: key)
  }

  private static func seed(_ value: String, for key: BridgeKey) {
    guard defaults?.object(forKey: key.rawValue) == nil else { return }
    set(value, for: key)
  }
}
