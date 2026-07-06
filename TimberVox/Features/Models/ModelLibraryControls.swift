import SwiftUI

struct ModelFilterChip: View {
  let title: String
  let clear: () -> Void

  private enum Metrics {
    static let spacing: CGFloat = 6
    static let fontSize: CGFloat = 11
    static let iconSize: CGFloat = 9
    static let horizontalPadding: CGFloat = 10
    static let height: CGFloat = 28
  }

  var body: some View {
    Button(action: clear) {
      HStack(spacing: Metrics.spacing) {
        Text(title)
          .font(.system(size: Metrics.fontSize, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "xmark")
          .font(.system(size: Metrics.iconSize, weight: .bold))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, Metrics.horizontalPadding)
      .frame(height: Metrics.height)
      .background(TLTheme.chipSurface, in: Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

struct ModelLibraryFilterMenu: View {
  @Binding var selection: ModelLibraryFilter?

  @State private var presentationID = UUID()
  @State private var anchorFrame: CGRect = .zero
  @State private var hovering = false
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  private enum Metrics {
    static let iconSize: CGFloat = 13
    static let controlSize: CGFloat = 28
    static let selectedOpacity = 0.16
    static let hoverOpacity = 0.08
    static let menuSpacing: CGFloat = 6
    static let menuWidth: CGFloat = 178
    static let menuHeight: CGFloat = 172
  }

  var body: some View {
    Button {
      toggleMenu()
    } label: {
      Image(systemName: "line.3.horizontal.decrease")
        .font(.system(size: Metrics.iconSize, weight: .semibold))
        .foregroundStyle(selection == nil ? .secondary : TLTheme.accentBlue)
        .frame(width: Metrics.controlSize, height: Metrics.controlSize)
        .background(
          selection == nil
            ? Color.primary.opacity(hovering ? Metrics.hoverOpacity : 0)
            : TLTheme.accentBlue.opacity(Metrics.selectedOpacity),
          in: Circle()
        )
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .help("Filter models")
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onHover { hovering = $0 }
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
      spacing: Metrics.menuSpacing,
      estimatedSize: CGSize(width: Metrics.menuWidth, height: Metrics.menuHeight),
      blocksBackground: true
    ) {
      ModelLibraryFilterPanel(selection: $selection)
    }
  }
}

private struct ModelLibraryFilterPanel: View {
  @Binding var selection: ModelLibraryFilter?

  private enum Metrics {
    static let spacing: CGFloat = 1
    static let padding: CGFloat = 6
    static let width: CGFloat = 178
    static let cornerRadius: CGFloat = 9
    static let borderWidth: CGFloat = 1
    static let borderOpacity = 0.14
  }

  var body: some View {
    VStack(spacing: Metrics.spacing) {
      ForEach(ModelLibraryFilter.allCases, id: \.self) { filter in
        ModelLibraryFilterRow(
          title: filter.label,
          isSelected: selection == filter
        ) {
          selection = selection == filter ? nil : filter
        }
      }
    }
    .padding(Metrics.padding)
    .frame(width: Metrics.width)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
    .overlay(
      RoundedRectangle(cornerRadius: Metrics.cornerRadius)
        .strokeBorder(.primary.opacity(Metrics.borderOpacity), lineWidth: Metrics.borderWidth)
    )
  }
}

private struct ModelLibraryFilterRow: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  @State private var hovering = false

  private enum Metrics {
    static let spacing: CGFloat = 9
    static let indicatorSize: CGFloat = 16
    static let indicatorLineWidth: CGFloat = 1
    static let checkSize: CGFloat = 9
    static let fontSize: CGFloat = 12
    static let horizontalPadding: CGFloat = 8
    static let height: CGFloat = 30
    static let cornerRadius: CGFloat = 7
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrics.spacing) {
        ZStack {
          Circle()
            .strokeBorder(isSelected ? TLTheme.accentBlue : Color.secondary.opacity(0.45), lineWidth: Metrics.indicatorLineWidth)
            .background(Circle().fill(isSelected ? TLTheme.accentBlue : Color.clear))
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: Metrics.checkSize, weight: .bold))
              .foregroundStyle(.white)
          }
        }
        .frame(width: Metrics.indicatorSize, height: Metrics.indicatorSize)

        Text(title)
          .font(.system(size: Metrics.fontSize, weight: .semibold))
          .lineLimit(1)
        Spacer()
      }
      .padding(.horizontal, Metrics.horizontalPadding)
      .frame(height: Metrics.height)
      .background(RoundedRectangle(cornerRadius: Metrics.cornerRadius).fill(hovering ? TLTheme.hoverFill : Color.clear))
      .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

struct ModelInventoryRow: View {
  let row: ModelLibraryRow
  let isSelected: Bool
  let select: () -> Void
  let startDownload: () -> Void
  let cancelDownload: () -> Void
  let delete: () -> Void

  @State private var hovering = false

  private enum Metrics {
    static let rowSpacing: CGFloat = 10
    static let titleSpacing: CGFloat = 5
    static let detailSpacing: CGFloat = 8
    static let minimumSpacer: CGFloat = 12
    static let titleSize: CGFloat = 13
    static let sizeFont: CGFloat = 11
    static let sizeWidth: CGFloat = 64
    static let selectedIconSize: CGFloat = 13
    static let selectedFrame: CGFloat = 18
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let hoverOpacity = 0.03
  }

  var body: some View {
    HStack(alignment: .center, spacing: Metrics.rowSpacing) {
      TLProviderLogo(provider: row.provider)

      VStack(alignment: .leading, spacing: Metrics.titleSpacing) {
        Text(row.entry.displayName)
          .font(.system(size: Metrics.titleSize, weight: .semibold))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
          .layoutPriority(1)
        rowDetails
      }

      Spacer(minLength: Metrics.minimumSpacer)

      selectionIndicator

      if let sizeText = row.entry.storageSizeText {
        Text(sizeText)
          .font(.system(size: Metrics.sizeFont))
          .foregroundStyle(.tertiary)
          .frame(width: Metrics.sizeWidth, alignment: .trailing)
      }

      ModelDownloadControl(
        state: row.downloadControlState,
        hovering: hovering,
        startDownload: startDownload,
        cancelDownload: cancelDownload,
        delete: delete
      )
    }
    .padding(.horizontal, Metrics.horizontalPadding)
    .padding(.vertical, Metrics.verticalPadding)
    .background(hovering ? Color.primary.opacity(Metrics.hoverOpacity) : .clear)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .onTapGesture {
      if row.entry.isSelectable {
        select()
      }
    }
    .contextMenu {
      if row.entry.isSelectable {
        Button("Select") { select() }
      }
      if row.downloadControlState == .notDownloaded {
        Button("Download") { startDownload() }
      }
      if case .downloading = row.downloadControlState {
        Button("Cancel Download", role: .destructive) { cancelDownload() }
      }
      if row.downloadControlState == .downloaded {
        Button("Delete", role: .destructive) { delete() }
      }
    }
  }

  private var rowDetails: some View {
    HStack(spacing: Metrics.detailSpacing) {
      ForEach(row.capabilityLabels, id: \.self) { label in
        ModelCapabilityChip(label: label)
      }
      ForEach(row.metricItems) { metric in
        MetricDots(label: metric.label, value: metric.value)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  @ViewBuilder private var selectionIndicator: some View {
    if row.entry.isSelectable {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.system(size: Metrics.selectedIconSize, weight: .semibold))
        .foregroundStyle(isSelected ? TLTheme.accentBlue : Color.secondary.opacity(0.38))
        .frame(width: Metrics.selectedFrame, height: Metrics.selectedFrame)
    }
  }
}

private struct ModelCapabilityChip: View {
  let label: String

  private enum Metrics {
    static let fontSize: CGFloat = 10
    static let horizontalPadding: CGFloat = 5
    static let verticalPadding: CGFloat = 2
  }

  var body: some View {
    Text(label)
      .font(.system(size: Metrics.fontSize, weight: .medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .padding(.horizontal, Metrics.horizontalPadding)
      .padding(.vertical, Metrics.verticalPadding)
      .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: TLTheme.chipRadius))
  }
}

private struct MetricDots: View {
  let label: String
  let value: String

  private enum Metrics {
    static let spacing: CGFloat = 5
    static let labelSize: CGFloat = 10
    static let valueSize: CGFloat = 10
    static let dotSize: CGFloat = 4
  }

  var body: some View {
    HStack(spacing: Metrics.spacing) {
      Circle()
        .fill(Color.secondary.opacity(0.45))
        .frame(width: Metrics.dotSize, height: Metrics.dotSize)
      Text(label)
        .font(.system(size: Metrics.labelSize))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
      Text(value)
        .font(.system(size: Metrics.valueSize, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}
