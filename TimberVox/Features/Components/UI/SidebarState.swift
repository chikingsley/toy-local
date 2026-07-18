// ============================================================
// SidebarState.swift — swiftcn-ui
// Supplemental source for: sidebar
// ============================================================
import Observation
import SwiftUI

// MARK: - Variants

/// How the sidebar collapses — shadcn's `collapsible` prop.
public enum SCSidebarCollapsible: Hashable, Sendable {
  /// Slides fully offscreen when collapsed.
  case offcanvas
  /// Collapses to a 56pt icon rail.
  case icon
  /// Never collapses.
  case none
}

/// Which edge of the layout the sidebar occupies.
public enum SCSidebarSide: Hashable, Sendable {
  case leading, trailing
}

/// Visual relationship between the sidebar and its detail content.
public enum SCSidebarVariant: Hashable, Sendable {
  /// A full-height panel separated from the detail by a hairline.
  case sidebar
  /// A rounded panel floating inside the window edge.
  case floating
  /// A rounded detail surface inset into the sidebar background.
  case inset
}

// MARK: - Metrics

enum SCSidebarMetrics {
  static let expandedWidth: CGFloat = 272
  static let railWidth: CGFloat = 56
  static let animation: Animation = .snappy(duration: 0.25)
  static let storageKey = "sc.sidebar.open"
}

// MARK: - State

/// Shared sidebar state — the SwiftUI analog of shadcn's `SidebarProvider`
/// + `useSidebar` hook. `SCSidebarLayout` owns one and injects it into the
/// environment; read it anywhere in the hierarchy via
/// `@Environment(\.scSidebar)`.
///
/// Sidebar state is UI graph state. Main-actor isolation makes that ownership
/// explicit instead of claiming the mutable reference is safe on every actor.
@MainActor
@Observable
public final class SCSidebarState {
  /// Whether the sidebar is expanded (drives regular-width layouts).
  public var isOpen: Bool
  /// Whether the sidebar sheet is presented (drives compact-width layouts).
  public var openMobile: Bool
  /// The collapse behavior of the owning layout.
  public var collapsible: SCSidebarCollapsible
  /// Whether the owning layout is currently using its compact side Sheet.
  public internal(set) var isCompact: Bool
  /// The physical layout edge used by the owning Sidebar.
  public internal(set) var side: SCSidebarSide

  /// True when the sidebar is currently the 56pt icon rail
  /// (`collapsible == .icon` and closed).
  public var isIconCollapsed: Bool { collapsible == .icon && !isOpen }

  public init(
    isOpen: Bool = true,
    openMobile: Bool = false,
    collapsible: SCSidebarCollapsible = .offcanvas,
    isCompact: Bool = false,
    side: SCSidebarSide = .leading
  ) {
    self.isOpen = isOpen
    self.openMobile = openMobile
    self.collapsible = collapsible
    self.isCompact = isCompact
    self.side = side
  }

  /// Toggles the active presentation: the side Sheet on compact widths or
  /// the expanded/collapsed pane on regular widths.
  public func toggle() {
    if isCompact {
      openMobile.toggle()
    } else {
      isOpen.toggle()
    }
  }

  /// Sets the expanded state. This makes caller-owned state read naturally
  /// from menu commands and app-level navigation coordinators.
  public func setOpen(_ isOpen: Bool) {
    self.isOpen = isOpen
  }

  /// Sets the compact-width side Sheet presentation directly.
  public func setOpenMobile(_ isOpen: Bool) {
    openMobile = isOpen
  }
}

// MARK: - Environment

private struct SCSidebarStateKey: @preconcurrency EnvironmentKey {
  @MainActor static let defaultValue = SCSidebarState()
}

private struct SCSidebarIconRailKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// The enclosing sidebar's state — swiftcn's `useSidebar`. Read it to
  /// toggle or inspect the sidebar from anywhere inside `SCSidebarLayout`.
  @MainActor
  public internal(set) var scSidebar: SCSidebarState {
    get { self[SCSidebarStateKey.self] }
    set { self[SCSidebarStateKey.self] = newValue }
  }

  /// Whether the enclosing sidebar pane is currently rendering as the
  /// icon rail. Set by `SCSidebarLayout`; pieces (including your own
  /// header/footer content) read it to adapt.
  /// (Always false inside the compact-width sheet.)
  public internal(set) var scSidebarIconRail: Bool {
    get { self[SCSidebarIconRailKey.self] }
    set { self[SCSidebarIconRailKey.self] = newValue }
  }
}
