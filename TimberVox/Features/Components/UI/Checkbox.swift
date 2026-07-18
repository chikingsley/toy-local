// ============================================================
// Checkbox.swift — swiftcn-ui
// Depends on: Theme/
// ============================================================
import SwiftUI

// MARK: - Primitive

/// The three visual and accessibility states supported by `SCCheckbox`.
public enum SCCheckboxState: Hashable, Sendable {
  case unchecked
  case checked
  case mixed

  fileprivate var isChecked: Bool { self == .checked }
}

/// The default check or mixed-state glyph rendered by `SCCheckbox`.
public struct SCCheckboxIndicator: View {
  public let state: SCCheckboxState

  public init(state: SCCheckboxState) {
    self.state = state
  }

  public var body: some View {
    Group {
      switch state {
      case .unchecked:
        EmptyView()
      case .checked:
        Image(systemName: "checkmark")
      case .mixed:
        Image(systemName: "minus")
      }
    }
    .font(.system(size: 10, weight: .bold))
    .accessibilityHidden(true)
  }
}

/// A controlled, composable checkbox with checked, unchecked, and mixed states.
///
/// The state binding is caller-owned. Activating a mixed checkbox resolves it
/// to checked, matching the native checkbox convention. Supply `EmptyView` as
/// the label when composing the control beside `SCFieldLabel` or table content.
public struct SCCheckbox<Label: View, Indicator: View>: View {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.theme) private var theme
  @FocusState private var isFocused: Bool

  @Binding private var state: SCCheckboxState
  private let isInvalid: Bool
  private let label: Label
  private let indicator: (SCCheckboxState) -> Indicator

  public init(
    state: Binding<SCCheckboxState>,
    isInvalid: Bool = false,
    @ViewBuilder label: () -> Label,
    @ViewBuilder indicator: @escaping (SCCheckboxState) -> Indicator
  ) {
    self._state = state
    self.isInvalid = isInvalid
    self.label = label()
    self.indicator = indicator
  }

  public var body: some View {
    Button(action: toggle) {
      HStack(spacing: 8) {
        control
        label
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .opacity(isEnabled ? 1 : 0.5)
    .accessibilityRepresentation {
      Toggle(isOn: checkedBinding) {
        label
      }
      .accessibilityValue(Text(accessibilityValue))
    }
  }

  private var control: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(state == .unchecked ? theme.background : theme.primary)
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .strokeBorder(borderColor, lineWidth: 1)
      if state != .unchecked {
        indicator(state)
          .foregroundStyle(theme.primaryForeground)
      }
    }
    .frame(width: 16, height: 16)
    .overlay {
      if isFocused || isInvalid {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(focusColor.opacity(0.45), lineWidth: 3)
          .padding(-3)
      }
    }
    .animation(.easeOut(duration: 0.12), value: state)
    .accessibilityHidden(true)
  }

  private var borderColor: Color {
    if isInvalid { return theme.destructive }
    return state == .unchecked ? theme.input : theme.primary
  }

  private var focusColor: Color {
    isInvalid ? theme.destructive : theme.ring
  }

  private var checkedBinding: Binding<Bool> {
    Binding(
      get: { state.isChecked },
      set: { state = $0 ? .checked : .unchecked }
    )
  }

  private var accessibilityValue: String {
    switch state {
    case .unchecked: "Unchecked"
    case .checked: "Checked"
    case .mixed: "Mixed"
    }
  }

  private func toggle() {
    state = state == .checked ? .unchecked : .checked
  }
}

extension SCCheckbox where Indicator == SCCheckboxIndicator {
  /// Creates a checkbox using the default check and mixed-state glyphs.
  public init(
    state: Binding<SCCheckboxState>,
    isInvalid: Bool = false,
    @ViewBuilder label: () -> Label
  ) {
    self.init(state: state, isInvalid: isInvalid, label: label) {
      SCCheckboxIndicator(state: $0)
    }
  }
}

extension SCCheckbox where Label == EmptyView, Indicator == SCCheckboxIndicator {
  /// Creates an unlabeled control for composition with a field or table label.
  public init(
    state: Binding<SCCheckboxState>,
    isInvalid: Bool = false
  ) {
    self.init(state: state, isInvalid: isInvalid) { EmptyView() }
  }
}

extension SCCheckbox where Indicator == SCCheckboxIndicator {
  /// Boolean-binding convenience for callers that do not need mixed state.
  public init(
    isChecked: Binding<Bool>,
    isInvalid: Bool = false,
    @ViewBuilder label: () -> Label
  ) {
    let state = Binding<SCCheckboxState>(
      get: { isChecked.wrappedValue ? .checked : .unchecked },
      set: { isChecked.wrappedValue = $0 == .checked }
    )
    self.init(state: state, isInvalid: isInvalid, label: label)
  }
}

// MARK: - Style

/// Checkbox appearance for native SwiftUI `Toggle`s — a square check control
/// in place of the platform switch. The toggle primitive is kept underneath
/// (wrapped in a `Button`), so tap targets, keyboard access, and the on/off
/// `accessibilityValue` all stay native; this supplies the style layer only.
///
///     Toggle("Accept terms and conditions", isOn: $accepted)
///         .toggleStyle(.scCheckbox)
public struct SCCheckboxStyle: ToggleStyle {
  @Environment(\.theme) private var theme
  @Environment(\.isEnabled) private var isEnabled

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: 8) {
        box(isOn: configuration.isOn)
        configuration.label
          .font(.subheadline)
          .foregroundStyle(theme.foreground)
      }
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.5)
  }

  private func box(isOn: Bool) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(isOn ? theme.primary : theme.background)
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(theme.input, lineWidth: 1.5)
        .opacity(isOn ? 0 : 1)
      if isOn {
        Image(systemName: "checkmark")
          .font(.caption2.weight(.bold))
          .foregroundStyle(theme.primaryForeground)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(width: 20, height: 20)
    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isOn)
  }
}

extension ToggleStyle where Self == SCCheckboxStyle {
  /// `Toggle("Accept terms", isOn: $accepted).toggleStyle(.scCheckbox)`
  public static var scCheckbox: SCCheckboxStyle { SCCheckboxStyle() }
}
