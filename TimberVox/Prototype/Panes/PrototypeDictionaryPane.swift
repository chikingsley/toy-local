import SwiftUI

struct PrototypeDictionaryPane: View {
  @State private var segment: DictionarySegment = .replacements
  @State private var searchText = ""
  @State private var scratchpadText = "Ok so uh I was testing deep gram against para keet on cloud flare"
  @State private var replacements = TLReplacement.mock
  @State private var removals = TLRemoval.mock
  @State private var vocabulary = TLVocabTerm.mock
  @State private var newVocabText = ""

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        searchField
      } trailing: {
        addMenu
      }
      TLPane {
        scratchpadCard

        segmentControl

        switch segment {
        case .replacements:
          replacementsSection
        case .removals:
          removalsSection
        case .vocabulary:
          vocabularySection
        }

        correctionLoopCard
      }
    }
  }

  private var searchField: some View {
    TLSearchField(placeholder: "Search the dictionary…", text: $searchText)
      .frame(maxWidth: .infinity)
  }

  private var addMenu: some View {
    Menu {
      Button("Add replacement") { addReplacement() }
      Button("Add removal") { addRemoval() }
      Button("Add term") { addTerm() }
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .medium))
        Text("Add")
          .font(.system(size: 12))
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9))
          .foregroundStyle(.tertiary)
      }
      .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private func addReplacement() {
    replacements.append(
      TLReplacement(match: "misheard phrase", replacement: "correction", source: .manual)
    )
    withAnimation(.easeInOut(duration: 0.15)) { segment = .replacements }
  }

  private func addRemoval() {
    removals.append(TLRemoval(pattern: "hmm+", note: "thinking sound"))
    withAnimation(.easeInOut(duration: 0.15)) { segment = .removals }
  }

  private func addTerm() {
    vocabulary.append(TLVocabTerm(text: "New term"))
    withAnimation(.easeInOut(duration: 0.15)) { segment = .vocabulary }
  }

  private var query: String {
    searchText.trimmingCharacters(in: .whitespaces).lowercased()
  }

  private var filteredReplacementIDs: Set<UUID> {
    guard !query.isEmpty else { return Set(replacements.map(\.id)) }
    return Set(
      replacements
        .filter { $0.match.lowercased().contains(query) || $0.replacement.lowercased().contains(query) }
        .map(\.id)
    )
  }

  private var filteredRemovalIDs: Set<UUID> {
    guard !query.isEmpty else { return Set(removals.map(\.id)) }
    return Set(
      removals
        .filter { $0.pattern.lowercased().contains(query) || $0.note.lowercased().contains(query) }
        .map(\.id)
    )
  }

  private var filteredVocabulary: [TLVocabTerm] {
    guard !query.isEmpty else { return vocabulary }
    return vocabulary.filter { $0.text.lowercased().contains(query) }
  }

  private var scratchpadCard: some View {
    TLSection(title: "Try it out") {
      TLCard {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            Image(systemName: "waveform")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
            TextField("Say something…", text: $scratchpadText)
              .textFieldStyle(.plain)
              .font(.system(size: 13))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: 8))

          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
              .font(.system(size: 10))
              .foregroundStyle(.tertiary)
            Text(previewText.isEmpty ? "Live preview appears here" : previewText)
              .font(.system(size: 13))
              .foregroundStyle(previewText.isEmpty ? .tertiary : .primary)
              .frame(maxWidth: .infinity, alignment: .leading)
            if !previewText.isEmpty {
              TLKeyChip("\(activeRuleCount) rules")
            }
          }
          .padding(.horizontal, 2)
        }
        .padding(12)
      }
    }
  }

  private var previewText: String {
    var output = scratchpadText
    for removal in removals where removal.isEnabled {
      output = output.replacingOccurrences(
        of: "\\b\(removal.pattern)\\b[,]?\\s?",
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
    }
    for replacement in replacements where replacement.isEnabled {
      output = output.replacingOccurrences(
        of: replacement.match,
        with: replacement.replacement,
        options: [.caseInsensitive]
      )
    }
    return
      output
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespaces)
  }

  private var activeRuleCount: Int {
    replacements.filter(\.isEnabled).count + removals.filter(\.isEnabled).count
  }

  private var segmentControl: some View {
    HStack(spacing: 2) {
      ForEach(DictionarySegment.allCases) { item in
        SegmentButton(
          title: item.title,
          count: count(for: item),
          isSelected: segment == item
        ) {
          withAnimation(.easeInOut(duration: 0.15)) { segment = item }
        }
      }
    }
    .padding(3)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: TLTheme.cardRadius))
  }

  private func count(for item: DictionarySegment) -> Int {
    switch item {
    case .replacements: filteredReplacementIDs.count
    case .removals: filteredRemovalIDs.count
    case .vocabulary: filteredVocabulary.count
    }
  }

  private var replacementsSection: some View {
    TLSection(
      title: "Replacements",
      hint: "Applied to every transcript, right after transcription and before the text is pasted."
    ) {
      TLSettingsCard {
        ForEach($replacements) { $entry in
          if filteredReplacementIDs.contains(entry.id) {
            ReplacementRow(entry: $entry) {
              replacements.removeAll { $0.id == entry.id }
            }
          }
        }
        if filteredReplacementIDs.isEmpty {
          NoMatchesRow(query: searchText)
        }
        AddRow(label: "Add replacement", action: addReplacement)

      }
    }
  }

  private var removalsSection: some View {
    TLSection(
      title: "Removals",
      hint: "Case-insensitive regular expressions matched against whole words, then stripped from the transcript."
    ) {
      TLSettingsCard {
        ForEach($removals) { $entry in
          if filteredRemovalIDs.contains(entry.id) {
            RemovalRow(entry: $entry) {
              removals.removeAll { $0.id == entry.id }
            }
          }
        }
        if filteredRemovalIDs.isEmpty {
          NoMatchesRow(query: searchText)
        }
        AddRow(label: "Add removal pattern", action: addRemoval)

      }
    }
  }

  private var vocabularySection: some View {
    TLSection(
      title: "Vocabulary",
      hint: "Names and jargon the recognizer should expect. These bias the speech model's decoding — no rewriting after the fact."
    ) {
      TLCard {
        VStack(alignment: .leading, spacing: 12) {
          if filteredVocabulary.isEmpty {
            Text("No terms match \u{201C}\(searchText)\u{201D}")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
          } else {
            ChipFlow(spacing: 6) {
              ForEach(filteredVocabulary) { term in
                VocabChip(term: term) {
                  vocabulary.removeAll { $0.id == term.id }
                }
              }
            }
          }

          TLSearchField(placeholder: "Add a term…", icon: "plus", text: $newVocabText)
            .onSubmit(addVocabTerm)
            .frame(maxWidth: 220)
        }
        .padding(12)
      }
    }
  }

  private func addVocabTerm() {
    let trimmed = newVocabText.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    vocabulary.append(TLVocabTerm(text: trimmed))
    newVocabText = ""
  }

  private var correctionLoopCard: some View {
    TLCard {
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .font(.system(size: 15))
          .foregroundStyle(Color.accentColor)
          .frame(width: 24)
        Text("Learn from recent dictations")
          .font(.system(size: 13, weight: .medium))
        TLInfoHint("Scans your last 20 transcripts for edits you made afterward and suggests replacements. Coming soon.")
        Spacer()
        Button("Scan now") {}
          .buttonStyle(.plain)
          .font(.system(size: 12, weight: .medium))
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
      }
      .padding(12)
    }
  }
}

