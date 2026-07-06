import Foundation

// MARK: - Schema

enum TimberVoxSettingKey: String, CodingKey, CaseIterable {
  case soundEffectsEnabled
  case soundEffectsVolume
  case hotkey
  case openOnLogin
  case showDockIcon
  case selectedModel
  case localModelPrewarmEnabled
  case superFastModeEnabled
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
  case appearancePreference
  case recordingRetention
  case clipboardRestoreBehavior
  case startRecordingOnMenubarClick
  case alwaysCloseRecordingWindow
  case autoPasteResult
  case holdShiftToAutoSend
  case voiceModelActiveDurationMinutes
  case showExperimentalModels
  case errorLoggingEnabled
  case autoIncreaseMicrophoneVolume
  case silenceRemovalEnabled
  case dynamicNormalizationEnabled
  case soundEffectsStyle
}

struct SettingsField<Value: Codable & Sendable> {
  let key: TimberVoxSettingKey
  let keyPath: WritableKeyPath<TimberVoxSettings, Value>
  let defaultValue: Value
  let decodeStrategy: (KeyedDecodingContainer<TimberVoxSettingKey>, TimberVoxSettingKey, Value) throws -> Value
  let encodeStrategy: (inout KeyedEncodingContainer<TimberVoxSettingKey>, TimberVoxSettingKey, Value) throws -> Void

  init(
    _ key: TimberVoxSettingKey,
    keyPath: WritableKeyPath<TimberVoxSettings, Value>,
    default defaultValue: Value,
    decode: ((KeyedDecodingContainer<TimberVoxSettingKey>, TimberVoxSettingKey, Value) throws -> Value)? = nil,
    encode: ((inout KeyedEncodingContainer<TimberVoxSettingKey>, TimberVoxSettingKey, Value) throws -> Void)? = nil
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

struct AnySettingsField {
  let key: TimberVoxSettingKey
  let decode: (KeyedDecodingContainer<TimberVoxSettingKey>, inout TimberVoxSettings) throws -> Void
  let encode: (TimberVoxSettings, inout KeyedEncodingContainer<TimberVoxSettingKey>) throws -> Void

  func decode(into settings: inout TimberVoxSettings, from container: KeyedDecodingContainer<TimberVoxSettingKey>) throws {
    try decode(container, &settings)
  }

  func encode(_ settings: TimberVoxSettings, into container: inout KeyedEncodingContainer<TimberVoxSettingKey>) throws {
    try encode(settings, &container)
  }
}

enum TimberVoxSettingsSchema {
  static let defaults = TimberVoxSettings()

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
    SettingsField(.superFastModeEnabled, keyPath: \.superFastModeEnabled, default: defaults.superFastModeEnabled).eraseToAny(),
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
    SettingsField(.appearancePreference, keyPath: \.appearancePreference, default: defaults.appearancePreference)
      .eraseToAny(),
    SettingsField(.recordingRetention, keyPath: \.recordingRetention, default: defaults.recordingRetention)
      .eraseToAny(),
    SettingsField(
      .clipboardRestoreBehavior,
      keyPath: \.clipboardRestoreBehavior,
      default: defaults.clipboardRestoreBehavior
    ).eraseToAny(),
    SettingsField(
      .startRecordingOnMenubarClick,
      keyPath: \.startRecordingOnMenubarClick,
      default: defaults.startRecordingOnMenubarClick
    ).eraseToAny(),
    SettingsField(
      .alwaysCloseRecordingWindow,
      keyPath: \.alwaysCloseRecordingWindow,
      default: defaults.alwaysCloseRecordingWindow
    ).eraseToAny(),
    SettingsField(.autoPasteResult, keyPath: \.autoPasteResult, default: defaults.autoPasteResult).eraseToAny(),
    SettingsField(.holdShiftToAutoSend, keyPath: \.holdShiftToAutoSend, default: defaults.holdShiftToAutoSend)
      .eraseToAny(),
    SettingsField(
      .voiceModelActiveDurationMinutes,
      keyPath: \.voiceModelActiveDurationMinutes,
      default: defaults.voiceModelActiveDurationMinutes
    ).eraseToAny(),
    SettingsField(
      .showExperimentalModels,
      keyPath: \.showExperimentalModels,
      default: defaults.showExperimentalModels
    ).eraseToAny(),
    SettingsField(.errorLoggingEnabled, keyPath: \.errorLoggingEnabled, default: defaults.errorLoggingEnabled)
      .eraseToAny(),
    SettingsField(
      .autoIncreaseMicrophoneVolume,
      keyPath: \.autoIncreaseMicrophoneVolume,
      default: defaults.autoIncreaseMicrophoneVolume
    ).eraseToAny(),
    SettingsField(
      .silenceRemovalEnabled,
      keyPath: \.silenceRemovalEnabled,
      default: defaults.silenceRemovalEnabled
    ).eraseToAny(),
    SettingsField(
      .dynamicNormalizationEnabled,
      keyPath: \.dynamicNormalizationEnabled,
      default: defaults.dynamicNormalizationEnabled
    ).eraseToAny(),
    SettingsField(.soundEffectsStyle, keyPath: \.soundEffectsStyle, default: defaults.soundEffectsStyle)
      .eraseToAny(),
  ]
}
