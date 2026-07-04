import SwiftUI

private let historyAccentGreen = TLTheme.accentGreen
private let historyPlaybackBlue = Color.accentColor
private let historyCardFill = Color.primary.opacity(0.075)

extension View {
  fileprivate func historyBorderedCard(
    fill: Color = historyCardFill,
    cornerRadius: CGFloat = 11
  ) -> some View {
    background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(TLTheme.borderStroke, lineWidth: 1)
      )
  }
}

struct PrototypeHistoryPane: View {
  private enum Route: Equatable {
    case list
    case detail(HistoryItem.ID)
  }

  @Binding var deepLinkItemID: String?

  init(deepLinkItemID: Binding<String?> = .constant(nil)) {
    self._deepLinkItemID = deepLinkItemID
  }

  @State private var route: Route = .list
  @State private var appFilter: HistoryAppFilter = .all
  @State private var dayFilter: String? = nil
  @State private var searchText = ""
  @State private var titleOverrides: [HistoryItem.ID: String] = [:]
  @State private var editingTitleID: HistoryItem.ID? = nil
  @State private var titleDraft = ""
  @State private var detailSheetItem: HistoryItem? = nil
  @State private var headerCopiedItemID: HistoryItem.ID? = nil

  private var filteredItems: [HistoryItem] {
    HistoryItem.samples.filter { item in
      let appMatch = appFilter.app == nil || item.app == appFilter.app
      let dayMatch = dayFilter == nil || item.dayLabel == dayFilter
      let searchMatch =
        searchText.isEmpty
        || item.title.localizedCaseInsensitiveContains(searchText)
        || item.preview.localizedCaseInsensitiveContains(searchText)
        || item.app.rawValue.localizedCaseInsensitiveContains(searchText)
      return appMatch && dayMatch && searchMatch
    }
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      VStack(spacing: 0) {
        TLHeader(
          control: route == .list
            ? .sidebarToggle
            : .back {
              withAnimation(.easeInOut(duration: 0.18)) {
                route = .list
              }
            }
        ) {
          if route == .list {
            TLSearchField(placeholder: "Search history", text: $searchText)
              .frame(maxWidth: .infinity)
          } else if case .detail(let itemID) = route, let item = item(for: itemID) {
            HStack(spacing: 9) {
              HistoryAppIcon(app: item.app, size: 24)
              HistoryEditableTitle(
                title: titleOverrides[item.id] ?? item.title,
                draft: $titleDraft,
                isEditing: editingTitleID == item.id,
                beginEditing: {
                  titleDraft = titleOverrides[item.id] ?? item.title
                  editingTitleID = item.id
                },
                commit: {
                  let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                  if !trimmedTitle.isEmpty {
                    titleOverrides[item.id] = trimmedTitle
                  }
                  editingTitleID = nil
                },
                cancel: {
                  titleDraft = titleOverrides[item.id] ?? item.title
                  editingTitleID = nil
                }
              )
              Text("•")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
              Text(item.timeLabel)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
              Spacer(minLength: 0)
            }
          }
        } trailing: {
          if route == .list {
            historyToolbar
          } else if case .detail(let itemID) = route, let item = item(for: itemID) {
            HistoryHeaderActions(
              copied: headerCopiedItemID == item.id,
              openDetails: { detailSheetItem = item },
              copy: { copyHeaderItem(item) }
            )
          }
        }

        switch route {
        case .list:
          listPage
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .detail(let itemID):
          if let item = item(for: itemID) {
            detailPage(item)
              .transition(.opacity.combined(with: .move(edge: .trailing)))
          }
        }
      }

      if let detailSheetItem {
        Color.black.opacity(0.24)
          .ignoresSafeArea()
          .onTapGesture { self.detailSheetItem = nil }

        HistoryRecordingDetailsSheet(item: detailSheetItem, title: titleOverrides[detailSheetItem.id] ?? detailSheetItem.title) {
          self.detailSheetItem = nil
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.18), value: route)
    .animation(.easeInOut(duration: 0.18), value: detailSheetItem)
    .onAppear(perform: consumeDeepLink)
    .onChange(of: deepLinkItemID) { _, _ in
      consumeDeepLink()
    }
  }

