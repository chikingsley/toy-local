import SwiftUI

struct TLMenuOption<Value: Hashable & Sendable>: Identifiable, Sendable {
  let value: Value
  let label: String
  var systemImage: String?
  var accessoryText: String = ""
  var detailTitle: String = ""
  var detailText: String = ""

  var id: Value { value }
}

struct TLOptionMenu<Value: Hashable & Sendable>: View {
  @Binding var selection: Value
  let options: [TLMenuOption<Value>]
  var width: CGFloat = 152
  var panelWidth: CGFloat?
  var selectedTint = TLTheme.accentGreen
  var onSelect: (Value) -> Void = { _ in }

  @State private var presentationID = UUID()
  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  private var selectedOption: TLMenuOption<Value> {
    options.first { $0.value == selection } ?? options[0]
  }

  private var resolvedPanelWidth: CGFloat {
    panelWidth ?? width
  }

  var body: some View {
    Button {
      toggleMenu()
    } label: {
      TLOptionValuePill(
        text: selectedOption.label,
        systemImage: selectedOption.systemImage,
        width: width,
        selectedTint: selectedTint
      )
    }
    .buttonStyle(.plain)
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onChange(of: anchorFrame) { _, _ in
      if floatingLayer?.contains(id: presentationID) == true {
        presentMenu()
      }
    }
    .onDisappear {
      floatingLayer?.dismiss(id: presentationID)
    }
  }

  private func toggleMenu() {
    if floatingLayer?.contains(id: presentationID) == true {
      floatingLayer?.dismiss(id: presentationID)
    } else {
      floatingLayer?.dismissAll()
      presentMenu()
    }
  }

  private func presentMenu() {
    guard anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: presentationID,
      anchor: anchorFrame,
      placement: .bottomTrailing,
      spacing: 6,
      estimatedSize: CGSize(width: resolvedPanelWidth, height: estimatedPanelHeight),
      blocksBackground: true
    ) {
      TLOptionMenuPanel(
        menuID: presentationID,
        selection: $selection,
        options: options,
        width: resolvedPanelWidth,
        selectedTint: selectedTint
      ) { value in
        onSelect(value)
      }
    }
  }

  private var estimatedPanelHeight: CGFloat {
    CGFloat(options.count) * 31 + 12
  }
}

struct TLOptionValuePill: View {
  let text: String
  var systemImage: String?
  var width: CGFloat = 152
  var selectedTint = TLTheme.accentGreen

  var body: some View {
    HStack(spacing: 7) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 11))
          .foregroundStyle(selectedTint)
          .frame(width: 14)
      }
      Text(text)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .frame(width: width, height: 30, alignment: .leading)
    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct TLOptionMenuPanel<Value: Hashable & Sendable>: View {
  let menuID: UUID
  @Binding var selection: Value
  let options: [TLMenuOption<Value>]
  let width: CGFloat
  let selectedTint: Color
  let onSelect: (Value) -> Void

  @Environment(\.tlFloatingLayer) private var floatingLayer

  var body: some View {
    VStack(spacing: 1) {
      ForEach(options) { option in
        TLOptionMenuRow(
          menuID: menuID,
          option: option,
          isSelected: option.value == selection,
          selectedTint: selectedTint
        ) {
          selection = option.value
          onSelect(option.value)
          floatingLayer?.dismissAll()
        }
      }
    }
    .padding(6)
    .frame(width: width)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
    )
  }
}

private struct TLOptionMenuRow<Value: Hashable & Sendable>: View {
  let menuID: UUID
  let option: TLMenuOption<Value>
  let isSelected: Bool
  let selectedTint: Color
  let action: () -> Void

  @State private var hovering = false
  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  private var detailID: AnyHashable {
    AnyHashable("\(menuID.uuidString)-\(option.label)-detail")
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        if let systemImage = option.systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        Text(option.label)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
        Spacer()
        if !option.accessoryText.isEmpty {
          Text(option.accessoryText)
            .font(.system(size: 10, weight: .semibold))
            .italic()
            .foregroundStyle(.secondary)
        } else if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selectedTint)
        }
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(isSelected ? Color.primary.opacity(0.09) : (hovering ? Color.primary.opacity(0.07) : .clear))
      )
    }
    .buttonStyle(.plain)
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onHover { isHovering in
      hovering = isHovering
      if isHovering {
        presentDetail()
      } else {
        floatingLayer?.dismiss(id: detailID)
      }
    }
    .onChange(of: anchorFrame) { _, _ in
      if hovering {
        presentDetail()
      }
    }
    .onDisappear {
      floatingLayer?.dismiss(id: detailID)
    }
  }

  private func presentDetail() {
    guard !option.detailText.isEmpty, anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: detailID,
      anchor: anchorFrame,
      placement: .left,
      spacing: 10,
      estimatedSize: CGSize(width: 220, height: 92),
      allowsHitTesting: false
    ) {
      TLPopoverCard(width: 220) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            if let systemImage = option.systemImage {
              Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            Text(option.detailTitle.isEmpty ? option.label : option.detailTitle)
              .font(.system(size: 12, weight: .semibold))
          }
          Text(option.detailText)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}
