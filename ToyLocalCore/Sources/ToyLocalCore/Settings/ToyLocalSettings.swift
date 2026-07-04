import Foundation

public enum RecordingAudioBehavior: String, Codable, CaseIterable, Equatable, Sendable {
  case pauseMedia
  case mute
  case doNothing
}

public enum RecordingInputMode: String, Codable, CaseIterable, Equatable, Sendable {
  case microphone
  case systemAudio

  public var displayName: String {
    switch self {
    case .microphone:
      "Microphone"
    case .systemAudio:
      "System Audio"
    }
  }
}

public enum TextTransformMode: String, Codable, CaseIterable, Equatable, Sendable {
  case voiceToText = "voice_to_text"
  case superPrompt = "super"
  case messagePrompt = "message"
  case notePrompt = "note"
  case emailPrompt = "email"
  case meetingPrompt = "meeting"
  case customPrompt = "custom"

  public var displayName: String {
    switch self {
    case .voiceToText:
      "Voice to Text"
    case .superPrompt:
      "Super"
    case .messagePrompt:
      "Message"
    case .notePrompt:
      "Note"
    case .emailPrompt:
      "Email"
    case .meetingPrompt:
      "Meeting"
    case .customPrompt:
      "Custom"
    }
  }

  public var usesTextTransform: Bool {
    self != .voiceToText
  }

  public var presetID: TextTransformPresetID? {
    switch self {
    case .voiceToText:
      nil
    case .superPrompt:
      .superPrompt
    case .messagePrompt:
      .messagePrompt
    case .notePrompt:
      .notePrompt
    case .emailPrompt:
      .emailPrompt
    case .meetingPrompt:
      .meetingPrompt
    case .customPrompt:
      .customPrompt
    }
  }
}

/// User-configurable settings saved to disk.
public struct ToyLocalSettings: Codable, Equatable, Sendable {
  public static let defaultPasteLastTranscriptHotkey = HotKey(key: .v, modifiers: [.option, .shift])
  public static let baseSoundEffectsVolume: Double = ToyLocalCoreConstants.baseSoundEffectsVolume
  public static let defaultTextTransformModel = CloudLanguageModels.defaultModel.id
  public static let defaultTextTransformContextOptions = DictationContextOptions(
    includeApplicationContext: true,
    includeSelectionContext: true,
    includeClipboardContext: true
  )
  public static let defaultWordRemovals: [WordRemoval] = [
    .init(pattern: "uh+"),
    .init(pattern: "um+"),
    .init(pattern: "er+"),
    .init(pattern: "hm+"),
  ]

  public static var defaultPasteLastTranscriptHotkeyDescription: String {
    let modifiers = defaultPasteLastTranscriptHotkey.modifiers.sorted.map { $0.stringValue }.joined()
    let key = defaultPasteLastTranscriptHotkey.key?.toString ?? ""
    return modifiers + key
  }

  public var soundEffectsEnabled: Bool
  public var soundEffectsVolume: Double
  public var hotkey: HotKey
  public var openOnLogin: Bool
  public var showDockIcon: Bool
  public var selectedModel: String
  public var localModelPrewarmEnabled: Bool
  public var useClipboardPaste: Bool
  public var preventSystemSleep: Bool
  public var recordingAudioBehavior: RecordingAudioBehavior
  public var recordingInputMode: RecordingInputMode
  public var minimumKeyTime: Double
  public var copyToClipboard: Bool
  public var useDoubleTapOnly: Bool
  public var outputLanguage: String?
  public var selectedMicrophoneID: String?
  public var saveTranscriptionHistory: Bool
  public var maxHistoryEntries: Int?
  public var pasteLastTranscriptHotkey: HotKey?
  public var hasCompletedModelBootstrap: Bool
  public var wordRemovalsEnabled: Bool
  public var wordRemovals: [WordRemoval]
  public var wordRemappings: [WordRemapping]
  public var alwaysOnEnabled: Bool
  public var alwaysOnPasteHotkey: HotKey?
  public var alwaysOnDumpHotkey: HotKey?
  public var alwaysOnStreamingModel: String
  public var textTransformMode: TextTransformMode
  public var textTransformModel: String
  public var customTextTransformInstructions: String
  public var textTransformContextOptions: DictationContextOptions

