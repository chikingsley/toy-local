import SwiftUI

struct PrototypeModesPane: View {
  private enum Route {
    case list
    case detail
  }

  @Binding var createModeRequest: Bool

  init(createModeRequest: Binding<Bool> = .constant(false)) {
    self._createModeRequest = createModeRequest
  }

  @State private var route: Route = .list
  @State private var modes = PrototypeMode.modes
  @State private var selectedModeID = PrototypeMode.modes[0].id
  @State private var microphone = TLMicrophoneSource.devices[0]
  @State private var advancedOpen = false
  @State private var editingModeTitleID: PrototypeMode.ID? = nil
  @State private var modeTitleDraft = ""

  private var selectedModeBinding: Binding<PrototypeMode> {
    Binding {
      modes.first { $0.id == selectedModeID } ?? modes[0]
    } set: { updatedMode in
      guard let index = modes.firstIndex(where: { $0.id == updatedMode.id }) else { return }
      modes[index] = updatedMode
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        TLHeader(control: headerControl) {
          EmptyView()
        } trailing: {
          if route == .list {
            microphoneMenu
          }
        }

        if route == .detail {
          PrototypeModesDetailTitle(
            mode: selectedModeBinding.wrappedValue,
            draft: $modeTitleDraft,
            isEditing: editingModeTitleID == selectedModeID,
            beginEditing: {
              modeTitleDraft = selectedModeBinding.wrappedValue.name
              editingModeTitleID = selectedModeID
            },
            commit: {
              let trimmedTitle = modeTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
              if !trimmedTitle.isEmpty {
                selectedModeBinding.wrappedValue.name = trimmedTitle
              }
              editingModeTitleID = nil
            },
            cancel: {
              modeTitleDraft = selectedModeBinding.wrappedValue.name
              editingModeTitleID = nil
            }
          )
        }
      }

      ZStack(alignment: .top) {
        switch route {
        case .list:
          listPage
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .detail:
          detailPage
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
      }
      .animation(.easeInOut(duration: 0.18), value: route)
    }
    .onAppear(perform: consumeCreateModeRequest)
    .onChange(of: createModeRequest) { _, _ in
      consumeCreateModeRequest()
    }
  }

  private var headerControl: TLHeaderControl {
    guard route == .detail else { return .sidebarToggle }
    return .back {
      withAnimation(.easeInOut(duration: 0.18)) {
        route = .list
      }
    }
  }

  private var microphoneMenu: some View {
    TLHeaderMicrophoneMenu(selection: $microphone)
  }

