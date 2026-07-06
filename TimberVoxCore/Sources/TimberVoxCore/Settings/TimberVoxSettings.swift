import Foundation

public enum RecordingAudioBehavior: String, Codable, CaseIterable, Equatable, Sendable {
  case pauseMedia
  case mute
  case lowerVolume
  case doNothing

  public var displayName: String {
    switch self {
    case .pauseMedia: "Pause"
    case .mute: "Mute"
    case .lowerVolume: "Lower volume"
    case .doNothing: "Do nothing"
    }
  }
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
public struct TimberVoxSettings: Codable, Equatable, Sendable {
  public static let defaultPasteLastTranscriptHotkey = HotKey(key: .v, modifiers: [.option, .shift])
  public static let baseSoundEffectsVolume: Double = TimberVoxCoreConstants.baseSoundEffectsVolume
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
  public var superFastModeEnabled: Bool
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
  public var appearancePreference: AppearancePreference
  public var recordingRetention: RecordingRetention
  public var clipboardRestoreBehavior: ClipboardRestoreBehavior
  public var startRecordingOnMenubarClick: Bool
  public var alwaysCloseRecordingWindow: Bool
  public var autoPasteResult: Bool
  public var holdShiftToAutoSend: Bool
  public var voiceModelActiveDurationMinutes: Int
  public var showExperimentalModels: Bool
  public var errorLoggingEnabled: Bool
  public var autoIncreaseMicrophoneVolume: Bool
  public var silenceRemovalEnabled: Bool
  public var dynamicNormalizationEnabled: Bool
  public var soundEffectsStyle: SoundEffectsStyle

  public init(
    soundEffectsEnabled: Bool = true,
    soundEffectsVolume: Double = TimberVoxSettings.baseSoundEffectsVolume,
    hotkey: HotKey = .init(key: nil, modifiers: [.option]),
    openOnLogin: Bool = false,
    showDockIcon: Bool = true,
    selectedModel: String = FluidAudioModels.parakeetTdtV3.id,
    localModelPrewarmEnabled: Bool = true,
    superFastModeEnabled: Bool = false,
    useClipboardPaste: Bool = true,
    preventSystemSleep: Bool = true,
    recordingAudioBehavior: RecordingAudioBehavior = .doNothing,
    recordingInputMode: RecordingInputMode = .microphone,
    minimumKeyTime: Double = TimberVoxCoreConstants.defaultMinimumKeyTime,
    copyToClipboard: Bool = false,
    useDoubleTapOnly: Bool = false,
    outputLanguage: String? = nil,
    selectedMicrophoneID: String? = nil,
    saveTranscriptionHistory: Bool = true,
    maxHistoryEntries: Int? = nil,
    pasteLastTranscriptHotkey: HotKey? = TimberVoxSettings.defaultPasteLastTranscriptHotkey,
    hasCompletedModelBootstrap: Bool = false,
    wordRemovalsEnabled: Bool = false,
    wordRemovals: [WordRemoval] = TimberVoxSettings.defaultWordRemovals,
    wordRemappings: [WordRemapping] = [],
    alwaysOnEnabled: Bool = false,
    alwaysOnPasteHotkey: HotKey? = HotKey(key: nil, modifiers: [.fn]),
    alwaysOnDumpHotkey: HotKey? = nil,
    alwaysOnStreamingModel: String = FluidAudioModels.parakeetEou160.id,
    textTransformMode: TextTransformMode = .voiceToText,
    textTransformModel: String = TimberVoxSettings.defaultTextTransformModel,
    customTextTransformInstructions: String = TextTransformPreset.defaultCustomInstructions,
    textTransformContextOptions: DictationContextOptions = TimberVoxSettings.defaultTextTransformContextOptions,
    appearancePreference: AppearancePreference = .automatic,
    recordingRetention: RecordingRetention = .forever,
    clipboardRestoreBehavior: ClipboardRestoreBehavior = .defaultBehavior,
    startRecordingOnMenubarClick: Bool = false,
    alwaysCloseRecordingWindow: Bool = false,
    autoPasteResult: Bool = true,
    holdShiftToAutoSend: Bool = false,
    voiceModelActiveDurationMinutes: Int = 1,
    showExperimentalModels: Bool = false,
    errorLoggingEnabled: Bool = false,
    autoIncreaseMicrophoneVolume: Bool = true,
    silenceRemovalEnabled: Bool = false,
    dynamicNormalizationEnabled: Bool = false,
    soundEffectsStyle: SoundEffectsStyle = .standard
  ) {
    self.soundEffectsEnabled = soundEffectsEnabled
    self.soundEffectsVolume = soundEffectsVolume
    self.hotkey = hotkey
    self.openOnLogin = openOnLogin
    self.showDockIcon = showDockIcon
    self.selectedModel = selectedModel
    self.localModelPrewarmEnabled = localModelPrewarmEnabled
    self.superFastModeEnabled = superFastModeEnabled
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
    self.appearancePreference = appearancePreference
    self.recordingRetention = recordingRetention
    self.clipboardRestoreBehavior = clipboardRestoreBehavior
    self.startRecordingOnMenubarClick = startRecordingOnMenubarClick
    self.alwaysCloseRecordingWindow = alwaysCloseRecordingWindow
    self.autoPasteResult = autoPasteResult
    self.holdShiftToAutoSend = holdShiftToAutoSend
    self.voiceModelActiveDurationMinutes = voiceModelActiveDurationMinutes
    self.showExperimentalModels = showExperimentalModels
    self.errorLoggingEnabled = errorLoggingEnabled
    self.autoIncreaseMicrophoneVolume = autoIncreaseMicrophoneVolume
    self.silenceRemovalEnabled = silenceRemovalEnabled
    self.dynamicNormalizationEnabled = dynamicNormalizationEnabled
    self.soundEffectsStyle = soundEffectsStyle
  }

  public init(from decoder: Decoder) throws {
    self.init()
    let container = try decoder.container(keyedBy: TimberVoxSettingKey.self)
    for field in TimberVoxSettingsSchema.fields {
      try field.decode(into: &self, from: container)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TimberVoxSettingKey.self)
    for field in TimberVoxSettingsSchema.fields {
      try field.encode(self, into: &container)
    }
  }
}