  public init(
    soundEffectsEnabled: Bool = true,
    soundEffectsVolume: Double = ToyLocalSettings.baseSoundEffectsVolume,
    hotkey: HotKey = .init(key: nil, modifiers: [.option]),
    openOnLogin: Bool = false,
    showDockIcon: Bool = true,
    selectedModel: String = FluidAudioModels.parakeetTdtV3.id,
    localModelPrewarmEnabled: Bool = true,
    useClipboardPaste: Bool = true,
    preventSystemSleep: Bool = true,
    recordingAudioBehavior: RecordingAudioBehavior = .doNothing,
    recordingInputMode: RecordingInputMode = .microphone,
    minimumKeyTime: Double = ToyLocalCoreConstants.defaultMinimumKeyTime,
    copyToClipboard: Bool = false,
    useDoubleTapOnly: Bool = false,
    outputLanguage: String? = nil,
    selectedMicrophoneID: String? = nil,
    saveTranscriptionHistory: Bool = true,
    maxHistoryEntries: Int? = nil,
    pasteLastTranscriptHotkey: HotKey? = ToyLocalSettings.defaultPasteLastTranscriptHotkey,
    hasCompletedModelBootstrap: Bool = false,
    wordRemovalsEnabled: Bool = false,
    wordRemovals: [WordRemoval] = ToyLocalSettings.defaultWordRemovals,
    wordRemappings: [WordRemapping] = [],
    alwaysOnEnabled: Bool = false,
    alwaysOnPasteHotkey: HotKey? = HotKey(key: nil, modifiers: [.fn]),
    alwaysOnDumpHotkey: HotKey? = nil,
    alwaysOnStreamingModel: String = FluidAudioModels.parakeetEou160.id,
    textTransformMode: TextTransformMode = .voiceToText,
    textTransformModel: String = ToyLocalSettings.defaultTextTransformModel,
    customTextTransformInstructions: String = TextTransformPreset.defaultCustomInstructions,
    textTransformContextOptions: DictationContextOptions = ToyLocalSettings.defaultTextTransformContextOptions
  ) {
    self.soundEffectsEnabled = soundEffectsEnabled
    self.soundEffectsVolume = soundEffectsVolume
    self.hotkey = hotkey
    self.openOnLogin = openOnLogin
    self.showDockIcon = showDockIcon
    self.selectedModel = selectedModel
    self.localModelPrewarmEnabled = localModelPrewarmEnabled
    self.useClipboardPaste = useClipboardPaste
    self.preventSystemSleep = preventSystemSleep
    self.recordingAudioBehavior = recordingAudioBehavior
    self.recordingInputMode = recordingInputMode
    self.minimumKeyTime = minimumKeyTime
    self.copyToClipboard = copyToClipboard
    self.useDoubleTapOnly = useDoubleTapOnly
    self.outputLanguage = outputLanguage
    self.selectedMicrophoneID = selectedMicrophoneID
    self.saveTranscriptionHistory = saveTranscriptionHistory
    self.maxHistoryEntries = maxHistoryEntries
    self.pasteLastTranscriptHotkey = pasteLastTranscriptHotkey
    self.hasCompletedModelBootstrap = hasCompletedModelBootstrap
    self.wordRemovalsEnabled = wordRemovalsEnabled
    self.wordRemovals = wordRemovals
    self.wordRemappings = wordRemappings
    self.alwaysOnEnabled = alwaysOnEnabled
    self.alwaysOnPasteHotkey = alwaysOnPasteHotkey
    self.alwaysOnDumpHotkey = alwaysOnDumpHotkey
    self.alwaysOnStreamingModel = alwaysOnStreamingModel
    self.textTransformMode = textTransformMode
    self.textTransformModel = textTransformModel
    self.customTextTransformInstructions = customTextTransformInstructions
    self.textTransformContextOptions = textTransformContextOptions
  }

  public init(from decoder: Decoder) throws {
    self.init()
    let container = try decoder.container(keyedBy: ToyLocalSettingKey.self)
    for field in ToyLocalSettingsSchema.fields {
      try field.decode(into: &self, from: container)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: ToyLocalSettingKey.self)
    for field in ToyLocalSettingsSchema.fields {
      try field.encode(self, into: &container)
    }
  }
}

// MARK: - Schema

