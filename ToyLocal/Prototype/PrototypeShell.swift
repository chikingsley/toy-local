import SwiftUI

struct PrototypeWindow: View {
  var body: some View {
    PrototypeShell()
      .frame(width: 820, height: 680)
      .background(TLTheme.windowBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(.white.opacity(0.12), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.4), radius: 28, y: 12)
      .padding(40)
      .background(Color(white: 0.06))
  }
}

enum PrototypeTab: String, CaseIterable, Identifiable {
  case home, modes, dictionary, dictionaryV2, history
  case configuration, hotMic, sound, models, license

  var id: String { rawValue }

  var label: String {
    switch self {
    case .home: "Home"
    case .modes: "Modes"
    case .dictionary: "Dictionary"
    case .dictionaryV2: "Dictionary V2"
    case .history: "History"
    case .configuration: "Configuration"
    case .hotMic: "Hot Mic"
    case .sound: "Sound"
    case .models: "Model library"
    case .license: "License"
    }
  }

  var icon: String {
    switch self {
    case .home: "house"
    case .modes: "mic.fill"
    case .dictionary: "character.book.closed"
    case .dictionaryV2: "character.book.closed.fill"
    case .history: "fossil.shell.fill"
    case .configuration: "slider.horizontal.3"
    case .hotMic: "waveform.circle"
    case .sound: "speaker.wave.2.fill"
    case .models: "square.stack.3d.up"
    case .license: "key.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .home: Color(hex: Shadcn.orange500)
    case .modes: Color(hex: Shadcn.blue500)
    case .dictionary: Color(hex: Shadcn.blue600)
    case .dictionaryV2: Color(hex: Shadcn.blue600)
    case .history: Color(hex: Shadcn.violet500)
    case .configuration: Color(hex: Shadcn.neutral500)
    case .hotMic: Color(hex: Shadcn.green500)
    case .sound: Color(hex: Shadcn.neutral500)
    case .models: Color(hex: Shadcn.neutral600)
    case .license: TLTheme.accentGreen
    }
  }

  static let libraryTop: [PrototypeTab] = [.modes, .dictionary, .dictionaryV2]
  static let settings: [PrototypeTab] = [.configuration, .sound, .hotMic, .models]

  var supportsSearch: Bool {
    switch self {
    case .history, .models, .dictionary, .dictionaryV2: true
    default: false
    }
  }
}

enum TLDestination: Equatable {
  case tab(PrototypeTab)
  case historyItem(String)
  case createMode
}

private struct PrototypeNavigateKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable (TLDestination) -> Void = { _ in }
}

extension EnvironmentValues {
  var tlNavigate: @MainActor @Sendable (TLDestination) -> Void {
    get { self[PrototypeNavigateKey.self] }
    set { self[PrototypeNavigateKey.self] = newValue }
  }
}

enum SidebarMode {
  case full, rail

  mutating func toggle() {
    self = self == .full ? .rail : .full
  }

  var width: CGFloat {
    self == .full ? TLTheme.sidebarWidth : TLTheme.railWidth
  }
}

struct PrototypeShell: View {
  @State private var selectedTab: PrototypeTab = .home
  @State private var sidebarMode: SidebarMode = .full
  @State private var pendingHistoryItemID: String?
  @State private var pendingCreateMode = false
  @State private var appearance: ColorScheme?

  var body: some View {
    TLFloatingHost {
      HStack(spacing: 0) {
        PrototypeSidebar(selectedTab: $selectedTab, mode: sidebarMode)
          .frame(width: sidebarMode.width)
          .overlay(alignment: .trailing) {
            Rectangle().fill(TLTheme.hairline).frame(width: 1)
          }

        detail
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .background(TLTheme.windowBackground)
      }
    }
    .preferredColorScheme(appearance)
    .animation(.easeInOut(duration: 0.18), value: sidebarMode)
    .environment(\.tlToggleSidebar) {
      withAnimation(.easeInOut(duration: 0.18)) {
        sidebarMode.toggle()
      }
    }
    .environment(\.tlNavigate) { destination in
      switch destination {
      case .tab(let tab):
        selectedTab = tab
      case .historyItem(let id):
        pendingHistoryItemID = id
        selectedTab = .history
      case .createMode:
        pendingCreateMode = true
        selectedTab = .modes
      }
    }
  }

