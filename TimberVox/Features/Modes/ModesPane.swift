import SwiftUI

struct ModesPane: View {
  @State private var modeStore = ModeStore.shared
  @State private var transcriptionCatalog = TranscriptionModelCatalogStore.shared
  @State private var selectedModeID: String?
  @State private var pendingDeleteID: String?
  @State private var showsDeleteConfirmation = false
  @State private var showsModeImporter = false
  @State private var showsImportError = false
  @State private var importErrorMessage = ""

  var body: some View {
    VStack(spacing: 0) {
      if let selectedModeID, modeStore.mode(id: selectedModeID) != nil {
        ModeDetailHeader(
          modeID: selectedModeID,
          modeStore: modeStore,
          canDelete: modeStore.modes.count > 1,
          onUse: { modeStore.activeModeID = selectedModeID },
          onDuplicate: { duplicateMode(selectedModeID) },
          onDelete: { requestDelete(selectedModeID) },
          onBack: { self.selectedModeID = nil }
        )

        ModeDetailForm(
          modeID: selectedModeID,
          modeStore: modeStore,
          transcriptionCatalog: transcriptionCatalog
        )
      } else {
        AppPageHeader("Modes") {
          Button("Import mode", systemImage: "square.and.arrow.down") {
            showsModeImporter = true
          }
          .buttonStyle(.sc(.secondary, size: .sm))

          Button("Create mode", systemImage: "plus") {
            createMode()
          }
          .buttonStyle(.sc(.secondary, size: .sm))
        }

        ModeListView(
          modes: modeStore.modes,
          activeModeID: modeStore.activeModeID,
          transcriptionModels: transcriptionCatalog.models,
          languageModels: transcriptionCatalog.languageModels,
          onSelect: { selectedModeID = $0 },
          onCreate: createMode(preset:)
        )
      }
    }
    .task {
      await refreshCatalog()
    }
    .scAlertDialog(
      isPresented: $showsDeleteConfirmation,
      title: "Delete mode?",
      message: deleteMessage,
      confirmLabel: "Delete",
      role: .destructive,
      onConfirm: confirmDelete
    )
    .appNoticeDialog(
      isPresented: $showsImportError,
      title: "Couldn’t import mode",
      message: importErrorMessage
    )
    .fileImporter(
      isPresented: $showsModeImporter,
      allowedContentTypes: [.timberVoxMode, .json]
    ) { result in
      importMode(result)
    }
  }

  private var deleteMessage: String {
    guard let pendingDeleteID, let mode = modeStore.mode(id: pendingDeleteID) else {
      return "This mode will be removed permanently."
    }
    return "\u{201c}\(mode.name)\u{201d} will be removed permanently."
  }

  private func createMode() {
    let newID = modeStore.addMode()
    modeStore.updateMode(id: newID) {
      $0.name = "New Mode"
      $0.nameIsCustomized = true
      $0.textTransformPreset = .custom
      $0.iconSystemName = nil
    }
    normalizeMode(id: newID)
    selectedModeID = newID
  }

  private func createMode(preset: ModeTextTransformPreset) {
    let newID = modeStore.addMode()
    modeStore.updateMode(id: newID) {
      $0.name = preset.referenceLabel
      $0.nameIsCustomized = false
      $0.textTransformPreset = preset
      $0.iconSystemName = nil
      $0.textTransformContextOptions =
        preset == .custom ? .none : preset.usesAllAvailableContext ? .allAvailable : .none
      if preset == .custom {
        $0.customTextTransformInstructions = TextTransformPreset.defaultCustomInstructions
      }
    }
    normalizeMode(id: newID)
    selectedModeID = newID
  }

  private func requestDelete(_ id: String) {
    guard modeStore.modes.count > 1 else { return }
    pendingDeleteID = id
    showsDeleteConfirmation = true
  }

  private func duplicateMode(_ id: String) {
    let duplicateID = modeStore.duplicateMode(id: id)
    normalizeMode(id: duplicateID)
    selectedModeID = duplicateID
  }

  private func confirmDelete() {
    guard let pendingDeleteID else { return }
    modeStore.deleteMode(id: pendingDeleteID)
    if selectedModeID == pendingDeleteID {
      selectedModeID = nil
    }
    self.pendingDeleteID = nil
  }

