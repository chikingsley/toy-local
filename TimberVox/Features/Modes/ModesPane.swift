import TimberVoxCore
import SwiftUI

struct ModesPane: View {
  private enum Route {
    case list
    case detail
  }

  @Bindable var store: SettingsStore
  @Binding var createModeRequest: Bool

  init(store: SettingsStore, createModeRequest: Binding<Bool> = .constant(false)) {
    self.store = store
    self._createModeRequest = createModeRequest
  }

  @State private var route: Route = .list
  @State private var modes = ModeDraft.modes
  @State private var selectedModeID = ModeDraft.modes[0].id
  @State private var microphone = TLMicrophoneSource.devices[0]
  @State private var advancedOpen = false
  @State private var editingModeTitleID: ModeDraft.ID?
  @State private var modeTitleDraft = ""

  private var selectedModeBinding: Binding<ModeDraft> {
    Binding {
      modes.first { $0.id == selectedModeID } ?? modes[0]
    } set: { updatedMode in
      guard let index = modes.firstIndex(where: { $0.id == updatedMode.id }) else { return }
      var normalizedMode = updatedMode
      if !languageIsSupported(normalizedMode.language, byModelID: normalizedMode.voiceModel.id) {
        normalizedMode.language = ModeLanguagePolicy.automaticName
      }
      modes[index] = normalizedMode
      if normalizedMode.id == ModeDraft.defaultModeID {
        applyDefaultMode(normalizedMode)
      }
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
          ModesDetailTitle(
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
    .onAppear {
      syncDefaultModeFromSettings()
      consumeCreateModeRequest()
    }
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
          ModeListRow(mode: mode) {
            selectedModeID = mode.id
            editingModeTitleID = nil
            withAnimation(.easeInOut(duration: 0.18)) {
              route = .detail
            }
          }
        }
      }

      Spacer()

      ModesTip()
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
              panelWidth: 204,
              showsAllRows: true,
              selectedTint: TLTheme.accentGreen
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
              options: languageOptions
            )
          }
          TLSettingsRow(title: "Voice Model") {
            ModesModelMenu(
              selection: selectedModeBinding.voiceModel,
              models: ModeModelOption.voiceModels
            )
          }
          if selectedModeBinding.wrappedValue.usesLanguageModel {
            TLSettingsRow(title: "Language Model") {
              ModesModelMenu(
                selection: selectedModeBinding.languageModel,
                models: ModeModelOption.languageModels
              )
            }
          }

        }

        TLSettingsCard {
          ModesActionRow(title: "Activate for apps", actionTitle: "Add apps and sites")
          ModesShortcutRow()

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
                options: ModeDraft.playbackOptions
              )
            }
            TLSettingsRow(
              title: "Record from system audio",
              hint: "If enabled, audio will be recorded from applications on your main display along with your Microphone."
            ) {
              settingToggle(isOn: selectedModeBinding.recordSystemAudio)
            }

          }
          .transition(.opacity.combined(with: .move(edge: .top)))

          TLSettingsCard {
            TLSettingsRow(
              title: "Auto paste",
              hint: "Controls whether transcribed text is automatically pasted into the active application when recording stops."
            ) {
              stringOptionMenu(
                value: selectedModeBinding.autoPaste,
                options: ModeDraft.autoPasteOptions
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

}

extension ModesPane {
  private func syncDefaultModeFromSettings() {
    guard let index = modes.firstIndex(where: { $0.id == ModeDraft.defaultModeID }) else { return }
    modes[index] = ModeDraft.defaultMode(
      from: store.timberVoxSettings,
      languageName: languageName(forCode: store.timberVoxSettings.outputLanguage)
    )
  }

  private func applyDefaultMode(_ mode: ModeDraft) {
    store.timberVoxSettings.textTransformMode = mode.preset.transformMode
    store.timberVoxSettings.outputLanguage = languageCode(forName: mode.language)
    store.timberVoxSettings.selectedModel = mode.voiceModel.id
    store.timberVoxSettings.textTransformModel = mode.languageModel.id
    store.timberVoxSettings.recordingAudioBehavior = ModeDraft.audioBehavior(forLabel: mode.playbackBehavior)
    store.timberVoxSettings.recordingInputMode = mode.recordSystemAudio ? .systemAudio : .microphone
    store.timberVoxSettings.autoPasteResult = mode.autoPaste != "Off"
  }

  private var languageOptions: [String] {
    ModeLanguagePolicy.allowedLanguageNames(
      languages: store.languages,
      supportedCodes: supportedLanguageCodes(forModelID: selectedModeBinding.wrappedValue.voiceModel.id)
    )
  }

  private func supportedLanguageCodes(forModelID modelID: String) -> Set<String> {
    TranscriptionModelCatalog.model(id: modelID)?.supportedLanguages ?? []
  }

  private func languageIsSupported(_ name: String, byModelID modelID: String) -> Bool {
    guard name != ModeLanguagePolicy.automaticName else { return true }
    return ModeLanguagePolicy.isSupported(
      code: languageCode(forName: name),
      supportedCodes: supportedLanguageCodes(forModelID: modelID)
    )
  }

  private func languageName(forCode code: String?) -> String {
    guard let code else { return "Automatic" }
    return store.languages.first { $0.code == code }?.name ?? "Automatic"
  }

  private func languageCode(forName name: String) -> String? {
    guard name != "Automatic" else { return nil }
    return store.languages.first { $0.name == name }?.code
  }

  private func consumeCreateModeRequest() {
    guard createModeRequest else { return }
    createModeRequest = false
    createMode()
  }

  private func createMode() {
    let template = modes[0]
    let newMode = ModeDraft(
      id: UUID().uuidString,
      name: "New Mode",
      preset: template.preset,
      language: "Automatic",
      voiceModel: template.voiceModel,
      languageModel: template.languageModel,
      playbackBehavior: "Default",
      recordSystemAudio: false,
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
      modes = ModeDraft.modes
    }
    selectedModeID = modes[0].id
  }

  private func stringOptionMenu(
    value: Binding<String>,
    options: [String]
  ) -> some View {
    TLOptionMenu(
      selection: value,
      options: options.map { TLMenuOption(value: $0, label: $0) },
      selectedTint: TLTheme.accentGreen
    )
  }

  private func settingToggle(isOn: Binding<Bool>) -> some View {
    Toggle("", isOn: isOn)
      .toggleStyle(.switch)
      .controlSize(.small)
      .labelsHidden()
  }
}

#Preview("Modes") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    ModesPane(store: store.settings)
      .frame(width: 580, height: 680)
      .background(TLTheme.windowBackground)
  }
}