  private var listPage: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 8) {
        Text("Modes")
          .font(.system(size: 13, weight: .semibold))
        TLInfoHint("Modes change the preset, models, activation, and post-processing used when you record.")
        Spacer()
        Button(action: createMode) {
          Label("Create mode", systemImage: "plus")
            .font(.system(size: 12, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
      }

      VStack(spacing: 10) {
        ForEach(modes) { mode in
          PrototypeModeRow(mode: mode) {
            selectedModeID = mode.id
            editingModeTitleID = nil
            withAnimation(.easeInOut(duration: 0.18)) {
              route = .detail
            }
          }
        }
      }

      Spacer()

      PrototypeModesTip()
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder private var detailPage: some View {
    TLScrollArea(
      contentPadding: EdgeInsets(top: 16, leading: 24, bottom: 18, trailing: 24),
      spacing: 14
    ) {
      VStack(alignment: .leading, spacing: 14) {
        TLCard {
          TLSettingsRow(title: "Preset") {
            TLOptionMenu(
              selection: selectedModeBinding.preset,
              options: Preset.allCases.map { preset in
                TLMenuOption(
                  value: preset,
                  label: preset.rawValue,
                  systemImage: preset.icon,
                  accessoryText: preset == .superPreset ? "Recommended" : "",
                  detailTitle: preset.rawValue,
                  detailText: preset.description
                )
              },
              width: 152,
              panelWidth: 204,
              selectedTint: activeGreen
            ) { preset in
              if selectedModeBinding.wrappedValue.id != "default" {
                selectedModeBinding.wrappedValue.name = preset.rawValue
              }
            }
          }
        }

        TLSettingsCard {
          TLSettingsRow(title: "Language") {
            stringOptionMenu(
              value: selectedModeBinding.language,
              options: PrototypeMode.languageOptions
            )
          }
          TLSettingsRow(title: "Voice Model") {
            PrototypeModesModelMenu(
              selection: selectedModeBinding.voiceModel,
              models: PrototypeModel.voiceModels
            )
          }
          if selectedModeBinding.wrappedValue.voiceModel.supportsRealtime {
            TLSettingsRow(title: "Realtime") {
              settingToggle(isOn: selectedModeBinding.realtime)
            }
          }
          if selectedModeBinding.wrappedValue.usesLanguageModel {
            TLSettingsRow(title: "Language Model") {
              PrototypeModesModelMenu(
                selection: selectedModeBinding.languageModel,
                models: PrototypeModel.languageModels
              )
            }
          }

        }

        TLSettingsCard {
          PrototypeModesActionRow(title: "Activate for apps", actionTitle: "Add apps and sites")
          PrototypeModesShortcutRow()

        }

        TLDisclosureRow(title: "Advanced settings", isOpen: $advancedOpen)

        if advancedOpen {
          TLSettingsCard {
            TLSettingsRow(
              title: "Playback when recording",
              hint: "Pause, lower, or mute your music and video while recording. Playback settings are restored once recording is complete."
            ) {
              stringOptionMenu(
                value: selectedModeBinding.playbackBehavior,
                options: PrototypeMode.playbackOptions,
                width: 160
              )
            }
            TLSettingsRow(
              title: "Record from system audio",
              hint: "If enabled, audio will be recorded from applications on your main display along with your Microphone."
            ) {
              settingToggle(isOn: selectedModeBinding.recordSystemAudio)
            }
            TLSettingsRow(
              title: "Identify Speakers",
              hint: "If enabled, speakers will be separated and identified (Speaker 1, Speaker 2, Speaker 3, etc.) in your recording."
            ) {
              settingToggle(isOn: selectedModeBinding.identifySpeakers)
            }

          }
          .transition(.opacity.combined(with: .move(edge: .top)))

          TLSettingsCard {
            TLSettingsRow(
              title: "Autocapitalize Insert",
              hint: "If enabled, the first word of inserted transcript text is adjusted to match cursor context "
                + "(start of sentence or mid-sentence). Turn this off for always-lowercase dictation."
            ) {
              settingToggle(isOn: selectedModeBinding.autocapitalizeInsert)
            }
            TLSettingsRow(
              title: "Auto paste",
              hint: "Controls whether transcribed text is automatically pasted into the active application when recording stops."
            ) {
              stringOptionMenu(
                value: selectedModeBinding.autoPaste,
                options: PrototypeMode.autoPasteOptions,
                width: 136
              )
            }

          }
          .transition(.opacity.combined(with: .move(edge: .top)))

          TLCard {
            TLDestructiveRow(title: "Delete this mode", action: deleteSelectedMode)
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func consumeCreateModeRequest() {
    guard createModeRequest else { return }
    createModeRequest = false
    createMode()
  }

  private func createMode() {
    let template = modes[0]
    let newMode = PrototypeMode(
      id: UUID().uuidString,
      name: "New Mode",
      preset: template.preset,
      language: "Automatic",
      voiceModel: template.voiceModel,
      languageModel: template.languageModel,
      realtime: false,
      playbackBehavior: "Default",
      recordSystemAudio: false,
      identifySpeakers: false,
      autocapitalizeInsert: template.autocapitalizeInsert,
      autoPaste: "Default",
      isActive: false
    )
    modes.append(newMode)
    selectedModeID = newMode.id
    modeTitleDraft = newMode.name
    editingModeTitleID = newMode.id
    withAnimation(.easeInOut(duration: 0.18)) {
      route = .detail
      advancedOpen = false
    }
  }

  private func deleteSelectedMode() {
    let removedID = selectedModeID
    withAnimation(.easeInOut(duration: 0.18)) {
      route = .list
      advancedOpen = false
      editingModeTitleID = nil
    }
    modes.removeAll { $0.id == removedID }
    if modes.isEmpty {
      modes = PrototypeMode.modes
    }
    selectedModeID = modes[0].id
  }

  private func stringOptionMenu(
    value: Binding<String>,
    options: [String],
    width: CGFloat = 152
  ) -> some View {
    TLOptionMenu(
      selection: value,
      options: options.map { TLMenuOption(value: $0, label: $0) },
      width: width,
      panelWidth: width,
      selectedTint: activeGreen
    )
  }

  private func settingToggle(isOn: Binding<Bool>) -> some View {
    Toggle("", isOn: isOn)
      .toggleStyle(.switch)
      .controlSize(.small)
      .labelsHidden()
  }
}

private let activeGreen = TLTheme.accentGreen

private struct PrototypeMode: Identifiable, Equatable {
  let id: String
  var name: String
  var preset: Preset
  var language: String
  var voiceModel: PrototypeModel
  var languageModel: PrototypeModel
  var realtime: Bool
  var playbackBehavior: String
  var recordSystemAudio: Bool
  var identifySpeakers: Bool
  var autocapitalizeInsert: Bool
  var autoPaste: String
  let isActive: Bool

  var leadingIcon: String { preset.icon }
  var usesLanguageModel: Bool { preset != .voiceToText }

  static let languageOptions = ["Automatic", "English", "French", "Spanish", "German", "Japanese"]
  static let playbackOptions = ["Default", "Pause", "Lower", "Mute", "Keep Playing"]
  static let autoPasteOptions = ["Default", "On", "Off"]

  static let modes: [PrototypeMode] = [
    PrototypeMode(
      id: "default",
      name: "Default",
      preset: .voiceToText,
      language: "Automatic",
      voiceModel: .voiceModels[0],
      languageModel: .languageModels[0],
      realtime: true,
      playbackBehavior: "Default",
      recordSystemAudio: false,
      identifySpeakers: false,
      autocapitalizeInsert: true,
      autoPaste: "Default",
      isActive: true
    ),
    PrototypeMode(
      id: "voice-to-text",
      name: "Voice to text",
      preset: .voiceToText,
      language: "Automatic",
      voiceModel: .voiceModels[0],
      languageModel: .languageModels[0],
      realtime: false,
      playbackBehavior: "Default",
      recordSystemAudio: false,
      identifySpeakers: false,
      autocapitalizeInsert: true,
      autoPaste: "Default",
      isActive: false
    ),
    PrototypeMode(
      id: "email",
      name: "Email",
      preset: .mail,
      language: "English",
      voiceModel: .voiceModels[1],
      languageModel: .languageModels[1],
      realtime: false,
      playbackBehavior: "Pause",
      recordSystemAudio: false,
      identifySpeakers: false,
      autocapitalizeInsert: true,
      autoPaste: "On",
      isActive: false
    ),
    PrototypeMode(
      id: "meeting",
      name: "Meeting notes",
      preset: .meetingSummary,
      language: "Automatic",
      voiceModel: .voiceModels[2],
      languageModel: .languageModels[2],
      realtime: false,
      playbackBehavior: "Lower",
      recordSystemAudio: true,
      identifySpeakers: true,
      autocapitalizeInsert: true,
      autoPaste: "Off",
      isActive: false
    ),
  ]
}

private enum Preset: String, CaseIterable, Identifiable, Hashable {
  case superPreset = "Super"
  case voiceToText = "Voice to text"
  case mail = "Mail"
  case message = "Message"
  case meetingSummary = "Meeting Summary"
  case custom = "Custom"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .superPreset: "sparkles"
    case .voiceToText: "mic.fill"
    case .mail: "envelope.fill"
    case .message: "bubble.left.fill"
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
    case .meetingSummary:
      "Capture meeting audio and turn it into concise notes, decisions, and follow-up items."
    case .custom:
      "Start from a blank mode and choose the exact models, prompts, and activation behavior."
    }
  }
}

private struct PrototypeModel: Identifiable, Equatable {
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

  static let voiceModels = [
    PrototypeModel(
      id: "parakeet", name: "Parakeet Multilingual", provider: .nvidia,
      description: "Local Parakeet Multilingual model optimized for realtime dictation.",
      badge: "", supportsRealtime: true, availability: .local),
    PrototypeModel(
      id: "s1-voice", name: "S1-Voice", provider: .superwhisper,
      description: "Superwhisper voice model.",
      badge: "New", supportsRealtime: false, availability: .local),
    PrototypeModel(
      id: "scribe", name: "Scribe", provider: .elevenLabs,
      description: "ElevenLabs cloud transcription with strong realtime support.",
      badge: "", supportsRealtime: true, availability: .cloud),
    PrototypeModel(
      id: "nova-3", name: "Nova 3", provider: .deepgram,
      description: "Deepgram Nova 3 cloud transcription.",
      badge: "", supportsRealtime: true, availability: .cloud),
    PrototypeModel(
      id: "nova-2", name: "Nova 2", provider: .deepgram,
      description: "Deepgram Nova 2 cloud transcription.",
      badge: "", supportsRealtime: true, availability: .cloud),
  ]

  static let languageModels = [
    PrototypeModel(
      id: "s1", name: "S1-Language", provider: .superwhisper,
      description: "Superwhisper language formatting.",
      badge: "", supportsRealtime: false, availability: .local),
    PrototypeModel(
      id: "sonnet", name: "Sonnet 4.6", provider: .anthropic,
      description: "High quality language rewriting.",
      badge: "", supportsRealtime: false, availability: .cloud),
    PrototypeModel(
      id: "gpt-mini", name: "GPT-5.4 mini", provider: .openAI,
      description: "Fast OpenAI language processing.",
      badge: "", supportsRealtime: false, availability: .cloud),
  ]
}

extension TLProvider {
  fileprivate var speed: Double {
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

  fileprivate var accuracy: Double {
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

private struct PrototypeModeRow: View {
  let mode: PrototypeMode
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: mode.leadingIcon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: 18)

        HStack(spacing: 7) {
          Text(mode.name)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          if mode.isActive {
            Circle()
              .fill(activeGreen)
              .frame(width: 7, height: 7)
          }
        }

        Spacer(minLength: 12)

        TLProviderLogo(provider: mode.voiceModel.provider, size: 24)
        if mode.usesLanguageModel {
          TLProviderLogo(provider: mode.languageModel.provider, size: 24)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(.primary.opacity(hovering ? 0.12 : 0.09))
      )
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct PrototypeModesTip: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "lightbulb.fill")
        .font(.system(size: 20))
        .foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 3) {
        Text("Auto-switch with activation")
          .font(.system(size: 13, weight: .semibold))
        Text("Link a mode to specific apps or websites so ToyLocal picks the right one automatically when you record.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Button("Dismiss") {}
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .buttonStyle(.plain)
    }
    .padding(14)
    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
    )
  }
}

private struct PrototypeModesDetailTitle: View {
  let mode: PrototypeMode
  @Binding var draft: String
  let isEditing: Bool
  let beginEditing: () -> Void
  let commit: () -> Void
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Spacer()
      Image(systemName: mode.leadingIcon)
        .font(.system(size: 18, weight: .semibold))
      if isEditing {
        TextField("Mode name", text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 170)
          .padding(.horizontal, 8)
          .frame(height: 28)
          .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        TLIconButton(
          systemName: "checkmark",
          tileSize: 22,
          hitSize: 28,
          foreground: activeGreen,
          help: "Save mode name",
          action: commit
        )
        TLIconButton(
          systemName: "xmark",
          tileSize: 22,
          hitSize: 28,
          help: "Cancel rename",
          action: cancel
        )
      } else {
        Button(action: beginEditing) {
          Text(mode.name)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      if mode.isActive {
        Circle()
          .fill(activeGreen)
          .frame(width: 7, height: 7)
      }
      Spacer()
    }
    .padding(.top, 4)
  }
}

private struct PrototypeModesShortcutRow: View {
  private static let defaultKeys = ["⌥", "⇧", "␣"]
  @State private var keys = defaultKeys

  var body: some View {
    TLSettingsRow(
      title: "Keyboard shortcut",
      subtitle: "Start a recording in this mode",
      height: 58
    ) {
      TLShortcutRecorder(keys: $keys, defaultKeys: Self.defaultKeys)
    }
  }
}

private struct PrototypeModesValuePill: View {
  let text: String
  var icon: String?
  var provider: TLProvider?
  var width: CGFloat = 152

  var body: some View {
    HStack(spacing: 7) {
      if let provider {
        TLProviderLogo(provider: provider, size: 18)
      } else if let icon {
        Image(systemName: icon)
          .font(.system(size: 11))
          .foregroundStyle(activeGreen)
      }
      Text(text)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .frame(width: width, height: 30, alignment: .leading)
    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct PrototypeModesModelMenu: View {
  @Binding var selection: PrototypeModel
  let models: [PrototypeModel]
  var width: CGFloat = 152
  var panelWidth: CGFloat = 220

  @State private var presentationID = UUID()
  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  var body: some View {
    Button {
      toggleMenu()
    } label: {
      PrototypeModesValuePill(text: selection.name, provider: selection.provider, width: width)
    }
    .buttonStyle(.plain)
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onChange(of: anchorFrame) { _, _ in
      if floatingLayer?.contains(id: presentationID) == true {
        presentMenu()
      }
    }
    .onDisappear {
      floatingLayer?.dismiss(id: presentationID)
    }
  }

  private func toggleMenu() {
    if floatingLayer?.contains(id: presentationID) == true {
      floatingLayer?.dismiss(id: presentationID)
    } else {
      floatingLayer?.dismissAll()
      presentMenu()
    }
  }

  private func presentMenu() {
    guard anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: presentationID,
      anchor: anchorFrame,
      placement: .bottomTrailing,
      spacing: 6,
      estimatedSize: CGSize(width: panelWidth, height: estimatedPanelHeight),
      blocksBackground: true
    ) {
      PrototypeModesModelPicker(
        selection: $selection,
        models: models,
        hoverNamespace: presentationID.uuidString
      ) {
        floatingLayer?.dismissAll()
      }
    }
  }

  private var estimatedPanelHeight: CGFloat {
    min(CGFloat(models.count) * 31 + 90, 280)
  }
}

private struct PrototypeModesModelPicker: View {
  @Binding var selection: PrototypeModel
  let models: [PrototypeModel]
  let hoverNamespace: String
  let dismiss: () -> Void
  @State private var searchText = ""
  @State private var hoveredModelID: PrototypeModel.ID?
  @State private var favoriteIDs: Set<PrototypeModel.ID> = ["parakeet"]
  @State private var downloadedIDs: Set<PrototypeModel.ID> = ["parakeet", "s1"]

  private var filteredModels: [PrototypeModel] {
    guard !searchText.isEmpty else { return models }
    return models.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
        || $0.description.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var favoriteModels: [PrototypeModel] {
    filteredModels.filter { favoriteIDs.contains($0.id) }
  }

  private var popularModels: [PrototypeModel] {
    filteredModels.filter { !favoriteIDs.contains($0.id) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TLSearchField(placeholder: "Search models", text: $searchText)
        .padding(10)

      VStack(spacing: 1) {
        if !favoriteModels.isEmpty {
          PrototypeModelSectionTitle(title: "Favorites")
          ForEach(favoriteModels) { model in
            modelButton(model)
          }
        }

        PrototypeModelSectionTitle(title: "Popular")
          .padding(.top, favoriteModels.isEmpty ? 0 : 7)

        ForEach(popularModels) { model in
          modelButton(model)
        }
      }
      .padding(.horizontal, 6)
      .padding(.bottom, 8)
    }
    .frame(width: 220)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: 9))
  }

  private func modelButton(_ model: PrototypeModel) -> some View {
    PrototypeModelPickerButton(
      hoverNamespace: hoverNamespace,
      model: model,
      isSelected: model.id == selection.id,
      isHovered: hoveredModelID == model.id,
      isFavorite: favoriteIDs.contains(model.id),
      isDownloaded: downloadedIDs.contains(model.id),
      onSelect: {
        selection = model
        dismiss()
      },
      onHover: { hovering in
        hoveredModelID = hovering ? model.id : (hoveredModelID == model.id ? nil : hoveredModelID)
      },
      onToggleFavorite: {
        if favoriteIDs.contains(model.id) {
          favoriteIDs.remove(model.id)
        } else {
          favoriteIDs.insert(model.id)
        }
      },
      onToggleDownload: {
        if downloadedIDs.contains(model.id) {
          downloadedIDs.remove(model.id)
        } else {
          downloadedIDs.insert(model.id)
        }
      }
    )
  }
}

private struct PrototypeModelSectionTitle: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 6)
      .padding(.bottom, 2)
  }
}

private struct PrototypeModelPickerButton: View {
  let hoverNamespace: String
  let model: PrototypeModel
  let isSelected: Bool
  let isHovered: Bool
  let isFavorite: Bool
  let isDownloaded: Bool
  let onSelect: () -> Void
  let onHover: (Bool) -> Void
  let onToggleFavorite: () -> Void
  let onToggleDownload: () -> Void

  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  private var detailID: AnyHashable {
    AnyHashable("\(hoverNamespace)-\(model.id)-detail")
  }

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        TLProviderLogo(provider: model.provider, size: 20)
        Text(model.name)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
        if !model.badge.isEmpty {
          Text(model.badge)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: TLTheme.chipRadius))
        }
        Spacer()
        Button {
          onToggleFavorite()
        } label: {
          Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isFavorite ? Color.yellow : .secondary)
            .opacity(isFavorite || isHovered ? 1 : 0)
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)

        ModelDownloadControl(
          state: model.availability == .cloud
            ? .cloud
            : (isDownloaded ? .downloaded : .notDownloaded),
          hovering: isHovered,
          startDownload: onToggleDownload,
          delete: onToggleDownload
        )
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isSelected ? activeGreen.opacity(0.12) : (isHovered ? Color.primary.opacity(0.07) : .clear))
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
              activeGreen,
              style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
      }
    }
    .buttonStyle(.plain)
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onHover { hovering in
      onHover(hovering)
      if hovering {
        presentDetail()
      } else {
        floatingLayer?.dismiss(id: detailID)
      }
    }
    .onChange(of: anchorFrame) { _, _ in
      if isHovered {
        presentDetail()
      }
    }
    .onDisappear {
      floatingLayer?.dismiss(id: detailID)
    }
  }

  private func presentDetail() {
    guard anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: detailID,
      anchor: anchorFrame,
      placement: .left,
      spacing: 10,
      estimatedSize: CGSize(width: 228, height: 168),
      allowsHitTesting: false
    ) {
      PrototypeModelInfoCard(model: model)
    }
  }
}

