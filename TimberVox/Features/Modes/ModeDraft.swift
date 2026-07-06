import TimberVoxCore
import SwiftUI

struct ModeDraft: Identifiable, Equatable {
  let id: String
  var name: String
  var preset: Preset
  var language: String
  var voiceModel: ModeModelOption
  var languageModel: ModeModelOption
  var playbackBehavior: String
  var recordSystemAudio: Bool
  var autoPaste: String
  let isActive: Bool

  var leadingIcon: String { preset.icon }
  var usesLanguageModel: Bool { preset != .voiceToText }

  static let defaultModeID = "default"
  static let playbackOptions = RecordingAudioBehavior.allCases.map(\.displayName)
  static let autoPasteOptions = ["On", "Off"]

  static func audioBehavior(forLabel label: String) -> RecordingAudioBehavior {
    RecordingAudioBehavior.allCases.first { $0.displayName == label } ?? .doNothing
  }

  static func defaultMode(from settings: TimberVoxSettings, languageName: String) -> ModeDraft {
    let voice =
      ModeModelOption.voiceModels.first { $0.id == settings.selectedModel } ?? ModeModelOption.voiceModels[0]
    let language =
      ModeModelOption.languageModels.first { $0.id == settings.textTransformModel } ?? ModeModelOption.languageModels[0]
    return ModeDraft(
      id: defaultModeID,
      name: "Default",
      preset: Preset(transformMode: settings.textTransformMode),
      language: languageName,
      voiceModel: voice,
      languageModel: language,
      playbackBehavior: settings.recordingAudioBehavior.displayName,
      recordSystemAudio: settings.recordingInputMode == .systemAudio,
      autoPaste: settings.autoPasteResult ? "On" : "Off",
      isActive: true
    )
  }

  static let modes: [ModeDraft] = [
    ModeDraft(
      id: "default",
      name: "Default",
      preset: .voiceToText,
      language: "Automatic",
      voiceModel: .voiceModels[0],
      languageModel: .languageModels[0],
      playbackBehavior: RecordingAudioBehavior.doNothing.displayName,
      recordSystemAudio: false,
      autoPaste: "On",
      isActive: true
    )
  ]
}

extension TLProvider {
  init(providerID: TranscriptionProviderID) {
    switch providerID.rawValue {
    case "fluidaudio": self = .fluidAudio
    case "deepgram": self = .deepgram
    case "mistral": self = .mistral
    case "elevenlabs": self = .elevenLabs
    case "cohere": self = .cohere
    default: self = .fluidAudio
    }
  }

  init(languageProviderID: String) {
    switch languageProviderID {
    case "mistral": self = .mistral
    case "openai": self = .openAI
    case "anthropic": self = .anthropic
    default: self = .mistral
    }
  }
}

enum Preset: String, CaseIterable, Identifiable, Hashable {
  case superPreset = "Super"
  case voiceToText = "Voice to text"
  case mail = "Mail"
  case message = "Message"
  case note = "Note"
  case meetingSummary = "Meeting Summary"
  case custom = "Custom"

  var id: String { rawValue }

  init(transformMode: TextTransformMode) {
    switch transformMode {
    case .voiceToText: self = .voiceToText
    case .superPrompt: self = .superPreset
    case .messagePrompt: self = .message
    case .notePrompt: self = .note
    case .emailPrompt: self = .mail
    case .meetingPrompt: self = .meetingSummary
    case .customPrompt: self = .custom
    }
  }

  var transformMode: TextTransformMode {
    switch self {
    case .voiceToText: .voiceToText
    case .superPreset: .superPrompt
    case .message: .messagePrompt
    case .note: .notePrompt
    case .mail: .emailPrompt
    case .meetingSummary: .meetingPrompt
    case .custom: .customPrompt
    }
  }

  var icon: String {
    switch self {
    case .superPreset: "sparkles"
    case .voiceToText: "mic.fill"
    case .mail: "envelope.fill"
    case .message: "bubble.left.fill"
    case .note: "note.text"
    case .meetingSummary: "person.2.fill"
    case .custom: "slider.horizontal.3"
    }
  }

  var description: String {
    switch self {
    case .superPreset:
      "A recommended balanced mode that combines transcription, cleanup, and light formatting."
    case .voiceToText:
      "Turn your voice into text, no AI post processing. The result will have punctuation and uses your Vocabulary and Text Replacements."
    case .mail:
      "Draft an email from a spoken prompt with a subject-ready structure and cleaner phrasing."
    case .message:
      "Create a short message that keeps the original intent but removes dictation artifacts."
    case .note:
      "Turn your dictation into a structured note with clean paragraphs and lists."
    case .meetingSummary:
      "Capture meeting audio and turn it into concise notes, decisions, and follow-up items."
    case .custom:
      "Start from a blank mode and choose the exact models, prompts, and activation behavior."
    }
  }
}

struct ModeModelOption: Identifiable, Equatable {
  let id: String
  let name: String
  let provider: TLProvider
  let description: String
  let badge: String
  let supportsRealtime: Bool
  let availability: Availability

  enum Availability {
    case local
    case cloud
  }

  static let voiceModels: [ModeModelOption] = TranscriptionModelCatalog.userSelectableASR.map { spec in
    ModeModelOption(
      id: spec.id,
      name: spec.displayName,
      provider: TLProvider(providerID: spec.provider),
      description: spec.runtime == .local
        ? "Runs on this Mac via \(spec.provider.rawValue)."
        : "Cloud model routed through TimberVox Cloud.",
      badge: "",
      supportsRealtime: spec.capabilities.realtime || spec.capabilities.streamingInput,
      availability: spec.runtime == .local ? .local : .cloud
    )
  }

  static let languageModels: [ModeModelOption] = CloudLanguageModels.all.map { spec in
    ModeModelOption(
      id: spec.id,
      name: spec.displayName,
      provider: TLProvider(languageProviderID: spec.provider.rawValue),
      description: "Cloud language model routed through TimberVox Cloud.",
      badge: "",
      supportsRealtime: false,
      availability: .cloud
    )
  }
}

extension TLProvider {
  var speed: Double {
    switch self {
    case .nvidia: 0.88
    case .deepgram: 0.9
    case .elevenLabs: 0.78
    case .superwhisper: 0.72
    case .anthropic: 0.66
    case .openAI: 0.86
    default: 0.8
    }
  }

  var accuracy: Double {
    switch self {
    case .nvidia: 0.82
    case .deepgram: 0.88
    case .elevenLabs: 0.84
    case .superwhisper: 0.8
    case .anthropic: 0.9
    case .openAI: 0.86
    default: 0.85
    }
  }
}
