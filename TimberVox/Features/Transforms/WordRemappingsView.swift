import TimberVoxCore
import SwiftUI

struct WordRemappingsView: View {
  @Bindable var store: SettingsStore
  @FocusState private var isScratchpadFocused: Bool
  @State private var activeSection: ModificationSection = .removals

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Transcript Modifications")
            .font(.title2.bold())
          Text("Remove or replace words in every transcript. Removals use regex patterns and match whole words.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        transformSection

        GroupBox {
          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Scratchpad")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                TextField("Say something...", text: $store.remappingScratchpadText)
                  .textFieldStyle(.roundedBorder)
                  .focused($isScratchpadFocused)
                  .onChange(of: isScratchpadFocused) { _, newValue in
                    store.setRemappingScratchpadFocused(newValue)
                  }
              }

              VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                Text(previewText.isEmpty ? "\u{2014}" : previewText)
                  .font(.body)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 6)
                  .background(
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color(nsColor: .controlBackgroundColor))
                  )
              }
            }
          }
          .padding(.vertical, 6)
        }

        Picker("Modification Type", selection: $activeSection) {
          ForEach(ModificationSection.allCases) { section in
            Text(section.title).tag(section)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        switch activeSection {
        case .removals:
          removalsSection
        case .remappings:
          remappingsSection
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .onDisappear {
      store.setRemappingScratchpadFocused(false)
    }
  }

  private var removalsSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        Toggle("Enable Word Removals", isOn: $store.timberVoxSettings.wordRemovalsEnabled)
          .toggleStyle(.checkbox)

        removalsColumnHeaders

        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(store.timberVoxSettings.wordRemovals) { removal in
            if let removalBinding = removalBinding(for: removal.id) {
              RemovalRow(removal: removalBinding) {
                store.removeWordRemoval(removal.id)
              }
            }
          }
        }

        HStack {
          Button {
            store.addWordRemoval()
          } label: {
            Label("Add Removal", systemImage: "plus")
          }
          Spacer()
        }
      }
      .padding(.vertical, 4)
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Word Removals")
          .font(.headline)
        Text("Remove filler words using case-insensitive regex patterns.")
          .settingsCaption()
      }
    }
  }

  private var transformSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Picker("Mode", selection: $store.timberVoxSettings.textTransformMode) {
            ForEach(TextTransformMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.menu)

          TextField("Cloud text model", text: $store.timberVoxSettings.textTransformModel)
            .textFieldStyle(.roundedBorder)
            .disabled(!store.timberVoxSettings.textTransformMode.usesTextTransform)
        }

        if store.timberVoxSettings.textTransformMode == .customPrompt {
          TextEditor(text: $store.timberVoxSettings.customTextTransformInstructions)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 86)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        if store.timberVoxSettings.textTransformMode.usesTextTransform {
          HStack(spacing: 14) {
            Toggle(
              "App + screen",
              isOn: contextOptionBinding(\.includeApplicationContext)
            )
            .toggleStyle(.checkbox)

            Toggle(
              "Selection",
              isOn: contextOptionBinding(\.includeSelectionContext)
            )
            .toggleStyle(.checkbox)

            Toggle(
              "Clipboard",
              isOn: contextOptionBinding(\.includeClipboardContext)
            )
            .toggleStyle(.checkbox)
          }
        }
      }
      .padding(.vertical, 4)
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Text Transform")
          .font(.headline)
        Text("Voice to Text skips LLM processing. Prompt modes send the transcript and selected context to the cloud text model.")
          .settingsCaption()
      }
    }
  }

  private var remappingsSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        remappingsColumnHeaders

        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(store.timberVoxSettings.wordRemappings) { remapping in
            if let remappingBinding = remappingBinding(for: remapping.id) {
              RemappingRow(remapping: remappingBinding) {
                store.removeWordRemapping(remapping.id)
              }
            }
          }
        }

        HStack {
          Button {
            store.addWordRemapping()
          } label: {
            Label("Add Remapping", systemImage: "plus")
          }
          Spacer()
        }
      }
      .padding(.vertical, 4)
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Word Remappings")
          .font(.headline)
        Text("Replace specific words in every transcript. Matches whole words, case-insensitive, in order.")
          .settingsCaption()
      }
    }
  }

  private var removalsColumnHeaders: some View {
    HStack(spacing: 8) {
      Text("On")
        .frame(width: Layout.toggleColumnWidth, alignment: .leading)
      Text("Pattern")
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer().frame(width: Layout.deleteColumnWidth)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, Layout.rowHorizontalPadding)
  }

  private var remappingsColumnHeaders: some View {
    HStack(spacing: 8) {
      Text("On")
        .frame(width: Layout.toggleColumnWidth, alignment: .leading)
      Text("Match")
        .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "arrow.right")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: Layout.arrowColumnWidth)
      Text("Replace")
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer().frame(width: Layout.deleteColumnWidth)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, Layout.rowHorizontalPadding)
  }

  private func removalBinding(for id: UUID) -> Binding<WordRemoval>? {
    guard store.timberVoxSettings.wordRemovals.contains(where: { $0.id == id }) else {
      return nil
    }
    return Binding(
      get: {
        store.timberVoxSettings.wordRemovals.first { $0.id == id }
          ?? WordRemoval(pattern: "")
      },
      set: { newValue in
        if let idx = store.timberVoxSettings.wordRemovals.firstIndex(where: { $0.id == id }) {
          store.timberVoxSettings.wordRemovals[idx] = newValue
        }
      }
    )
  }

  private func remappingBinding(for id: UUID) -> Binding<WordRemapping>? {
    guard store.timberVoxSettings.wordRemappings.contains(where: { $0.id == id }) else {
      return nil
    }
    return Binding(
      get: {
        store.timberVoxSettings.wordRemappings.first { $0.id == id }
          ?? WordRemapping(match: "", replacement: "")
      },
      set: { newValue in
        if let idx = store.timberVoxSettings.wordRemappings.firstIndex(where: { $0.id == id }) {
          store.timberVoxSettings.wordRemappings[idx] = newValue
        }
      }
    )
  }

  private func contextOptionBinding(_ keyPath: WritableKeyPath<DictationContextOptions, Bool>) -> Binding<Bool> {
    Binding(
      get: {
        store.timberVoxSettings.textTransformContextOptions[keyPath: keyPath]
      },
      set: { newValue in
        store.timberVoxSettings.textTransformContextOptions[keyPath: keyPath] = newValue
      }
    )
  }

  private var previewText: String {
    var output = store.remappingScratchpadText
    if store.timberVoxSettings.wordRemovalsEnabled {
      output = WordRemovalApplier.apply(output, removals: store.timberVoxSettings.wordRemovals)
    }
    output = WordRemappingApplier.apply(output, remappings: store.timberVoxSettings.wordRemappings)
    return output
  }
}

