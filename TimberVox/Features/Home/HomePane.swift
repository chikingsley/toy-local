import TimberVoxCore
import SwiftUI

private struct HomeTile: Identifiable {
  let icon: String
  let title: String
  var destination: TLDestination?
  var id: String { title }
}

private struct HomeStats {
  private static let secondsPerMinute = 60.0
  static let typingWPM = 40

  let wordCount: Int
  let averageWPM: Int
  let appCount: Int
  let savedSeconds: TimeInterval

  init(records: [TranscriptRecord]) {
    let computedWordCount = records.reduce(0) { total, record in
      total + Self.wordCount(in: record.finalText)
    }
    let totalDuration = records.reduce(0) { total, record in
      total + max(0, record.duration)
    }
    let computedAverageWPM: Int
    if totalDuration > 0, computedWordCount > 0 {
      computedAverageWPM = Int((Double(computedWordCount) / (totalDuration / Self.secondsPerMinute)).rounded())
    } else {
      computedAverageWPM = 0
    }
    let typingSeconds = Double(computedWordCount) / Double(Self.typingWPM) * Self.secondsPerMinute

    wordCount = computedWordCount
    averageWPM = computedAverageWPM
    appCount = Set(records.compactMap(\.sourceAppBundleID)).count
    savedSeconds = max(0, typingSeconds - totalDuration)
  }

  var averageSpeedValue: String {
    "\(averageWPM.formatted()) WPM"
  }

  var wordsValue: String {
    wordCount.formatted()
  }

  var appsUsedValue: String {
    appCount.formatted()
  }

  var timeSavedValue: String {
    Self.formatSavedTime(savedSeconds)
  }

  private static func wordCount(in text: String) -> Int {
    text.split { $0.isWhitespace || $0.isNewline }.count
  }

  private static func formatSavedTime(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int((seconds / Self.secondsPerMinute).rounded()))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0, minutes > 0 {
      return "\(hours) hr \(minutes) min"
    }
    if hours > 0 {
      return "\(hours) hr"
    }
    return "\(minutes) min"
  }
}

struct HomePane: View {
  private static let systemDefaultMicrophoneID = "system-default-input"

  @Bindable var historyStore: HistoryStore
  @Bindable var settingsStore: SettingsStore
  @State private var urlText = ""
  @Environment(\.tlNavigate) private var navigate

  init(historyStore: HistoryStore, settingsStore: SettingsStore) {
    self.historyStore = historyStore
    self.settingsStore = settingsStore
  }

  private let tiles: [HomeTile] = [
    HomeTile(icon: "record.circle", title: "Start Recording"),
    HomeTile(icon: "folder", title: "Transcribe Files"),
    HomeTile(icon: "speaker.wave.2", title: "System Audio"),
    HomeTile(icon: "waveform.badge.mic", title: "Always-On"),
    HomeTile(icon: "plus.square.on.square", title: "Create a Mode", destination: .createMode),
    HomeTile(icon: "character.book.closed", title: "Add Vocabulary", destination: .tab(.dictionary)),
    HomeTile(icon: "square.stack.3d.up", title: "Manage Models", destination: .tab(.models)),
    HomeTile(icon: "plus", title: "Add Shortcut", destination: .tab(.configuration)),
  ]

  private var stats: HomeStats {
    HomeStats(records: historyStore.records)
  }

