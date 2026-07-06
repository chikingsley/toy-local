import SwiftUI

enum TLHeaderControl {
  case sidebarToggle
  case back(() -> Void)
  case none
}

private struct PrototypeToggleSidebarKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
  var tlToggleSidebar: @MainActor @Sendable () -> Void {
    get { self[PrototypeToggleSidebarKey.self] }
    set { self[PrototypeToggleSidebarKey.self] = newValue }
  }
}

struct TLHeader<Leading: View, Trailing: View>: View {
  var control: TLHeaderControl = .sidebarToggle
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing
  @Environment(\.tlToggleSidebar) private var toggleSidebar

  var body: some View {
    HStack(spacing: 10) {
      controlView
      leading
      Spacer(minLength: 8)
      trailing
    }
    .padding(.leading, 10)
    .padding(.trailing, 14)
    .frame(height: TLTheme.headerHeight)
    .overlay(alignment: .bottom) {
      Rectangle().fill(TLTheme.hairline).frame(height: 1)
    }
  }

  @ViewBuilder private var controlView: some View {
    switch control {
    case .sidebarToggle:
      Button(action: toggleSidebar) {
        Image(systemName: "sidebar.leading")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case .back(let action):
      Button(action: action) {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case .none:
      EmptyView()
    }
  }
}
