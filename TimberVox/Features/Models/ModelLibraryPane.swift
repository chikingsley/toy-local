import TimberVoxCore
import Foundation
import SwiftUI

struct ModelLibraryPane: View {
  @Bindable var store: SettingsStore

  @State private var query = ""
  @State private var activeFilter: ModelLibraryFilter?
  @State private var supportExpanded = false

  init(store: SettingsStore) {
    self.store = store
  }

  private var sections: [ModelLibrarySectionViewModel] {
    store.modelDownload.modelLibrarySections
  }

  private var modelSections: [ModelLibrarySectionViewModel] {
    sections.filter { $0.id != .supportAssets }
  }

  private var supportSectionModel: ModelLibrarySectionViewModel? {
    sections.first { $0.id == .supportAssets }
  }

  private var supportRows: [ModelLibraryRow] {
    supportSectionModel?.rows ?? []
  }

  private var visibleSupportRows: [ModelLibraryRow] {
    visibleRows(in: supportRows)
  }

  private var supportShouldShowRows: Bool {
    supportExpanded || !query.isEmpty || activeFilter != nil
  }

  private var downloadedLocalRows: [ModelLibraryRow] {
    sections.flatMap(\.rows).filter { row in
      row.entry.runtime == .local && row.isDownloaded
    }
  }

  private var downloadingCount: Int {
    sections.flatMap(\.rows).filter { row in
      if case .downloading = row.downloadState { return true }
      return false
    }.count
  }

