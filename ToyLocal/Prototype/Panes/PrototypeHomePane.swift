import SwiftUI

private struct HomeTile: Identifiable {
  let icon: String
  let title: String
  var destination: TLDestination?
  var id: String { title }
}

struct PrototypeHomePane: View {
  @State private var urlText = ""
  @State private var microphone = TLMicrophoneSource.devices[0]
  @Environment(\.tlNavigate) private var navigate

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

  private var todayItems: [HistoryItem] {
    Array(
      HistoryItem.samples
        .filter { Calendar.current.isDateInToday($0.date) }
        .sorted { $0.date > $1.date }
        .prefix(3))
  }

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        EmptyView()
      } trailing: {
        TLHeaderMicrophoneMenu(selection: $microphone)
      }
      paneContent
    }
  }

  private var paneContent: some View {
    TLPane {
      TLSection(title: "All time") {
        TLCard {
          HStack(spacing: 0) {
            TLStat(value: "128 WPM", label: "Average speed")
            TLStat(value: "42,381", label: "Words")
            TLStat(value: "12", label: "Apps used")
            TLStat(value: "9.4 hours", label: "Saved all time", showsGear: true)
          }
        }
      }

      TLSearchField(
        placeholder: "Enter YouTube, audio or video file URL…",
        icon: "link",
        text: $urlText
      )

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
        ForEach(tiles) { tile in
          TLTile(icon: tile.icon, title: tile.title) {
            if let destination = tile.destination {
              navigate(destination)
            }
          }
        }
      }

      TLSection(title: "Today", trailing: "View all") {
        TLSettingsCard(dividerInset: 12) {
          ForEach(todayItems) { item in
            Button {
              navigate(.historyItem(item.id))
            } label: {
              TLRow(
                icon: item.app.icon,
                title: item.preview,
                subtitle: "\(item.app.rawValue) · \(item.timeLabel) · \(item.duration)"
              )
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      }

      TLSection(title: "What's new?", trailing: "View all changes") {
        TLSettingsCard(dividerInset: 12) {
          TLRow(
            icon: "sparkles",
            title: "Sidebar redesign",
            subtitle: "Jul 3 — New navigation, seamless header, icon rail collapse."
          )
          TLRow(
            icon: "keyboard",
            title: "Always-on hotkeys editable",
            subtitle: "Jul 2 — Paste and dump shortcuts can now be recorded in Shortcuts."
          )
        }
      }
    }
  }
}

#Preview("Home") {
  TLFloatingHost {
    PrototypeHomePane()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
