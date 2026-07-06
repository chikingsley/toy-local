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

enum TLOptionMenuMetrics {
  static let pillWidth: CGFloat = 152
  static let pillHeight: CGFloat = 30
  static let rowHeight: CGFloat = 30
  static let rowSpacing: CGFloat = 1
  static let panelPadding: CGFloat = 6
  static let maxVisibleRows = 6

  static func listHeight(forVisibleRows rows: Int) -> CGFloat {
    CGFloat(rows) * rowHeight + CGFloat(max(0, rows - 1)) * rowSpacing
  }

  static func panelHeight(forRowCount count: Int, showsAllRows: Bool) -> CGFloat {
    let visible = showsAllRows ? count : min(count, maxVisibleRows)
    return listHeight(forVisibleRows: visible) + panelPadding * 2
  }
}

struct TLOptionMenu<Value: Hashable & Sendable>: View {
  @Binding var selection: Value
  let options: [TLMenuOption<Value>]
  var width: CGFloat = TLOptionMenuMetrics.pillWidth
  var panelWidth: CGFloat?
  var showsAllRows = false
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
        showsAllRows: showsAllRows,
        selectedTint: selectedTint
      ) { value in
        onSelect(value)
      }
    }
  }

  private var estimatedPanelHeight: CGFloat {
    TLOptionMenuMetrics.panelHeight(forRowCount: options.count, showsAllRows: showsAllRows)
  }
}

struct TLOptionValuePill: View {
  let text: String
  var systemImage: String?
  var width: CGFloat = TLOptionMenuMetrics.pillWidth
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
    .frame(width: width, height: TLOptionMenuMetrics.pillHeight, alignment: .leading)
    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct TLOptionMenuPanel<Value: Hashable & Sendable>: View {
  let menuID: UUID
  @Binding var selection: Value
  let options: [TLMenuOption<Value>]
  let width: CGFloat
  let showsAllRows: Bool
  let selectedTint: Color
  let onSelect: (Value) -> Void

  @Environment(\.tlFloatingLayer) private var floatingLayer

  private var needsScroll: Bool {
    !showsAllRows && options.count > TLOptionMenuMetrics.maxVisibleRows
  }

  var body: some View {
    Group {
      if needsScroll {
        ScrollView {
          rowList
        }
        .frame(height: TLOptionMenuMetrics.listHeight(forVisibleRows: TLOptionMenuMetrics.maxVisibleRows))
      } else {
        rowList
      }
    }
    .padding(TLOptionMenuMetrics.panelPadding)
    .frame(width: width)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
    )
  }

  private var rowList: some View {
    VStack(spacing: TLOptionMenuMetrics.rowSpacing) {
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
  }
}

#Preview("Long list caps at six rows") {
  TLOptionMenuPanel(
    menuID: UUID(),
    selection: .constant("English"),
    options: [
      "Automatic", "English", "Spanish", "French", "German", "Italian", "Portuguese", "Dutch",
      "Japanese", "Korean", "Mandarin", "Cantonese", "Arabic", "Hindi", "Turkish", "Polish",
    ].map { TLMenuOption(value: $0, label: $0) },
    width: TLOptionMenuMetrics.pillWidth,
    showsAllRows: false,
    selectedTint: TLTheme.accentGreen
  ) { _ in }
  .padding(24)
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
      .frame(height: TLOptionMenuMetrics.rowHeight)
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