  private func consumeDeepLink() {
    guard let id = deepLinkItemID else { return }
    deepLinkItemID = nil
    guard item(for: id) != nil else { return }
    route = .detail(id)
  }

  private func item(for id: HistoryItem.ID) -> HistoryItem? {
    HistoryItem.samples.first { $0.id == id }
  }

  private func copyHeaderItem(_ item: HistoryItem) {
    headerCopiedItemID = item.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
      if headerCopiedItemID == item.id {
        headerCopiedItemID = nil
      }
    }
  }

  private var historyToolbar: some View {
    HStack(spacing: 8) {
      TLOptionMenu(
        selection: $dayFilter,
        options: HistoryDayFilter.options(for: HistoryItem.samples),
        width: 112,
        panelWidth: 150
      )
      TLOptionMenu(
        selection: $appFilter,
        options: HistoryAppFilter.options,
        width: 110,
        panelWidth: 156
      )
    }
    .fixedSize()
  }

  private var listPage: some View {
    VStack(alignment: .leading, spacing: 16) {
      TLScrollArea(
        contentPadding: EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0),
        spacing: 18
      ) {
        ForEach(HistoryDayFilter.orderedDayLabels(for: filteredItems), id: \.self) { day in
          let items = filteredItems.filter { $0.dayLabel == day }
          if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Text(day)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
              VStack(spacing: 8) {
                ForEach(items) { item in
                  HistoryRow(item: item) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                      titleDraft = titleOverrides[item.id] ?? item.title
                      editingTitleID = nil
                      route = .detail(item.id)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder private func detailPage(_ item: HistoryItem) -> some View {
    HistoryDetail(item: item, title: titleOverrides[item.id] ?? item.title)
  }
}

private struct HistoryEditableTitle: View {
  let title: String
  @Binding var draft: String
  let isEditing: Bool
  let beginEditing: () -> Void
  let commit: () -> Void
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      if isEditing {
        TextField("Title", text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 190)
          .padding(.horizontal, 8)
          .frame(height: 26)
          .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        TLIconButton(
          systemName: "checkmark",
          tileSize: 22,
          hitSize: 28,
          foreground: historyAccentGreen,
          help: "Save title",
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
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct HistoryHeaderActions: View {
  let copied: Bool
  let openDetails: () -> Void
  let copy: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TLIconButton(systemName: "info.circle", tileSize: 22, hitSize: 28, help: "Recording details", action: openDetails)
      TLIconButton(
        systemName: copied ? "checkmark" : "doc.on.doc",
        tileSize: 22,
        hitSize: 28,
        foreground: copied ? historyAccentGreen : nil,
        help: copied ? "Copied" : "Copy transcript",
        action: copy
      )
      TLIconButton(systemName: "goforward.15", tileSize: 22, hitSize: 28, help: "Replay action") {}
      TLIconButton(systemName: "trash", tileSize: 22, hitSize: 28, foreground: .red.opacity(0.9), help: "Delete") {}
    }
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(.secondary)
  }
}

enum HistoryScope {
  case dictations, transcriptions
}

enum HistoryDayFilter {
  static func options(for items: [HistoryItem]) -> [TLMenuOption<String?>] {
    let labels = orderedDayLabels(for: items)
    return [TLMenuOption(value: String?.none, label: "Any day", systemImage: "calendar")]
      + labels.map { TLMenuOption(value: $0, label: $0, systemImage: "calendar") }
  }

  static func orderedDayLabels(for items: [HistoryItem]) -> [String] {
    var seen = Set<String>()
    return items.sorted { $0.date > $1.date }.compactMap { item in
      seen.insert(item.dayLabel).inserted ? item.dayLabel : nil
    }
  }
}

private enum HistoryAppFilter: String, CaseIterable, Hashable {
  case all = "Apps"
  case xcode = "Xcode"
  case mail = "Mail"
  case notes = "Notes"
  case zoom = "Zoom"
  case safari = "Safari"
  case finder = "Finder"

  var app: HistoryApp? {
    switch self {
    case .all: nil
    case .xcode: .xcode
    case .mail: .mail
    case .notes: .notes
    case .zoom: .zoom
    case .safari: .safari
    case .finder: .finder
    }
  }

  var icon: String {
    app?.icon ?? "square.grid.2x2"
  }

  static var options: [TLMenuOption<HistoryAppFilter>] {
    HistoryAppFilter.allCases.map {
      TLMenuOption(value: $0, label: $0.rawValue, systemImage: $0.icon)
    }
  }
}

enum HistoryApp: String, CaseIterable, Identifiable {
  case xcode = "Xcode"
  case mail = "Mail"
  case notes = "Notes"
  case zoom = "Zoom"
  case safari = "Safari"
  case finder = "Finder"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .xcode: "hammer.fill"
    case .mail: "envelope.fill"
    case .notes: "note.text"
    case .zoom: "video.fill"
    case .safari: "safari.fill"
    case .finder: "folder.fill"
    }
  }

  var tint: Color {
    switch self {
    case .xcode: .blue
    case .mail: .cyan
    case .notes: .yellow
    case .zoom: .indigo
    case .safari: .blue
    case .finder: .orange
    }
  }
}

struct HistoryItem: Identifiable, Equatable {
  let id: String
  let scope: HistoryScope
  let app: HistoryApp
  let title: String
  let preview: String
  let date: Date
  let duration: String
  let mode: String
  let speakers: Int?

  var dayLabel: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(.dateTime.month(.abbreviated).day())
  }

  var timeLabel: String {
    date.formatted(date: .omitted, time: .shortened)
  }

  var dateLabel: String {
    date.formatted(date: .abbreviated, time: .omitted)
  }

  static func stamp(daysAgo: Int, hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
  }

  static let samples: [HistoryItem] = [
    HistoryItem(
      id: "dictation-xcode-1", scope: .dictations, app: .xcode, title: "MacWhisper",
      preview:
        "The history is just not great for me. It's ugly and it's over complicated. I want the context, the app, the time, and the length, but not a pile of metadata in the way. The actual reading surface should feel like a working transcript, not a dashboard. I want enough body text here that the detail page has something to scroll, so we can see how the bottom playback dock and the fading edge interact with the text. The transcript should feel like it belongs directly on the page, with the controls anchored below it, and the extra recording details living in the side sheet where they do not interrupt reading.",
      date: stamp(daysAgo: 0, hour: 18, minute: 14), duration: "0:38", mode: "Vibe Code", speakers: nil),
    HistoryItem(
      id: "dictation-xcode-2", scope: .dictations, app: .xcode, title: "Xcode note",
      preview: "Add a separate one so we can go back and forth and compare. Let's go ahead and do that.",
      date: stamp(daysAgo: 0, hour: 17, minute: 34),
      duration: "0:07", mode: "Default", speakers: nil),
    HistoryItem(
      id: "dictation-mail", scope: .dictations, app: .mail, title: "Release follow-up",
      preview: "Hey, just following up on the release notes. I left two small comments, otherwise it looks ready to ship.",
      date: stamp(daysAgo: 0, hour: 13, minute: 20), duration: "0:09", mode: "Email", speakers: nil),
    HistoryItem(
      id: "file-unit-14", scope: .transcriptions, app: .finder, title: "Pimsleur French I - Unit 14",
      preview:
        "This is Unit 14 de Pimsleur's Speak and Read Essential French 1. Ecoutez cette conversation francaise. Un monsieur americain veut acheter un journal.",
      date: stamp(daysAgo: 92, hour: 18, minute: 7), duration: "26:59", mode: "Parakeet v3", speakers: 5),
    HistoryItem(
      id: "file-meeting", scope: .transcriptions, app: .zoom, title: "Design review - sidebar and history",
      preview: "Decisions around one History roof, separating dictations from file transcriptions, and moving detailed metadata into an inspector.",
      date: stamp(daysAgo: 1, hour: 15, minute: 44), duration: "42:18", mode: "Meeting Notes", speakers: 4),
  ]
}

private struct HistoryRow: View {
  let item: HistoryItem
  let open: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: open) {
      historyCard
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }

  private var historyCard: some View {
    HStack(alignment: .top, spacing: 12) {
      HistoryAppIcon(app: item.app)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(item.scope == .dictations ? item.app.rawValue : item.title)
            .font(.system(size: 13, weight: .semibold))
          Text(item.timeLabel)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Spacer()
          if let speakers = item.speakers {
            Text("\(speakers) speakers")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        Text(item.preview)
          .font(.system(size: 13))
          .lineLimit(2)
        HStack(spacing: 8) {
          if item.scope == .dictations {
            TLKeyChip(item.app.rawValue)
          }
          TLKeyChip(item.duration)
          TLKeyChip(item.mode)
        }
      }
      if item.scope == .dictations {
        HistoryRowActions()
          .opacity(hovering ? 1 : 0)
      }
    }
    .padding(14)
    .historyBorderedCard(fill: .primary.opacity(hovering ? 0.11 : 0.075), cornerRadius: 14)
  }
}

private struct HistoryAppIcon: View {
  let app: HistoryApp
  var size: CGFloat = 26

  var body: some View {
    Image(systemName: app.icon)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(app.tint.gradient, in: RoundedRectangle(cornerRadius: 7))
  }
}

private struct HistoryRowActions: View {
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "play.fill")
      Image(systemName: "doc.on.doc")
      Image(systemName: "trash")
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(.secondary)
  }
}