private enum ToyLocalSettingKey: String, CodingKey, CaseIterable {
  case soundEffectsEnabled
  case soundEffectsVolume
  case hotkey
  case openOnLogin
  case showDockIcon
  case selectedModel
  case localModelPrewarmEnabled
  case useClipboardPaste
  case preventSystemSleep
  case recordingAudioBehavior
  case recordingInputMode
  case minimumKeyTime
  case copyToClipboard
  case useDoubleTapOnly
  case outputLanguage
  case selectedMicrophoneID
  case saveTranscriptionHistory
  case maxHistoryEntries
  case pasteLastTranscriptHotkey
  case hasCompletedModelBootstrap
  case wordRemovalsEnabled
  case wordRemovals
  case wordRemappings
  case alwaysOnEnabled
  case alwaysOnPasteHotkey
  case alwaysOnDumpHotkey
  case alwaysOnStreamingModel
  case textTransformMode
  case textTransformModel
  case customTextTransformInstructions
  case textTransformContextOptions
}

private struct SettingsField<Value: Codable & Sendable> {
  let key: ToyLocalSettingKey
  let keyPath: WritableKeyPath<ToyLocalSettings, Value>
  let defaultValue: Value
  let decodeStrategy: (KeyedDecodingContainer<ToyLocalSettingKey>, ToyLocalSettingKey, Value) throws -> Value
  let encodeStrategy: (inout KeyedEncodingContainer<ToyLocalSettingKey>, ToyLocalSettingKey, Value) throws -> Void

  init(
    _ key: ToyLocalSettingKey,
    keyPath: WritableKeyPath<ToyLocalSettings, Value>,
    default defaultValue: Value,
    decode: ((KeyedDecodingContainer<ToyLocalSettingKey>, ToyLocalSettingKey, Value) throws -> Value)? = nil,
    encode: ((inout KeyedEncodingContainer<ToyLocalSettingKey>, ToyLocalSettingKey, Value) throws -> Void)? = nil
  ) {
    self.key = key
    self.keyPath = keyPath
    self.defaultValue = defaultValue
    self.decodeStrategy =
      decode ?? { container, key, defaultValue in
        try container.decodeIfPresent(Value.self, forKey: key) ?? defaultValue
      }
    self.encodeStrategy =
      encode ?? { container, key, value in
        try container.encode(value, forKey: key)
      }
  }

  func eraseToAny() -> AnySettingsField {
    AnySettingsField(
      key: key,
      decode: { container, settings in
        let value = try decodeStrategy(container, key, defaultValue)
        settings[keyPath: keyPath] = value
      },
      encode: { settings, container in
        let value = settings[keyPath: keyPath]
        try encodeStrategy(&container, key, value)
      }
    )
  }
}

private struct AnySettingsField {
  let key: ToyLocalSettingKey
  let decode: (KeyedDecodingContainer<ToyLocalSettingKey>, inout ToyLocalSettings) throws -> Void
  let encode: (ToyLocalSettings, inout KeyedEncodingContainer<ToyLocalSettingKey>) throws -> Void

  func decode(into settings: inout ToyLocalSettings, from container: KeyedDecodingContainer<ToyLocalSettingKey>) throws {
    try decode(container, &settings)
  }

  func encode(_ settings: ToyLocalSettings, into container: inout KeyedEncodingContainer<ToyLocalSettingKey>) throws {
    try encode(settings, &container)
  }
}

private enum ToyLocalSettingsSchema {
  static let defaults = ToyLocalSettings()

