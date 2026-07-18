// ============================================================
// Popover.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Configuration

public enum SCPopoverSide: CaseIterable, Hashable, Sendable {
  case top
  case bottom
  /// Logical inline-start placement.
  case leading
  /// Logical inline-end placement.
  case trailing
  /// Physical left placement regardless of layout direction.
  case left
  /// Physical right placement regardless of layout direction.
  case right
}

public enum SCPopoverAlignment: CaseIterable, Hashable, Sendable {
  case start
  case center
  case end
}

public enum SCPopoverCompactAdaptation: CaseIterable, Hashable, Sendable {
  /// Preserve an anchored popover in compact environments.
  case popover
  /// Deliberately adapt to a sheet in compact environments.
  case sheet
  /// Let SwiftUI choose its platform default.
  case automatic
}

public enum SCPopoverChangeReason: Hashable, Sendable {
  case triggerPress
  case triggerHover
  /// SwiftUI reported dismissal without exposing whether it was an outside
  /// press, system Escape handling, or another native presentation event.
  case nativeDismissal
  case escapeKey
  case closePress
  case focusOut
  case programmatic
}

/// Real side and alignment configuration for the native popover attachment.
public struct SCPopoverPosition: Hashable, Sendable {
  public var side: SCPopoverSide
  public var alignment: SCPopoverAlignment

  public init(
    side: SCPopoverSide = .bottom,
    alignment: SCPopoverAlignment = .center
  ) {
    self.side = side
    self.alignment = alignment
  }

  func arrowEdge(layoutDirection: LayoutDirection) -> Edge {
    switch side {
    case .top:
      return .bottom
    case .bottom:
      return .top
    case .leading:
      return .trailing
    case .trailing:
      return .leading
    case .left:
      return layoutDirection == .leftToRight ? .trailing : .leading
    case .right:
      return layoutDirection == .leftToRight ? .leading : .trailing
    }
  }

  func attachmentAnchor(
    layoutDirection: LayoutDirection
  ) -> PopoverAttachmentAnchor {
    .point(attachmentPoint(layoutDirection: layoutDirection))
  }

  private func attachmentPoint(layoutDirection: LayoutDirection) -> UnitPoint {
    let startX: CGFloat = layoutDirection == .leftToRight ? 0 : 1
    let endX: CGFloat = layoutDirection == .leftToRight ? 1 : 0

    switch side {
    case .top:
      return UnitPoint(x: horizontalCoordinate(start: startX, end: endX), y: 0)
    case .bottom:
      return UnitPoint(x: horizontalCoordinate(start: startX, end: endX), y: 1)
    case .leading:
      return UnitPoint(x: startX, y: verticalCoordinate)
    case .trailing:
      return UnitPoint(x: endX, y: verticalCoordinate)
    case .left:
      return UnitPoint(x: 0, y: verticalCoordinate)
    case .right:
      return UnitPoint(x: 1, y: verticalCoordinate)
    }
  }

  private func horizontalCoordinate(start: CGFloat, end: CGFloat) -> CGFloat {
    switch alignment {
    case .start: start
    case .center: 0.5
    case .end: end
    }
  }

  private var verticalCoordinate: CGFloat {
    switch alignment {
    case .start: 0
    case .center: 0.5
    case .end: 1
    }
  }

  init(arrowEdge: Edge) {
    switch arrowEdge {
    case .top:
      self.init(side: .bottom)
    case .bottom:
      self.init(side: .top)
    case .leading:
      self.init(side: .trailing)
    case .trailing:
      self.init(side: .leading)
    }
  }
}

// MARK: - Shared context

struct SCPopoverContext {
  var isPresented = false
  var setPresented: (Bool, SCPopoverChangeReason) -> Void = { _, _ in }
  var scheduleHoverOpen: (Duration, Duration) -> Void = { _, _ in }
  var scheduleHoverClose: () -> Void = {}
  var cancelHoverClose: () -> Void = {}
}

private struct SCPopoverContextKey: EnvironmentKey {
  static var defaultValue: SCPopoverContext { SCPopoverContext() }
}

private struct SCPopoverDismissActionKey: EnvironmentKey {
  static var defaultValue: () -> Void { {} }
}

extension EnvironmentValues {
  var scPopoverContext: SCPopoverContext {
    get { self[SCPopoverContextKey.self] }
    set { self[SCPopoverContextKey.self] = newValue }
  }

  /// Dismisses the nearest enclosing `SCPopover`.
  public var scDismissPopover: () -> Void {
    get { self[SCPopoverDismissActionKey.self] }
    set { self[SCPopoverDismissActionKey.self] = newValue }
  }
}

// MARK: - Root

/// A controlled or internally managed native popover with independent Trigger
/// and Content slots.
///
/// SwiftUI owns the real portal, anchoring, arrow, collision avoidance,
/// outside dismissal, window/dialog stacking, focus movement, and accessibility
/// presentation. The component owns state, trigger interaction, optional hover
/// timing, semantic content parts, and theme chrome.
public struct SCPopover<Trigger: View, PopoverContent: View>: View {
  private let externalIsPresented: Binding<Bool>?
  private let defaultPresented: Bool
  private let position: SCPopoverPosition
  private let compactAdaptation: SCPopoverCompactAdaptation
  private let isDisabled: Bool
  private let onPresentedChange: ((Bool, SCPopoverChangeReason) -> Void)?
  private let trigger: Trigger
  private let popoverContent: PopoverContent