private struct HistoryDetail: View {
  let item: HistoryItem
  let title: String
  @State private var selectedTextView = "Processed"

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      TLScrollArea(
        contentPadding: EdgeInsets(top: 18, leading: 18, bottom: 46, trailing: 18),
        spacing: 18
      ) {
        ForEach(detailTurns) { turn in
          HStack(alignment: .top, spacing: 14) {
            if let speaker = turn.speaker {
              Text(speaker)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(turn.color)
                .frame(width: 72, alignment: .trailing)
            }

            Text(turn.text)
              .font(.system(size: 14, weight: .semibold))
              .lineSpacing(8)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .mask(
        LinearGradient(
          stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.86),
            .init(color: .clear, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )

      HistoryPlaybackBar(duration: item.duration)

      ZStack {
        HStack {
          Text("\(item.app.rawValue) - \(wordCount) words")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          Spacer()
          Picker("", selection: $selectedTextView) {
            Text("Raw").tag("Raw")
            Text("Processed").tag("Processed")
          }
          .pickerStyle(.segmented)
          .frame(width: 174)
        }

        HistorySpeedMenu()
      }
      .padding(.top, 8)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(.primary.opacity(0.1))
          .frame(height: 1)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var wordCount: Int {
    detailTurns.map(\.text).joined(separator: " ").split { $0.isWhitespace || $0.isNewline }.count
  }

  private var detailTurns: [HistoryTurn] {
    if item.scope == .transcriptions {
      return [
        HistoryTurn(speaker: "Speaker 1", text: item.preview, color: .red),
        HistoryTurn(
          speaker: "Speaker 1", text: "Ecoutez cette conversation francaise. Un monsieur americain veut acheter un journal. A newspaper. Un journal.",
          color: .red),
        HistoryTurn(speaker: "Speaker 2", text: "Oui, monsieur. Merci. Je vous dois combien?", color: .cyan),
        HistoryTurn(speaker: "Speaker 1", text: "Voila. C'est 8 francs. Vous me devez 8 francs.", color: .red),
      ]
    }

    return [
      HistoryTurn(speaker: nil, text: item.preview, color: .primary)
    ]
  }
}

private struct HistoryTurn: Identifiable {
  let id = UUID()
  let speaker: String?
  let text: String
  let color: Color
}

private struct HistoryRecordingDetailsSheet: View {
  let item: HistoryItem
  let title: String
  let close: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(action: close) {
          Image(systemName: "chevron.left")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        Spacer()
        Text("Recording Details")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Color.clear.frame(width: 32, height: 32)
      }
      .padding(.horizontal, 12)
      .frame(height: 48)
      .overlay(alignment: .bottom) {
        Rectangle().fill(.primary.opacity(0.1)).frame(height: 1)
      }

      VStack(alignment: .leading, spacing: 14) {
        Text("\(item.dateLabel) at \(item.timeLabel)")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(historyAccentGreen)
              .frame(width: 36, height: 36)
              .background(historyAccentGreen.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
              Text(item.mode)
                .font(.system(size: 13, weight: .semibold))
              Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Label("English", systemImage: "globe")
              .font(.system(size: 10, weight: .semibold))
              .padding(.horizontal, 8)
              .frame(height: 25)
              .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
          }

          HStack(spacing: 8) {
            TLKeyChip(item.scope == .transcriptions ? "System Audio" : "Mic Only")
            TLKeyChip("\(wordCount) words")
          }
        }
        .padding(12)
        .historyBorderedCard()

        Text("Recording")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 2)

        VStack(spacing: 0) {
          recordingRow(icon: "mic.fill", label: item.scope == .transcriptions ? "System Audio" : "Default Input", value: item.duration)
          TLDivider(leadingInset: 50)
          recordingRow(icon: "waveform", label: item.scope == .transcriptions ? item.mode : "Parakeet Multilingual", value: "118ms")
          TLDivider(leadingInset: 50)
          recordingRow(icon: "sparkles", label: "S1-Language", value: "480ms")
        }
        .historyBorderedCard()

        Spacer()

        Button {
        } label: {
          Label("Open File Location", systemImage: "folder")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .frame(height: 34)
        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))

        Button {
        } label: {
          Label("Report Issue", systemImage: "info.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .frame(height: 34)
        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
      }
      .padding(16)
    }
    .frame(width: 330)
    .frame(maxHeight: .infinity)
    .background(TLTheme.windowBackground)
    .overlay(alignment: .leading) {
      Rectangle().fill(.primary.opacity(0.1)).frame(width: 1)
    }
  }

  private var wordCount: Int {
    item.preview.split { $0.isWhitespace || $0.isNewline }.count
  }

  private func recordingRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 28, height: 28)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
      Spacer()
      Text(value)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
  }
}