private struct RemovalRow: View {
  @Binding var removal: WordRemoval
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Toggle("", isOn: $removal.isEnabled)
        .labelsHidden()
        .toggleStyle(.checkbox)
        .frame(width: Layout.toggleColumnWidth, alignment: .leading)

      TextField("Regex Pattern", text: $removal.pattern)
        .textFieldStyle(.roundedBorder)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .frame(width: Layout.deleteColumnWidth)
    }
    .padding(.horizontal, Layout.rowHorizontalPadding)
    .padding(.vertical, Layout.rowVerticalPadding)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }
}

private struct RemappingRow: View {
  @Binding var remapping: WordRemapping
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Toggle("", isOn: $remapping.isEnabled)
        .labelsHidden()
        .toggleStyle(.checkbox)
        .frame(width: Layout.toggleColumnWidth, alignment: .leading)

      TextField("Match", text: $remapping.match)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: "arrow.right")
        .foregroundStyle(.secondary)
        .frame(width: Layout.arrowColumnWidth)

      TextField("Replace", text: $remapping.replacement)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .frame(width: Layout.deleteColumnWidth)
    }
    .padding(.horizontal, Layout.rowHorizontalPadding)
    .padding(.vertical, Layout.rowVerticalPadding)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: Layout.rowCornerRadius)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }
}

private enum ModificationSection: String, CaseIterable, Identifiable {
  case removals
  case remappings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .removals:
      return "Word Removals"
    case .remappings:
      return "Word Remappings"
    }
  }
}

private enum Layout {
  static let toggleColumnWidth: CGFloat = 24
  static let deleteColumnWidth: CGFloat = 24
  static let arrowColumnWidth: CGFloat = 16
  static let rowHorizontalPadding: CGFloat = 10
  static let rowVerticalPadding: CGFloat = 6
  static let rowCornerRadius: CGFloat = 8
}

#Preview {
  WordRemappingsView(store: AppPreviewState.makeStore().settings)
    .frame(width: 700, height: 640)
}