private struct NoMatchesRow: View {
  let query: String

  var body: some View {
    HStack {
      Text("No entries match \u{201C}\(query)\u{201D}")
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}

private enum DictionarySegment: String, CaseIterable, Identifiable {
  case replacements, removals, vocabulary

  var id: String { rawValue }

  var title: String {
    switch self {
    case .replacements: "Replacements"
    case .removals: "Removals"
    case .vocabulary: "Vocabulary"
    }
  }
}

private struct SegmentButton: View {
  let title: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Text(title)
          .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .primary : .secondary)
        Text("\(count)")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? TLTheme.selectionFill : (hovering ? TLTheme.hoverFill : Color.clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private enum TLRuleSource {
  case manual
  case learned(Int)

  var badge: String {
    switch self {
    case .manual: "manual"
    case .learned(let count): "learned ×\(count)"
    }
  }
}

private struct TLReplacement: Identifiable {
  let id = UUID()
  var match: String
  var replacement: String
  var source: TLRuleSource
  var isEnabled = true

  static let mock: [TLReplacement] = [
    TLReplacement(match: "deep gram", replacement: "Deepgram", source: .learned(4)),
    TLReplacement(match: "para keet", replacement: "Parakeet", source: .learned(7)),
    TLReplacement(match: "cloud flare", replacement: "Cloudflare", source: .manual),
    TLReplacement(match: "fluid audio", replacement: "FluidAudio", source: .manual),
    TLReplacement(match: "ark voice", replacement: "TimberVox", source: .learned(2), isEnabled: false),
  ]
}

private struct TLRemoval: Identifiable {
  let id = UUID()
  var pattern: String
  var note: String
  var isEnabled = true

  static let mock: [TLRemoval] = [
    TLRemoval(pattern: "uh+", note: "filler"),
    TLRemoval(pattern: "um+", note: "filler"),
    TLRemoval(pattern: "you know", note: "hedge phrase"),
    TLRemoval(pattern: "like", note: "hedge word", isEnabled: false),
    TLRemoval(pattern: "ok so", note: "opener"),
  ]
}

private struct TLVocabTerm: Identifiable {
  let id = UUID()
  var text: String

  static let mock: [TLVocabTerm] = [
    "Parakeet", "FluidAudio", "Cloudflare", "TCA", "Deepgram",
    "SwiftUI", "TimberVox", "Superwhisper", "xcstrings", "CoreML",
  ].map { TLVocabTerm(text: $0) }
}

private struct EnableDot: View {
  @Binding var isEnabled: Bool

  var body: some View {
    Button {
      isEnabled.toggle()
    } label: {
      Circle()
        .fill(isEnabled ? Color.accentColor : Color.primary.opacity(0.15))
        .frame(width: 8, height: 8)
        .padding(4)
        .contentShape(Circle().inset(by: -4))
    }
    .buttonStyle(.plain)
    .help(isEnabled ? "Enabled — click to disable" : "Disabled — click to enable")
  }
}

private struct ReplacementRow: View {
  @Binding var entry: TLReplacement
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 10) {
      EnableDot(isEnabled: $entry.isEnabled)

      Text(entry.match.capitalized)
        .font(.system(size: 13))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)
      Image(systemName: "arrow.right")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.tertiary)
      Text(entry.replacement)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)