private struct PrototypeModelInfoCard: View {
  let model: PrototypeModel

  var body: some View {
    TLPopoverCard(width: 228) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          TLProviderLogo(provider: model.provider, size: 22)
          VStack(alignment: .leading, spacing: 1) {
            Text(model.name)
              .font(.system(size: 13, weight: .semibold))
            Text(model.provider.displayName)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.secondary)
          }
        }

        Text(model.description)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        PrototypeModelMetric(title: "Speed", value: model.provider.speed)
        PrototypeModelMetric(title: "Accuracy", value: model.provider.accuracy)

        HStack {
          Text("Size")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Label(model.availability == .cloud ? "Cloud" : "Local", systemImage: model.availability == .cloud ? "icloud" : "internaldrive")
            .font(.system(size: 11, weight: .semibold))
        }
      }
    }
  }
}

private struct PrototypeModelMetric: View {
  let title: String
  let value: Double

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 48, alignment: .leading)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(.primary.opacity(0.08))
          Capsule()
            .fill(Color.accentColor)
            .frame(width: proxy.size.width * value)
        }
      }
      .frame(height: 3)
    }
  }
}

private struct PrototypeModesActionRow: View {
  let title: String
  var subtitle = ""
  let actionTitle: String

  var body: some View {
    TLSettingsRow(
      title: title,
      subtitle: subtitle,
      height: subtitle.isEmpty ? 50 : 58
    ) {
      TLActionPill(title: actionTitle)
    }
  }
}

#Preview("Modes") {
  TLFloatingHost {
    PrototypeModesPane()
      .frame(width: 580, height: 680)
      .background(TLTheme.windowBackground)
  }
}
