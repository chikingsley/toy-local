import SwiftUI

private struct VocabEntryV2: Identifiable, Equatable {
  let id = UUID()
  var word: String
  var replacement: String?

  static let samples: [VocabEntryV2] = [
    VocabEntryV2(word: "super whisper", replacement: "Superwhisper"),
    VocabEntryV2(word: "Superwhisper", replacement: nil),
    VocabEntryV2(word: "ark voice", replacement: "TimberVox"),
    VocabEntryV2(word: "Parakeet", replacement: nil),
    VocabEntryV2(word: "FluidAudio", replacement: nil),
  ]
}

struct PrototypeDictionaryPaneV2: View {
  private enum SidePanel: Equatable {
    case importCSV
    case edit(VocabEntryV2.ID)
  }

  @State private var entries = VocabEntryV2.samples
  @State private var searchText = ""
  @State private var newWord = ""
  @State private var panel: SidePanel?
  @State private var editWord = ""
  @State private var editReplacement = ""

  private var filteredEntries: [VocabEntryV2] {
    guard !searchText.isEmpty else { return entries }
    return entries.filter {
      $0.word.localizedCaseInsensitiveContains(searchText)
        || ($0.replacement ?? "").localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      VStack(spacing: 0) {
        TLHeader {
          TLSearchField(placeholder: "Search vocabulary", text: $searchText)
            .frame(maxWidth: .infinity)
        } trailing: {
          Button {
            panel = panel == .importCSV ? nil : .importCSV
          } label: {
            Image(systemName: "doc.badge.arrow.up.fill")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 28)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help("Import vocabulary")
        }

        TLPane {
          addField
          entryList
        }
      }

      if let panel {
        Rectangle()
          .fill(.black.opacity(0.001))
          .ignoresSafeArea()
          .onTapGesture { self.panel = nil }
        sidePanel(panel)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.18), value: panel)
  }

  private var addField: some View {
    HStack(spacing: 8) {
      TextField("Add a word or create a snippet", text: $newWord)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .onSubmit(addWord)
      HStack(spacing: 5) {
        Text("Add word")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        TLKeyChip("⏎")
      }
      HStack(spacing: 5) {
        Text("Replace with…")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        TLKeyChip("⌘")
        TLKeyChip("⏎")
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 40)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: TLTheme.cardRadius))
  }

  private var entryList: some View {
    VStack(spacing: 2) {
      ForEach(filteredEntries) { entry in
        VocabRowV2(entry: entry) {
          beginEditing(entry)
        } delete: {
          entries.removeAll { $0.id == entry.id }
        }
      }
    }
  }

  private func addWord() {
    let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    entries.insert(VocabEntryV2(word: trimmed, replacement: nil), at: 0)
    newWord = ""
  }

  private func beginEditing(_ entry: VocabEntryV2) {
    editWord = entry.word
    editReplacement = entry.replacement ?? ""
    panel = .edit(entry.id)
  }

  @ViewBuilder private func sidePanel(_ panel: SidePanel) -> some View {
    switch panel {
    case .importCSV:
      importPanel
    case .edit(let id):
      editPanel(id)
    }
  }

  private var importPanel: some View {
    VocabSidePanelV2(title: "Import vocabulary", onBack: { panel = nil }) {
      VStack(alignment: .leading, spacing: 12) {
        VStack(spacing: 6) {
          Image(systemName: "doc.text.fill")
            .font(.system(size: 16))
          Text("Import CSV")
            .font(.system(size: 13, weight: .semibold))
          Text("Drag and drop or select file")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(TLTheme.borderStroke, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .contentShape(Rectangle())

        HStack(spacing: 6) {
          Image(systemName: "info.circle")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          Text("Example file")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
          Spacer()
          Text("word")
            .font(.system(size: 11, design: .monospaced))
          Text("and")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          Text("replacement")
            .font(.system(size: 11, design: .monospaced))
          Text("headers required")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func editPanel(_ id: VocabEntryV2.ID) -> some View {
    VocabSidePanelV2(
      title: "Edit replacement",
      onBack: { panel = nil },
      trailing: {
        Button("Delete") {
          entries.removeAll { $0.id == id }
          panel = nil
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(TLTheme.destructive)
      }
    ) {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Replace")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
          TextField("", text: $editWord)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
        }

        VStack(alignment: .leading, spacing: 6) {
          Text("With")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
          TextEditor(text: $editReplacement)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(height: 96)
            .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: 8))
        }

        Spacer()

        VStack(spacing: 10) {
          Button {
            if let index = entries.firstIndex(where: { $0.id == id }) {
              entries[index].word = editWord
              entries[index].replacement = editReplacement.isEmpty ? nil : editReplacement
            }
            panel = nil
          } label: {
            Text("Save")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 36)
              .background(TLTheme.accentBlue, in: RoundedRectangle(cornerRadius: 9))
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          Button("Cancel") { panel = nil }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
    }
  }
}

private struct VocabRowV2: View {
  let entry: VocabEntryV2
  let open: () -> Void
  let delete: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: open) {
      HStack(spacing: 10) {
        Text(entry.word)
          .font(.system(size: 13))
        if let replacement = entry.replacement {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Text(replacement)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        Spacer()
        if hovering {
          Button(action: delete) {
            Image(systemName: "xmark")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.secondary)
              .frame(width: 22, height: 22)
              .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: 6))
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help("Remove")
        }
      }
      .padding(.horizontal, 14)
      .frame(height: 38)
      .background(
        RoundedRectangle(cornerRadius: 9)
          .fill(hovering ? TLTheme.hoverFill : .clear)
      )
      .contentShape(RoundedRectangle(cornerRadius: 9))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct VocabSidePanelV2<Trailing: View, Content: View>: View {
  let title: String
  let onBack: () -> Void
  @ViewBuilder var trailing: Trailing
  @ViewBuilder var content: Content

  init(
    title: String,
    onBack: @escaping () -> Void,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() },
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.onBack = onBack
    self.trailing = trailing()
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        HStack {
          Button(action: onBack) {
            Image(systemName: "chevron.left")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)
              .frame(width: 28, height: 28)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Spacer()
          trailing
        }
        Text(title)
          .font(.system(size: 13, weight: .semibold))
      }
      .padding(.horizontal, 10)
      .frame(height: TLTheme.headerHeight)
      .overlay(alignment: .bottom) {
        Rectangle().fill(TLTheme.hairline).frame(height: 1)
      }

      content
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(width: 400)
    .frame(maxHeight: .infinity)
    .background(TLTheme.windowBackground)
    .overlay(alignment: .leading) {
      Rectangle().fill(TLTheme.hairline).frame(width: 1)
    }
  }
}

#Preview("Dictionary V2") {
  TLFloatingHost {
    PrototypeDictionaryPaneV2()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