private struct HistoryPlaybackBar: View {
  let duration: String
  @State private var progress = 0.0

  var body: some View {
    HStack(spacing: 12) {
      Button {
      } label: {
        Image(systemName: "play.fill")
          .font(.system(size: 12, weight: .bold))
          .frame(width: 28, height: 28)
          .background(.primary.opacity(0.09), in: Circle())
      }
      .buttonStyle(.plain)

      Text("0:00")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 32, alignment: .leading)

      Slider(value: $progress, in: 0...1)
        .tint(historyPlaybackBlue)
        .controlSize(.small)

      Text(duration)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 42, alignment: .trailing)
    }
    .padding(.horizontal, 12)
    .frame(height: 48)
    .historyBorderedCard()
  }
}

private struct HistorySpeedMenu: View {
  @State private var speed = "1x"
  private let speeds = ["0.25x", "0.5x", "0.75x", "1x", "1.25x", "1.5x", "2x", "2.5x", "3x"]

  var body: some View {
    Menu {
      ForEach(speeds, id: \.self) { option in
        Button {
          speed = option
        } label: {
          if speed == option {
            Label(option, systemImage: "checkmark")
          } else {
            Text(option)
          }
        }
      }
    } label: {
      Text(speed)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: 38, height: 28)
        .background(.primary.opacity(0.075), in: Capsule())
        .overlay(
          Capsule()
            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }
}

#Preview("History") {
  TLFloatingHost {
    PrototypeHistoryPane()
      .frame(width: 640, height: 680)
      .background(TLTheme.windowBackground)
  }
}
