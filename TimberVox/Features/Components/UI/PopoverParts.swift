// ============================================================
// PopoverParts.swift — swiftcn-ui
// Depends on: Popover.swift · Theme/
// ============================================================
import SwiftUI

// MARK: - Trigger

/// A real native button that toggles its enclosing popover.
public struct SCPopoverTrigger<Label: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.scPopoverContext) private var context

  private let isDisabled: Bool
  private let opensOnHover: Bool
  private let openDelay: Duration
  private let closeDelay: Duration
  private let label: Label

  public init(
    isDisabled: Bool = false,
    opensOnHover: Bool = false,
    openDelay: Duration = .milliseconds(300),
    closeDelay: Duration = .zero,
    @ViewBuilder label: () -> Label
  ) {
    self.isDisabled = isDisabled
    self.opensOnHover = opensOnHover
    self.openDelay = openDelay
    self.closeDelay = closeDelay
    self.label = label()
  }

  public var body: some View {
    Button {
      context.setPresented(!context.isPresented, .triggerPress)
    } label: {
      label
    }
    .disabled(isDisabled)
    .onHover { isHovered in
      guard opensOnHover, isEnabled, !isDisabled else { return }
      if isHovered {
        context.scheduleHoverOpen(openDelay, closeDelay)
      } else {
        context.scheduleHoverClose()
      }
    }
    .accessibilityValue(context.isPresented ? "Expanded" : "Collapsed")
  }
}

extension SCPopoverTrigger where Label == Text {
  public init(
    _ title: String,
    isDisabled: Bool = false,
    opensOnHover: Bool = false,
    openDelay: Duration = .milliseconds(300),
    closeDelay: Duration = .zero
  ) {
    self.init(
      isDisabled: isDisabled,
      opensOnHover: opensOnHover,
      openDelay: openDelay,
      closeDelay: closeDelay
    ) {
      Text(title)
    }
  }
}

// MARK: - Content parts

/// The themed popup surface for arbitrary rich content, including forms.
public struct SCPopoverContent<Content: View>: View {
  @Environment(\.scPopoverContext) private var context
  @Environment(\.theme) private var theme

  private let padding: CGFloat
  private let width: CGFloat?
  private let minimumWidth: CGFloat?
  private let maximumWidth: CGFloat?
  private let content: Content

  public init(
    padding: CGFloat = 16,
    width: CGFloat? = 288,
    minimumWidth: CGFloat? = nil,
    maximumWidth: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = max(padding, 0)
    self.width = width.map { max($0, 0) }
    self.minimumWidth = minimumWidth.map { max($0, 0) }
    self.maximumWidth = maximumWidth.map { max($0, 0) }
    self.content = content()
  }

  public var body: some View {
    content
      .padding(padding)
      .frame(
        minWidth: minimumWidth,
        idealWidth: width,
        maxWidth: maximumWidth,
        alignment: .leading
      )
      .frame(width: fixedWidth, alignment: .leading)
      .foregroundStyle(theme.popoverForeground)
      .presentationBackground(theme.popover)
      .onHover { isHovered in
        if isHovered {
          context.cancelHoverClose()
        } else {
          context.scheduleHoverClose()
        }
      }
      .onKeyPress(.escape) {
        context.setPresented(false, .escapeKey)
        return .handled
      }
      .accessibilityElement(children: .contain)
  }

  private var fixedWidth: CGFloat? {
    guard minimumWidth == nil, maximumWidth == nil else { return nil }
    return width
  }
}

/// A compact vertical heading group for title and description parts.
public struct SCPopoverHeader<Content: View>: View {
  private let spacing: CGFloat
  private let content: Content

  public init(spacing: CGFloat = 4, @ViewBuilder content: () -> Content) {
    self.spacing = max(spacing, 0)
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: spacing) { content }
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The semantic heading that labels popover content.
public struct SCPopoverTitle<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.subheadline.weight(.medium))
      .accessibilityAddTraits(.isHeader)
  }
}

extension SCPopoverTitle where Content == Text {
  public init(_ title: String) {
    self.init { Text(title) }
  }
}

/// Supporting text associated with the nearest popover title.
public struct SCPopoverDescription<Content: View>: View {
  @Environment(\.theme) private var theme

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .font(.footnote)
      .foregroundStyle(theme.mutedForeground)
  }
}

extension SCPopoverDescription where Content == Text {
  public init(_ description: String) {
    self.init { Text(description) }
  }
}

/// A real native button that dismisses the nearest popover before invoking the
/// caller's optional action.
public struct SCPopoverClose<Label: View>: View {
  @Environment(\.scPopoverContext) private var context

  private let isDisabled: Bool
  private let action: (() -> Void)?
  private let label: Label

  public init(
    isDisabled: Bool = false,
    action: (() -> Void)? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.isDisabled = isDisabled
    self.action = action
    self.label = label()
  }

  public var body: some View {
    Button {
      context.setPresented(false, .closePress)
      action?()
    } label: {
      label
    }
    .disabled(isDisabled)
  }
}

extension SCPopoverClose where Label == Text {
  public init(
    _ title: String,
    isDisabled: Bool = false,
    action: (() -> Void)? = nil
  ) {
    self.init(isDisabled: isDisabled, action: action) {
      Text(title)
    }
  }
}

// MARK: - Presentation convenience

extension View {
  /// Presents caller-controlled content through the same native presentation
  /// host as `SCPopover`. The view remains its own real trigger; this modifier
  /// does not wrap an existing Button inside another Button.
  public func scPopover<PopoverContent: View>(
    isPresented: Binding<Bool>,
    arrowEdge: Edge = .top,
    compactAdaptation: SCPopoverCompactAdaptation = .popover,
    @ViewBuilder content: @escaping () -> PopoverContent
  ) -> some View {
    modifier(
      SCPopoverPresentationHost(
        isPresented: isPresented,
        position: SCPopoverPosition(arrowEdge: arrowEdge),
        compactAdaptation: compactAdaptation,
        popoverContent: SCPopoverContent { content() }
      )
    )
  }

  /// Position-aware form of `.scPopover` for logical and physical side
  /// placement plus start, center, or end attachment.
  public func scPopover<PopoverContent: View>(
    isPresented: Binding<Bool>,
    position: SCPopoverPosition,
    compactAdaptation: SCPopoverCompactAdaptation = .popover,
    @ViewBuilder content: @escaping () -> PopoverContent
  ) -> some View {
    modifier(
      SCPopoverPresentationHost(
        isPresented: isPresented,
        position: position,
        compactAdaptation: compactAdaptation,
        popoverContent: SCPopoverContent { content() }
      )
    )
  }
}