  private func importMode(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      let hasSecurityAccess = url.startAccessingSecurityScopedResource()
      defer {
        if hasSecurityAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let data = try Data(contentsOf: url, options: .mappedIfSafe)
      let file = try TimberVoxModeFile.decode(data)
      var importedMode = transcriptionCatalog.normalized(file.mode)
      if importedMode.usesTextTransform,
        !transcriptionCatalog.languageModels.contains(where: {
          $0.id == importedMode.textTransformModelID
        }),
        let fallbackLanguageModel = transcriptionCatalog.languageModels.first
      {
        importedMode.textTransformModelID = fallbackLanguageModel.id
      }
      let newID = modeStore.importMode(importedMode)
      selectedModeID = newID
    } catch {
      importErrorMessage = error.localizedDescription
      showsImportError = true
    }
  }

  private func normalizeModes() {
    for id in modeStore.modes.map(\.id) {
      normalizeMode(id: id)
    }
  }

  private func refreshCatalog() async {
    await transcriptionCatalog.refreshIfNeeded()
    normalizeModes()
  }

  private func normalizeMode(id: String) {
    guard let current = modeStore.mode(id: id) else { return }
    let normalized = transcriptionCatalog.normalized(current)
    guard normalized != current else { return }
    modeStore.updateMode(id: id) { $0 = normalized }
  }
}

private struct ModeDetailHeader: View {
  let modeID: String
  @Bindable var modeStore: ModeStore
  let canDelete: Bool
  let onUse: () -> Void
  let onDuplicate: () -> Void
  let onDelete: () -> Void
  let onBack: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    ZStack {
      HStack(spacing: AppSpacing.sm) {
        Image(systemName: mode?.resolvedIconSystemName ?? "mic.fill")
          .font(.system(size: 16, weight: .semibold))

        TextField("Mode name", text: nameBinding)
          .textFieldStyle(.plain)
          .font(.system(size: 14, weight: .semibold))
          .fixedSize(horizontal: true, vertical: false)
          .multilineTextAlignment(.center)
      }

      HStack(spacing: AppSpacing.xs) {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .accessibilityLabel("Back")

        Spacer(minLength: AppSpacing.md)

        if modeStore.activeModeID == modeID {
          SCBadge {
            Label("Active", systemImage: "checkmark.circle.fill")
          }
        } else {
          Button("Use Mode", systemImage: "checkmark.circle", action: onUse)
            .buttonStyle(.sc(.secondary, size: .sm))
        }

        Button(action: onDuplicate) {
          Image(systemName: "plus.square.on.square")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .accessibilityLabel("Duplicate mode")

        if let mode {
          ShareLink(
            item: TimberVoxModeTransfer(file: TimberVoxModeFile(mode: mode)),
            subject: Text("TimberVox mode: \(mode.name)"),
            message: Text("Import this TimberVox mode configuration."),
            preview: SharePreview(mode.name)
          ) {
            Image(systemName: "square.and.arrow.up")
          }
          .buttonStyle(.sc(.ghost, size: .iconSM))
          .accessibilityLabel("Share mode")
        }

        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .disabled(!canDelete)
        .accessibilityLabel("Delete mode")
      }
    }
    .padding(.horizontal, AppSpacing.sm)
    .frame(height: AppLayout.headerHeight)
    .foregroundStyle(theme.foreground)
    .background(theme.background)
    .overlay(alignment: .bottom) {
      SCSeparator().opacity(0.7)
    }
  }

  private var mode: DictationMode? {
    modeStore.mode(id: modeID)
  }

  private var nameBinding: Binding<String> {
    Binding {
      modeStore.mode(id: modeID)?.name ?? "Mode"
    } set: { name in
      modeStore.updateMode(id: modeID) {
        $0.name = name
        $0.nameIsCustomized = true
      }
    }
  }

}

extension ModeTextTransformPreset {
  var referenceLabel: String {
    switch self {
    case .voiceToText: "Voice to Text"
    case .meeting: "Meeting Summary"
    default: label
    }
  }
}
