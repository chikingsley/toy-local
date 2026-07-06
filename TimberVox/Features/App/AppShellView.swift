import TimberVoxCore
import SwiftUI

extension AppearancePreference {
  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
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

struct AppShellView: View {
  @Bindable var store: AppStore
  @State private var sidebarMode: SidebarMode = .full
  @State private var pendingHistoryItemID: String?
  @State private var pendingCreateMode = false

  var body: some View {
    TLFloatingHost {
      HStack(spacing: 0) {
        AppSidebar(selectedTab: $store.activeTab, mode: sidebarMode)
          .frame(width: sidebarMode.width)
          .overlay(alignment: .trailing) {
            Rectangle().fill(TLTheme.hairline).frame(width: 1)
          }

        detail
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .background(TLTheme.windowBackground)
      }
    }
    .ignoresSafeArea(.container, edges: .top)
    .preferredColorScheme(store.settings.timberVoxSettings.appearancePreference.colorScheme)
    .animation(.easeInOut(duration: 0.18), value: sidebarMode)
    .background(AppWindowConfigurator(sidebarMode: sidebarMode))
    .environment(\.tlToggleSidebar) {
      withAnimation(.easeInOut(duration: 0.18)) {
        sidebarMode.toggle()
      }
    }
    .environment(\.tlNavigate) { destination in
      switch destination {
      case .tab(let tab):
        store.activeTab = tab
      case .historyItem(let id):
        pendingHistoryItemID = id
        store.activeTab = .history
      case .createMode:
        pendingCreateMode = true
        store.activeTab = .modes
      }
    }
  }

  @ViewBuilder private var detail: some View {
    switch store.activeTab {
    case .home: HomePane(historyStore: store.history, settingsStore: store.settings)
    case .modes: ModesPane(store: store.settings, createModeRequest: $pendingCreateMode)
    case .dictionary: PrototypeDictionaryPaneV2()
    case .history: HistoryPane(store: store.history, deepLinkItemID: $pendingHistoryItemID)
    case .configuration:
      ConfigurationPane(
        store: store.settings,
        microphonePermission: store.microphonePermission,
        accessibilityPermission: store.accessibilityPermission,
        screenCapturePermission: store.screenCapturePermission
      )
    case .hotMic: HotMicPane(store: store.settings)
    case .sound: SoundPane(store: store.settings)
    case .models: ModelLibraryPane(store: store.settings)
    case .license: LicensePane()
    }
  }
}

struct AppSidebar: View {
  @Binding var selectedTab: ActiveTab
  let mode: SidebarMode

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Color.clear.frame(height: 44)

      item(.home)

      groupGap

      ForEach(ActiveTab.libraryTop) { tab in
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

      ForEach(ActiveTab.settings) { tab in
        item(tab)
      }

      groupGap

      item(.history)

      Spacer()

      if mode == .full {
        AppSidebarLicenseCard(isSelected: selectedTab == .license) {
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

  private func item(_ tab: ActiveTab) -> some View {
    AppSidebarItem(tab: tab, isSelected: selectedTab == tab, mode: mode) { selectedTab = tab }
  }

  private var groupGap: some View {
    Color.clear.frame(height: 10)
  }
}

private struct AppSidebarItem: View {
  let tab: ActiveTab
  let isSelected: Bool
  let mode: SidebarMode
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        TLIconTile(
          systemName: tab.icon,
          style: .colored(tab.iconColor),
          size: 22,
          isSelected: isSelected
        )
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
}

private struct AppSidebarLicenseCard: View {
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
          Text(AppBrand.proName)
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
          .fill(isSelected ? TLTheme.selectionFill : (hovering ? TLTheme.hoverFill : TLTheme.cardSurface))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(TLTheme.borderStroke, lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct AppWindowConfigurator: NSViewRepresentable {
  let sidebarMode: SidebarMode

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      configure(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    configure(nsView.window)
  }

  private func configure(_ window: NSWindow?) {
    guard let window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = sidebarMode == .rail
  }
}
