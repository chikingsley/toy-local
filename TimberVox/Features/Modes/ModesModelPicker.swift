import TimberVoxCore
import SwiftUI

struct ModesModelMenu: View {
  @Binding var selection: ModeModelOption
  let models: [ModeModelOption]
  var width: CGFloat = 190

  @State private var presentationID = UUID()
  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  var body: some View {
    Button {
      toggleMenu()
    } label: {
      ModesValuePill(text: selection.name, provider: selection.provider, width: width)
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
      estimatedSize: CGSize(width: PickerMetrics.minPanelWidth, height: estimatedPanelHeight),
      blocksBackground: true
    ) {
      ModesModelPicker(
        selection: $selection,
        models: models,
        hoverNamespace: presentationID.uuidString
      ) {
        floatingLayer?.dismissAll()
      }
    }
  }

  private var estimatedPanelHeight: CGFloat {
    let searchArea: CGFloat = 52
    let sectionTitles: CGFloat = 52
    let visibleRows = CGFloat(min(models.count, PickerMetrics.visibleRows))
    return searchArea + sectionTitles + visibleRows * PickerMetrics.rowHeight + 12
  }
}

private enum PickerMetrics {
  static let visibleRows = 6
  static let rowHeight: CGFloat = 31
  static let minPanelWidth: CGFloat = 300
  static let maxListHeight = CGFloat(visibleRows) * rowHeight + 60
}

#Preview("Voice model picker sizes to content") {
  ModesModelPicker(
    selection: .constant(ModeModelOption.voiceModels[0]),
    models: ModeModelOption.voiceModels,
    hoverNamespace: "preview"
  ) {}
  .padding(24)
}

struct ModesModelPicker: View {
  @Binding var selection: ModeModelOption
  let models: [ModeModelOption]
  let hoverNamespace: String
  let dismiss: () -> Void
  @State private var searchText = ""
  @State private var hoveredModelID: ModeModelOption.ID?
  @State private var favoriteIDs: Set<ModeModelOption.ID> = ["parakeet"]
  @State private var downloadedIDs: Set<ModeModelOption.ID> = ["parakeet", "s1"]

  private var filteredModels: [ModeModelOption] {
    guard !searchText.isEmpty else { return models }
    return models.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
        || $0.description.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var favoriteModels: [ModeModelOption] {
    filteredModels.filter { favoriteIDs.contains($0.id) }
  }

  private var popularModels: [ModeModelOption] {
    filteredModels.filter { !favoriteIDs.contains($0.id) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TLSearchField(placeholder: "Search models", text: $searchText)
        .padding(10)

      ScrollView {
        VStack(spacing: 1) {
          if !favoriteModels.isEmpty {
            ModesModelSectionTitle(title: "Favorites")
            ForEach(favoriteModels) { model in
              modelButton(model)
            }
          }

          ModesModelSectionTitle(title: "Popular")
            .padding(.top, favoriteModels.isEmpty ? 0 : 7)

          ForEach(popularModels) { model in
            modelButton(model)
          }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
      }
      .frame(maxHeight: PickerMetrics.maxListHeight)
    }
    .frame(minWidth: PickerMetrics.minPanelWidth, alignment: .leading)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: 9))
  }

  private func modelButton(_ model: ModeModelOption) -> some View {
    ModesModelPickerButton(
      hoverNamespace: hoverNamespace,
      model: model,
      isSelected: model.id == selection.id,
      isHovered: hoveredModelID == model.id,
      isFavorite: favoriteIDs.contains(model.id),
      isDownloaded: downloadedIDs.contains(model.id),
      onSelect: {
        selection = model
        dismiss()
      },
      onHover: { hovering in
        hoveredModelID = hovering ? model.id : (hoveredModelID == model.id ? nil : hoveredModelID)
      },
      onToggleFavorite: {
        if favoriteIDs.contains(model.id) {
          favoriteIDs.remove(model.id)
        } else {
          favoriteIDs.insert(model.id)
        }
      },
      onToggleDownload: {
        if downloadedIDs.contains(model.id) {
          downloadedIDs.remove(model.id)
        } else {
          downloadedIDs.insert(model.id)
        }
      }
    )
  }
}

struct ModesModelSectionTitle: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 6)
      .padding(.bottom, 2)
  }
}

struct ModesModelPickerButton: View {
  let hoverNamespace: String
  let model: ModeModelOption
  let isSelected: Bool
  let isHovered: Bool
  let isFavorite: Bool
  let isDownloaded: Bool
  let onSelect: () -> Void
  let onHover: (Bool) -> Void
  let onToggleFavorite: () -> Void
  let onToggleDownload: () -> Void

  @State private var anchorFrame: CGRect = .zero
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  private var detailID: AnyHashable {
    AnyHashable("\(hoverNamespace)-\(model.id)-detail")
  }

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        TLProviderLogo(provider: model.provider, size: 20)
        Text(model.name)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
          .layoutPriority(1)
        if !model.badge.isEmpty {
          Text(model.badge)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: TLTheme.chipRadius))
        }
        Spacer()
        Button {
          onToggleFavorite()
        } label: {
          Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isFavorite ? Color.yellow : .secondary)
            .opacity(isFavorite || isHovered ? 1 : 0)
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)

        ModelDownloadControl(
          state: model.availability == .cloud
            ? .cloud
            : (isDownloaded ? .downloaded : .notDownloaded),
          hovering: isHovered,
          startDownload: onToggleDownload,
          delete: onToggleDownload
        )
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isSelected ? TLTheme.accentGreen.opacity(0.12) : (isHovered ? Color.primary.opacity(0.07) : .clear))
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
              TLTheme.accentGreen,
              style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
      }
    }
    .buttonStyle(.plain)
    .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
    .onHover { hovering in
      onHover(hovering)
      if hovering {
        presentDetail()
      } else {
        floatingLayer?.dismiss(id: detailID)
      }
    }
    .onChange(of: anchorFrame) { _, _ in
      if isHovered {
        presentDetail()
      }
    }
    .onDisappear {
      floatingLayer?.dismiss(id: detailID)
    }
  }

  private func presentDetail() {
    guard anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: detailID,
      anchor: anchorFrame,
      placement: .left,
      spacing: 10,
      estimatedSize: CGSize(width: 228, height: 168),
      allowsHitTesting: false
    ) {
      ModesModelInfoCard(model: model)
    }
  }
}

struct ModesModelInfoCard: View {
  let model: ModeModelOption

  var body: some View {
    TLPopoverCard(width: 228) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          TLProviderLogo(provider: model.provider, size: 22)
          VStack(alignment: .leading, spacing: 1) {
            Text(model.name)
              .font(.system(size: 13, weight: .semibold))
            Text(model.provider.displayName)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.secondary)
          }
        }

        Text(model.description)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        ModesModelMetric(title: "Speed", value: model.provider.speed)
        ModesModelMetric(title: "Accuracy", value: model.provider.accuracy)

        HStack {
          Text("Size")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Label(model.availability == .cloud ? "Cloud" : "Local", systemImage: model.availability == .cloud ? "icloud" : "internaldrive")
            .font(.system(size: 11, weight: .semibold))
        }
      }
    }
  }
}

struct ModesModelMetric: View {
  let title: String
  let value: Double

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 48, alignment: .leading)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(.primary.opacity(0.08))
          Capsule()
            .fill(Color.accentColor)
            .frame(width: proxy.size.width * value)
        }
      }
      .frame(height: 3)
    }
  }
}