  private var todayItems: [HistoryItem] {
    Array(
      historyStore.records
        .filter { Calendar.current.isDateInToday($0.createdAt) }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(HomePaneMetrics.todayLimit)
        .map(HistoryItem.init(record:)))
  }

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        EmptyView()
      } trailing: {
        microphoneMenu
      }
      paneContent
    }
    .onAppear {
      historyStore.search("")
      settingsStore.loadAvailableInputDevices()
    }
  }

  private var paneContent: some View {
    TLPane {
      statsSection

      TLSearchField(
        placeholder: "Enter YouTube, audio or video file URL...",
        icon: "link",
        text: $urlText
      )

      quickActionsSection
      todaySection
      whatsNewSection
    }
  }

  private var microphoneMenu: some View {
    TLHeaderMicrophoneMenu(selection: microphoneSelection, options: microphoneOptions)
  }

  private var microphoneSelection: Binding<String> {
    Binding(
      get: { settingsStore.timberVoxSettings.selectedMicrophoneID ?? Self.systemDefaultMicrophoneID },
      set: { selectedID in
        settingsStore.timberVoxSettings.selectedMicrophoneID =
          selectedID == Self.systemDefaultMicrophoneID ? nil : selectedID
      }
    )
  }

  private var microphoneOptions: [TLMenuOption<String>] {
    var options = [
      TLMenuOption(
        value: Self.systemDefaultMicrophoneID,
        label: defaultMicrophoneLabel,
        systemImage: "headphones"
      )
    ]

    options.append(
      contentsOf: settingsStore.availableInputDevices.map { device in
        TLMenuOption(value: device.id, label: device.name, systemImage: "headphones")
      }
    )

    if let selectedID = settingsStore.timberVoxSettings.selectedMicrophoneID,
      !options.contains(where: { $0.value == selectedID })
    {
      options.append(
        TLMenuOption(
          value: selectedID,
          label: "Unavailable microphone",
          systemImage: "headphones",
          accessoryText: "Missing"
        )
      )
    }

    return options
  }

  private var defaultMicrophoneLabel: String {
    if let name = settingsStore.defaultInputDeviceName, !name.isEmpty {
      return "System Default (\(name))"
    }
    return "System Default"
  }

  private var statsSection: some View {
    TLSection(title: "All time") {
      TLCard {
        HStack(spacing: 0) {
          TLStat(value: stats.averageSpeedValue, label: "Average speed")
          TLStat(value: stats.wordsValue, label: "Words")
          TLStat(value: stats.appsUsedValue, label: "Apps used")
          TLStat(value: stats.timeSavedValue, label: "Saved all time", showsGear: true)
        }
      }
    }
  }

  private var quickActionsSection: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: HomePaneMetrics.tileMinimumWidth), spacing: 10)], spacing: 10) {
      ForEach(tiles) { tile in
        TLTile(icon: tile.icon, title: tile.title) {
          if let destination = tile.destination {
            navigate(destination)
          }
        }
      }
    }
  }

  private var todaySection: some View {
    TLSection(title: "Today", trailing: "View all") {
      if todayItems.isEmpty {
        TLSettingsCard(dividerInset: 12) {
          TLRow(
            icon: "text.bubble",
            title: "No recordings today",
            subtitle: "New dictations will appear here after they are saved."
          )
        }
      } else {
        VStack(spacing: HistoryMetrics.rowSpacing) {
          ForEach(todayItems) { item in
            HistoryRow(item: item) {
              navigate(.historyItem(item.id))
            }
          }
        }
      }
    }
  }

  private var whatsNewSection: some View {
    TLSection(title: "What's new?", trailing: "View all changes") {
      TLSettingsCard(dividerInset: 12) {
        TLRow(
          icon: "sparkles",
          title: "Sidebar redesign",
          subtitle: "Jul 3 - New navigation, seamless header, icon rail collapse."
        )
        TLRow(
          icon: "keyboard",
          title: "Always-on hotkeys editable",
          subtitle: "Jul 2 - Paste and dump shortcuts can now be recorded in Shortcuts."
        )
      }
    }
  }
}

private enum HomePaneMetrics {
  static let todayLimit = 3
  static let tileMinimumWidth: CGFloat = 160
  static let previewWidth: CGFloat = 620
  static let previewHeight: CGFloat = 700
}

#Preview("Home") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    HomePane(historyStore: store.history, settingsStore: store.settings)
      .frame(width: HomePaneMetrics.previewWidth, height: HomePaneMetrics.previewHeight)
      .background(TLTheme.windowBackground)
  }
}