      Spacer()

      TLKeyChip(entry.source.badge)

      DeleteButton(visible: hovering, action: onDelete)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

private struct RemovalRow: View {
  @Binding var entry: TLRemoval
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 10) {
      EnableDot(isEnabled: $entry.isEnabled)

      Text(entry.pattern)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(entry.isEnabled ? .primary : .tertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))

      Text(entry.note)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)

      Spacer()

      TLKeyChip("regex")

      DeleteButton(visible: hovering, action: onDelete)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

private struct DeleteButton: View {
  let visible: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "trash")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .opacity(visible ? 1 : 0)
    .help("Delete")
  }
}

private struct AddRow: View {
  let label: String
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .medium))
        Text(label)
          .font(.system(size: 12))
        Spacer()
      }
      .foregroundStyle(hovering ? .primary : .secondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct VocabChip: View {
  let term: TLVocabTerm
  let onDelete: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 4) {
      Text(term.text)
        .font(.system(size: 12))
      if hovering {
        Button(action: onDelete) {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(.primary.opacity(hovering ? 0.12 : 0.07), in: Capsule())
    .onHover { value in
      withAnimation(.easeInOut(duration: 0.12)) { hovering = value }
    }
  }
}

private struct ChipFlow: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    return arrange(subviews: subviews, in: width).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let arrangement = arrange(subviews: subviews, in: bounds.width)
    for (subview, position) in zip(subviews, arrangement.positions) {
      subview.place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func arrange(subviews: Subviews, in width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
    }

    return (CGSize(width: maxX, height: y + rowHeight), positions)
  }
}

#Preview("Dictionary") {
  TLFloatingHost {
    PrototypeDictionaryPane()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