  private var storageSummary: String {
    let sizeMB = downloadedLocalRows.compactMap(\.entry.approximateSizeMB).reduce(0, +)
    let assetLabel = downloadedLocalRows.count == ModelLibraryMetrics.singleItemCount ? "asset" : "assets"
    guard sizeMB > 0 else {
      return "\(downloadedLocalRows.count) local \(assetLabel)"
    }
    return "\(downloadedLocalRows.count) local \(assetLabel) - \(Self.storageText(forMegabytes: sizeMB)) on disk"
  }

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        headerContent
      } trailing: {
        headerActions
      }

      TLPane {
        ForEach(modelSections) { section in
          modelSection(section)
        }
        supportSection
      }

      storageFooter
    }
    .task {
      if store.modelDownload.availableModels.isEmpty {
        store.modelDownload.fetchModels()
      }
    }
  }

  private var headerContent: some View {
    TLSearchField(placeholder: "Search models...", text: $query)
      .frame(maxWidth: .infinity)
  }

  private var headerActions: some View {
    HStack(spacing: ModelLibraryMetrics.headerActionSpacing) {
      if let activeFilter {
        ModelFilterChip(title: activeFilter.label) {
          self.activeFilter = nil
        }
      }
      ModelLibraryFilterMenu(selection: $activeFilter)
    }
  }

  private func modelSection(_ section: ModelLibrarySectionViewModel) -> some View {
    let rows = visibleRows(in: section.rows)
    return VStack(alignment: .leading, spacing: ModelLibraryMetrics.sectionSpacing) {
      Text(section.title)
        .font(.system(size: ModelLibraryMetrics.sectionTitleSize, weight: .semibold))
        .foregroundStyle(.secondary)

      TLSettingsCard {
        if rows.isEmpty {
          emptyRow
        } else {
          ForEach(rows) { row in
            inventoryRow(row)
          }
        }
      }
    }
  }

  private var supportSection: some View {
    VStack(alignment: .leading, spacing: ModelLibraryMetrics.sectionSpacing) {
      Button {
        withAnimation(.easeInOut(duration: ModelLibraryMetrics.expandAnimationDuration)) {
          supportExpanded.toggle()
        }
      } label: {
        HStack(spacing: ModelLibraryMetrics.supportHeaderSpacing) {
          Image(systemName: "chevron.right")
            .font(.system(size: ModelLibraryMetrics.chevronSize, weight: .semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(supportShouldShowRows ? ModelLibraryMetrics.expandedDegrees : 0))
          Text(supportSectionModel?.title ?? ModelLibrarySectionID.supportAssets.title)
            .font(.system(size: ModelLibraryMetrics.sectionTitleSize, weight: .semibold))
            .foregroundStyle(.secondary)
          TLInfoHint("Support models are downloaded when a feature needs them. They are not normal dictation choices.")
          Spacer()
          Text(supportShouldShowRows ? "\(visibleSupportRows.count) shown" : "Collapsed")
            .font(.system(size: ModelLibraryMetrics.supportStatusSize))
            .foregroundStyle(.tertiary)
        }
      }
      .buttonStyle(.plain)

      TLSettingsCard {
        if supportShouldShowRows {
          if visibleSupportRows.isEmpty {
            emptyRow
          } else {
            ForEach(visibleSupportRows) { row in
              inventoryRow(row)
            }
          }
        } else {
          collapsedSupportRow
        }
      }
    }
  }

  private var collapsedSupportRow: some View {
    HStack(spacing: ModelLibraryMetrics.collapsedSupportSpacing) {
      Image(systemName: "puzzlepiece.extension")
        .font(.system(size: ModelLibraryMetrics.collapsedSupportIconSize))
        .foregroundStyle(.secondary)
        .frame(width: ModelLibraryMetrics.collapsedSupportIconFrame)
      VStack(alignment: .leading, spacing: ModelLibraryMetrics.collapsedSupportTextSpacing) {
        Text("Silence removal, speaker recognition, vocabulary")
          .font(.system(size: ModelLibraryMetrics.collapsedSupportTitleSize))
        Text("Downloaded only when those features are enabled.")
          .font(.system(size: ModelLibraryMetrics.collapsedSupportSubtitleSize))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text("\(supportRows.count) assets")
        .font(.system(size: ModelLibraryMetrics.collapsedSupportSubtitleSize, weight: .medium))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, ModelLibraryMetrics.rowHorizontalPadding)
    .padding(.vertical, ModelLibraryMetrics.collapsedSupportVerticalPadding)
  }

  private var emptyRow: some View {
    Text("No models match this search")
      .font(.system(size: ModelLibraryMetrics.emptyFontSize))
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, ModelLibraryMetrics.emptyVerticalPadding)
  }

  private var storageFooter: some View {
    HStack(spacing: ModelLibraryMetrics.footerSpacing) {
      Image(systemName: "internaldrive")
        .font(.system(size: ModelLibraryMetrics.footerIconSize))
        .foregroundStyle(.tertiary)
      Text(storageSummary)
        .font(.system(size: ModelLibraryMetrics.footerFontSize))
        .foregroundStyle(.secondary)
      if downloadingCount > 0 {
        Text("\(downloadingCount) downloading")
          .font(.system(size: ModelLibraryMetrics.downloadBadgeFontSize, weight: .medium))
          .foregroundStyle(Color(hex: Shadcn.orange400))
          .padding(.horizontal, ModelLibraryMetrics.downloadBadgeHorizontalPadding)
          .padding(.vertical, ModelLibraryMetrics.downloadBadgeVerticalPadding)
          .background(
            Color(hex: Shadcn.orange400).opacity(ModelLibraryMetrics.downloadBadgeOpacity), in: RoundedRectangle(cornerRadius: TLTheme.chipRadius))
      }
      Spacer()
      Button {
        store.modelDownload.openModelLocation()
      } label: {
        HStack(spacing: ModelLibraryMetrics.finderButtonSpacing) {
          Image(systemName: "folder")
            .font(.system(size: ModelLibraryMetrics.finderIconSize))
          Text("Show in Finder")
            .font(.system(size: ModelLibraryMetrics.footerFontSize, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, ModelLibraryMetrics.finderHorizontalPadding)
        .padding(.vertical, ModelLibraryMetrics.finderVerticalPadding)
        .background(
          .primary.opacity(ModelLibraryMetrics.finderBackgroundOpacity), in: RoundedRectangle(cornerRadius: ModelLibraryMetrics.finderCornerRadius))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, ModelLibraryMetrics.footerHorizontalPadding)
    .padding(.vertical, ModelLibraryMetrics.footerVerticalPadding)
    .background(.primary.opacity(ModelLibraryMetrics.footerBackgroundOpacity))
    .overlay(alignment: .top) {
      Rectangle().fill(TLTheme.hairline).frame(height: ModelLibraryMetrics.hairlineHeight)
    }
  }

  private func visibleRows(in rows: [ModelLibraryRow]) -> [ModelLibraryRow] {
    rows.filter { $0.matches(query: query, filter: activeFilter) }
  }

  private func inventoryRow(_ row: ModelLibraryRow) -> some View {
    ModelInventoryRow(
      row: row,
      isSelected: isSelected(row),
      select: { select(row) },
      startDownload: { startDownload(row) },
      cancelDownload: { store.modelDownload.cancelDownload() },
      delete: { store.modelDownload.deleteModel(row.entry.id) }
    )
  }

  private func isSelected(_ row: ModelLibraryRow) -> Bool {
    switch row.entry.sectionID {
    case .localDictation, .cloudDictation:
      store.timberVoxSettings.selectedModel == row.entry.id
    case .streamingPreview:
      store.timberVoxSettings.alwaysOnStreamingModel == row.entry.id
    case .cloudText:
      store.timberVoxSettings.textTransformModel == row.entry.id
    case .supportAssets:
      false
    }
  }

  private func select(_ row: ModelLibraryRow) {
    guard row.entry.isSelectable else { return }
    switch row.entry.sectionID {
    case .cloudText:
      store.timberVoxSettings.textTransformModel = row.entry.id
    case .localDictation, .cloudDictation, .streamingPreview:
      store.modelDownload.selectModel(row.entry.id)
    case .supportAssets:
      break
    }
  }

  private func startDownload(_ row: ModelLibraryRow) {
    if row.entry.isSelectable {
      select(row)
    }
    store.modelDownload.downloadModel(row.entry.id)
  }

  private static func storageText(forMegabytes sizeMB: Double) -> String {
    if sizeMB >= ModelLibraryMetrics.megabytesPerGigabyte {
      return String(format: "%.1f GB", sizeMB / ModelLibraryMetrics.megabytesPerGigabyte)
    }
    return "\(Int(sizeMB.rounded())) MB"
  }
}

private enum ModelLibraryMetrics {
  static let singleItemCount = 1
  static let megabytesPerGigabyte = 1000.0
  static let headerActionSpacing: CGFloat = 8
  static let sectionSpacing: CGFloat = 8
  static let sectionTitleSize: CGFloat = 12
  static let expandAnimationDuration = 0.16
  static let supportHeaderSpacing: CGFloat = 6
  static let chevronSize: CGFloat = 9
  static let expandedDegrees = 90.0
  static let supportStatusSize: CGFloat = 11
  static let collapsedSupportSpacing: CGFloat = 10
  static let collapsedSupportIconSize: CGFloat = 13
  static let collapsedSupportIconFrame: CGFloat = 20
  static let collapsedSupportTextSpacing: CGFloat = 2
  static let collapsedSupportTitleSize: CGFloat = 13
  static let collapsedSupportSubtitleSize: CGFloat = 11
  static let rowHorizontalPadding: CGFloat = 12
  static let collapsedSupportVerticalPadding: CGFloat = 10
  static let emptyFontSize: CGFloat = 12
  static let emptyVerticalPadding: CGFloat = 18
  static let footerSpacing: CGFloat = 8
  static let footerIconSize: CGFloat = 11
  static let footerFontSize: CGFloat = 11
  static let downloadBadgeFontSize: CGFloat = 10
  static let downloadBadgeHorizontalPadding: CGFloat = 6
  static let downloadBadgeVerticalPadding: CGFloat = 2
  static let downloadBadgeOpacity = 0.13
  static let finderButtonSpacing: CGFloat = 4
  static let finderIconSize: CGFloat = 10
  static let finderHorizontalPadding: CGFloat = 8
  static let finderVerticalPadding: CGFloat = 4
  static let finderBackgroundOpacity = 0.07
  static let finderCornerRadius: CGFloat = 5
  static let footerHorizontalPadding: CGFloat = 18
  static let footerVerticalPadding: CGFloat = 10
  static let footerBackgroundOpacity = 0.03
  static let hairlineHeight: CGFloat = 1
}

#Preview("Model library") {
  let store = AppPreviewState.makeStore()
  TLFloatingHost {
    ModelLibraryPane(store: store.settings)
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