  @ViewBuilder private var detail: some View {
    switch selectedTab {
    case .home: PrototypeHomePane()
    case .modes: PrototypeModesPane(createModeRequest: $pendingCreateMode)
    case .dictionary: PrototypeDictionaryPane()
    case .dictionaryV2: PrototypeDictionaryPaneV2()
    case .history: PrototypeHistoryPane(deepLinkItemID: $pendingHistoryItemID)
    case .configuration: PrototypeConfigurationPane(appearance: $appearance)
    case .hotMic: PrototypeHotMicPane()
    case .sound: PrototypeSoundPane()
    case .models: PrototypeModelsPane()
    case .license: PrototypeLicensePane()
    }
  }
}

struct PrototypeSidebar: View {
  @Binding var selectedTab: PrototypeTab
  let mode: SidebarMode

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        PrototypeTrafficLights(showMinimize: mode == .full)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: 44)

      item(.home)

      groupGap

      ForEach(PrototypeTab.libraryTop) { tab in
        item(tab)
      }

      if mode == .full {
        Text("Settings")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.tertiary)
          .padding(.horizontal, 12)
          .padding(.top, 14)
          .padding(.bottom, 4)
      } else {
        groupGap
      }

      ForEach(PrototypeTab.settings) { tab in
        item(tab)
      }

      groupGap

      item(.history)

      Spacer()

      if mode == .full {
        PrototypeSidebarLicenseCard(isSelected: selectedTab == .license) {
          selectedTab = .license
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
      } else {
        Button {
          selectedTab = .license
        } label: {
          TLIconTile(
            systemName: "key.fill",
            style: .colored(TLTheme.accentGreen),
            size: 22,
            isSelected: selectedTab == .license
          )
          .frame(width: 36, height: 36)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
        .help("License")
      }
    }
    .padding(.horizontal, 6)
    .frame(maxHeight: .infinity)
    .background(TLTheme.windowBackground)
  }

  private func item(_ tab: PrototypeTab) -> some View {
    SidebarItem(tab: tab, isSelected: selectedTab == tab, mode: mode) { selectedTab = tab }
  }

  private var groupGap: some View {
    Color.clear.frame(height: 10)
  }
}

private struct PrototypeTrafficLights: View {
  let showMinimize: Bool
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 8) {
      light(color: Color(hex: 0xFF5F57), glyph: "xmark")
      if showMinimize {
        light(color: Color(hex: 0xFEBC2E), glyph: "minus")
      }
    }
    .padding(.leading, 16)
    .onHover { hovering = $0 }
  }

  private func light(color: Color, glyph: String) -> some View {
    ZStack {
      Circle().fill(color).frame(width: 12, height: 12)
      if hovering {
        Image(systemName: glyph)
          .font(.system(size: 6.5, weight: .black))
          .foregroundStyle(.black.opacity(0.55))
      }
    }
    .contentShape(Circle())
  }
}

private struct PrototypeSidebarLicenseCard: View {
  let isSelected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 6) {
          Image(systemName: "key.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 18, height: 18)
            .background(TLTheme.accentGreen, in: RoundedRectangle(cornerRadius: 5))
          Text("ToyLocal Pro")
            .font(.system(size: 12, weight: .semibold))
          Spacer()
          Text("Trial")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: 4))
        }

        Text("Your Pro trial has ended.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Capsule()
          .fill(TLTheme.accentGreen)
          .frame(height: 5)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.primary.opacity(0.13) : (hovering ? Color.primary.opacity(0.09) : Color.primary.opacity(0.06)))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct SidebarItem: View {
  let tab: PrototypeTab
  let isSelected: Bool
  let mode: SidebarMode
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        sidebarIcon
        if mode == .full {
          Text(tab.label)
            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
          Spacer(minLength: 0)
        }
      }
      .padding(.horizontal, mode == .full ? 8 : 0)
      .frame(maxWidth: .infinity, alignment: mode == .full ? .leading : .center)
      .frame(height: mode == .full ? 32 : 36)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? TLTheme.selectionFill : (hovering ? TLTheme.hoverFill : .clear))
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .help(mode == .rail ? tab.label : "")
  }

  @ViewBuilder private var sidebarIcon: some View {
    TLIconTile(
      systemName: tab.icon,
      style: .colored(tab.iconColor),
      size: 22,
      isSelected: isSelected
    )
  }
}

#Preview("Prototype window") {
  PrototypeWindow()
}