  nonisolated(unsafe) static let fields: [AnySettingsField] = [
    SettingsField(.soundEffectsEnabled, keyPath: \.soundEffectsEnabled, default: defaults.soundEffectsEnabled).eraseToAny(),
    SettingsField(.soundEffectsVolume, keyPath: \.soundEffectsVolume, default: defaults.soundEffectsVolume).eraseToAny(),
    SettingsField(.hotkey, keyPath: \.hotkey, default: defaults.hotkey).eraseToAny(),
    SettingsField(.openOnLogin, keyPath: \.openOnLogin, default: defaults.openOnLogin).eraseToAny(),
    SettingsField(.showDockIcon, keyPath: \.showDockIcon, default: defaults.showDockIcon).eraseToAny(),
    SettingsField(.selectedModel, keyPath: \.selectedModel, default: defaults.selectedModel).eraseToAny(),
    SettingsField(
      .localModelPrewarmEnabled,
      keyPath: \.localModelPrewarmEnabled,
      default: defaults.localModelPrewarmEnabled
    ).eraseToAny(),
    SettingsField(.useClipboardPaste, keyPath: \.useClipboardPaste, default: defaults.useClipboardPaste).eraseToAny(),
    SettingsField(.preventSystemSleep, keyPath: \.preventSystemSleep, default: defaults.preventSystemSleep).eraseToAny(),
    SettingsField(.recordingAudioBehavior, keyPath: \.recordingAudioBehavior, default: defaults.recordingAudioBehavior).eraseToAny(),
    SettingsField(.recordingInputMode, keyPath: \.recordingInputMode, default: defaults.recordingInputMode).eraseToAny(),
    SettingsField(.minimumKeyTime, keyPath: \.minimumKeyTime, default: defaults.minimumKeyTime).eraseToAny(),
    SettingsField(.copyToClipboard, keyPath: \.copyToClipboard, default: defaults.copyToClipboard).eraseToAny(),
    SettingsField(.useDoubleTapOnly, keyPath: \.useDoubleTapOnly, default: defaults.useDoubleTapOnly).eraseToAny(),
    // swiftlint:disable trailing_closure
    SettingsField(
      .outputLanguage,
      keyPath: \.outputLanguage,
      default: defaults.outputLanguage,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    SettingsField(
      .selectedMicrophoneID,
      keyPath: \.selectedMicrophoneID,
      default: defaults.selectedMicrophoneID,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    SettingsField(.saveTranscriptionHistory, keyPath: \.saveTranscriptionHistory, default: defaults.saveTranscriptionHistory).eraseToAny(),
    SettingsField(
      .maxHistoryEntries,
      keyPath: \.maxHistoryEntries,
      default: defaults.maxHistoryEntries,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    SettingsField(
      .pasteLastTranscriptHotkey,
      keyPath: \.pasteLastTranscriptHotkey,
      default: defaults.pasteLastTranscriptHotkey,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    SettingsField(.hasCompletedModelBootstrap, keyPath: \.hasCompletedModelBootstrap, default: defaults.hasCompletedModelBootstrap).eraseToAny(),
    SettingsField(.wordRemovalsEnabled, keyPath: \.wordRemovalsEnabled, default: defaults.wordRemovalsEnabled).eraseToAny(),
    SettingsField(
      .wordRemovals,
      keyPath: \.wordRemovals,
      default: defaults.wordRemovals
    ).eraseToAny(),
    SettingsField(
      .wordRemappings,
      keyPath: \.wordRemappings,
      default: defaults.wordRemappings
    ).eraseToAny(),
    SettingsField(.alwaysOnEnabled, keyPath: \.alwaysOnEnabled, default: defaults.alwaysOnEnabled).eraseToAny(),
    SettingsField(
      .alwaysOnPasteHotkey,
      keyPath: \.alwaysOnPasteHotkey,
      default: defaults.alwaysOnPasteHotkey,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    SettingsField(
      .alwaysOnDumpHotkey,
      keyPath: \.alwaysOnDumpHotkey,
      default: defaults.alwaysOnDumpHotkey,
      encode: { container, key, value in
        try container.encodeIfPresent(value, forKey: key)
      }
    ).eraseToAny(),
    // swiftlint:enable trailing_closure
    SettingsField(.alwaysOnStreamingModel, keyPath: \.alwaysOnStreamingModel, default: defaults.alwaysOnStreamingModel).eraseToAny(),
    SettingsField(.textTransformMode, keyPath: \.textTransformMode, default: defaults.textTransformMode).eraseToAny(),
    SettingsField(.textTransformModel, keyPath: \.textTransformModel, default: defaults.textTransformModel).eraseToAny(),
    SettingsField(
      .customTextTransformInstructions,
      keyPath: \.customTextTransformInstructions,
      default: defaults.customTextTransformInstructions
    ).eraseToAny(),
    SettingsField(
      .textTransformContextOptions,
      keyPath: \.textTransformContextOptions,
      default: defaults.textTransformContextOptions
    ).eraseToAny(),
  ]
}