  public init(
    isPresented: Binding<Bool>,
    position: SCPopoverPosition = SCPopoverPosition(),
    compactAdaptation: SCPopoverCompactAdaptation = .popover,
    isDisabled: Bool = false,
    onPresentedChange: ((Bool, SCPopoverChangeReason) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> PopoverContent
  ) {
    self.externalIsPresented = isPresented
    self.defaultPresented = isPresented.wrappedValue
    self.position = position
    self.compactAdaptation = compactAdaptation
    self.isDisabled = isDisabled
    self.onPresentedChange = onPresentedChange
    self.trigger = trigger()
    self.popoverContent = content()
  }

  public init(
    defaultPresented: Bool = false,
    position: SCPopoverPosition = SCPopoverPosition(),
    compactAdaptation: SCPopoverCompactAdaptation = .popover,
    isDisabled: Bool = false,
    onPresentedChange: ((Bool, SCPopoverChangeReason) -> Void)? = nil,
    @ViewBuilder trigger: () -> Trigger,
    @ViewBuilder content: () -> PopoverContent
  ) {
    self.externalIsPresented = nil
    self.defaultPresented = defaultPresented
    self.position = position
    self.compactAdaptation = compactAdaptation
    self.isDisabled = isDisabled
    self.onPresentedChange = onPresentedChange
    self.trigger = trigger()
    self.popoverContent = content()
  }

  public var body: some View {
    SCPopoverStateContainer(
      externalIsPresented: externalIsPresented,
      defaultPresented: defaultPresented,
      position: position,
      compactAdaptation: compactAdaptation,
      isDisabled: isDisabled,
      onPresentedChange: onPresentedChange,
      trigger: trigger,
      popoverContent: popoverContent
    )
  }
}

private struct SCPopoverStateContainer<Trigger: View, PopoverContent: View>: View {
  @State private var internalIsPresented: Bool
  @State private var hoverOwnsPresentation = false
  @State private var hoverCloseDelay: Duration = .zero
  @State private var openTask: Task<Void, Never>?
  @State private var closeTask: Task<Void, Never>?

  let externalIsPresented: Binding<Bool>?
  let position: SCPopoverPosition
  let compactAdaptation: SCPopoverCompactAdaptation
  let isDisabled: Bool
  let onPresentedChange: ((Bool, SCPopoverChangeReason) -> Void)?
  let trigger: Trigger
  let popoverContent: PopoverContent

  init(
    externalIsPresented: Binding<Bool>?,
    defaultPresented: Bool,
    position: SCPopoverPosition,
    compactAdaptation: SCPopoverCompactAdaptation,
    isDisabled: Bool,
    onPresentedChange: ((Bool, SCPopoverChangeReason) -> Void)?,
    trigger: Trigger,
    popoverContent: PopoverContent
  ) {
    self.externalIsPresented = externalIsPresented
    self.position = position
    self.compactAdaptation = compactAdaptation
    self.isDisabled = isDisabled
    self.onPresentedChange = onPresentedChange
    self.trigger = trigger
    self.popoverContent = popoverContent
    self._internalIsPresented = State(initialValue: defaultPresented)
  }

  var body: some View {
    trigger
      .environment(\.scPopoverContext, context)
      .disabled(isDisabled)
      .modifier(
        SCPopoverPresentationHost(
          isPresented: presentation,
          position: position,
          compactAdaptation: compactAdaptation,
          popoverContent: popoverBody
        )
      )
      .onDisappear {
        openTask?.cancel()
        closeTask?.cancel()
      }
  }

  private var isPresented: Bool {
    externalIsPresented?.wrappedValue ?? internalIsPresented
  }

  private var presentation: Binding<Bool> {
    Binding(
      get: { isPresented },
      set: { nextValue in
        guard !nextValue else { return }
        setPresented(false, reason: .nativeDismissal)
      }
    )
  }

  private var context: SCPopoverContext {
    SCPopoverContext(
      isPresented: isPresented,
      setPresented: setPresented,
      scheduleHoverOpen: scheduleHoverOpen,
      scheduleHoverClose: scheduleHoverClose,
      cancelHoverClose: cancelHoverClose
    )
  }

  private var popoverBody: some View {
    popoverContent
      .environment(\.scPopoverContext, context)
      .environment(\.scDismissPopover) {
        setPresented(false, reason: .programmatic)
      }
  }

  private func setPresented(_ nextValue: Bool, reason: SCPopoverChangeReason) {
    openTask?.cancel()
    closeTask?.cancel()
    guard isPresented != nextValue else { return }

    hoverOwnsPresentation = reason == .triggerHover && nextValue
    if let externalIsPresented {
      externalIsPresented.wrappedValue = nextValue
    } else {
      internalIsPresented = nextValue
    }
    onPresentedChange?(nextValue, reason)
  }

  private func scheduleHoverOpen(openDelay: Duration, closeDelay: Duration) {
    closeTask?.cancel()
    openTask?.cancel()
    hoverCloseDelay = closeDelay
    openTask = Task { @MainActor in
      do {
        try await Task.sleep(for: openDelay)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      setPresented(true, reason: .triggerHover)
    }
  }

  private func scheduleHoverClose() {
    openTask?.cancel()
    guard hoverOwnsPresentation else { return }
    closeTask?.cancel()
    closeTask = Task { @MainActor in
      do {
        try await Task.sleep(for: hoverCloseDelay)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      setPresented(false, reason: .focusOut)
    }
  }

  private func cancelHoverClose() {
    closeTask?.cancel()
  }
}
