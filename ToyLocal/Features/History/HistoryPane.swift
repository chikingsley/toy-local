import AppKit
import SwiftUI

struct HistoryPane: View {
  private enum Route: Equatable {
    case list
    case detail(HistoryItem.ID)
  }

  @Bindable var store: HistoryStore
  @Binding var deepLinkItemID: String?

  init(store: HistoryStore, deepLinkItemID: Binding<String?> = .constant(nil)) {
    self.store = store
    self._deepLinkItemID = deepLinkItemID
  }

  @State private var route: Route = .list
  @State private var appFilter = HistoryAppFilter.all
  @State private var dayFilter: String?
  @State private var searchText = ""
  @State private var editingTitleID: HistoryItem.ID?
  @State private var titleDraft = ""
  @State private var detailSheetItemID: HistoryItem.ID?
  @State private var headerCopiedItemID: HistoryItem.ID?

  private var fetchedItems: [HistoryItem] {
    store.records.map(HistoryItem.init(record:))
  }

  private var filteredItems: [HistoryItem] {
    fetchedItems.filter { item in
      let appMatch = appFilter.matches(item.app)
      let dayMatch = dayFilter == nil || item.dayLabel == dayFilter
      return appMatch && dayMatch
    }
  }

  private var appFilterOptions: [TLMenuOption<HistoryAppFilter>] {
    HistoryAppFilter.options(for: fetchedItems)
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      VStack(spacing: 0) {
        header

        switch route {
        case .list:
          listPage
            .transition(.opacity.combined(with: .move(edge: .leading)))
        case .detail(let itemID):
          if let item = item(for: itemID) {
            HistoryDetail(
              item: item,
              title: item.title,
              isPlaying: store.playingTranscriptID == item.id,
              playbackPosition: store.playbackPosition,
              playbackDuration: store.playbackDuration,
              togglePlayback: { store.playTranscript(item.id) },
              seek: { store.seek(to: $0) }
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
          } else {
            HistoryEmptyState(
              systemName: "text.bubble",
              title: "Transcript not found",
              message: "The selected transcript is no longer in history."
            )
          }
        }
      }

      detailSheet
    }
    .animation(.easeInOut(duration: HistoryMetrics.animationDuration), value: route)
    .animation(.easeInOut(duration: HistoryMetrics.animationDuration), value: detailSheetItemID)
    .onAppear {
      store.refreshRecords()
      normalizeFilters()
      consumeDeepLink()
    }
    .onChange(of: deepLinkItemID) { _, _ in
      consumeDeepLink()
    }
    .onChange(of: searchText) { _, text in
      store.search(text)
      normalizeFilters()
    }
    .onChange(of: store.records.map(\.id)) { _, _ in
      normalizeFilters()
    }
  }

  private var header: some View {
    TLHeader(control: headerControl) {
      if route == .list {
        TLSearchField(placeholder: "Search history", text: $searchText)
          .frame(maxWidth: .infinity)
      } else if case .detail(let itemID) = route, let item = item(for: itemID) {
        HStack(spacing: 9) {
          HistoryAppIcon(app: item.app, size: 24)
          HistoryEditableTitle(
            title: item.title,
            draft: $titleDraft,
            isEditing: editingTitleID == item.id,
            beginEditing: {
              titleDraft = item.title
              editingTitleID = item.id
            },
            commit: { commitTitle(item) },
            cancel: {
              titleDraft = item.title
              editingTitleID = nil
            }
          )
          Text("-")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
          Text(item.timeLabel)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(.secondary)
          Spacer(minLength: 0)
        }
      }
    } trailing: {
      if route == .list {
        historyToolbar
      } else if case .detail(let itemID) = route, let item = item(for: itemID) {
        HistoryHeaderActions(
          copied: headerCopiedItemID == item.id,
          openDetails: { detailSheetItemID = item.id },
          copy: { copyHeaderItem(item) },
          delete: { deleteItem(item) }
        )
      }
    }
  }

  private var headerControl: TLHeaderControl {
    switch route {
    case .list:
      .sidebarToggle
    case .detail:
      .back {
        withAnimation(.easeInOut(duration: HistoryMetrics.animationDuration)) {
          route = .list
          editingTitleID = nil
        }
      }
    }
  }

  private var historyToolbar: some View {
    HStack(spacing: 8) {
      TLOptionMenu(
        selection: $dayFilter,
        options: HistoryDayFilter.options(for: fetchedItems)
      )
      TLOptionMenu(
        selection: $appFilter,
        options: appFilterOptions
      )
    }
    .fixedSize()
  }

  private var listPage: some View {
    Group {
      if !store.saveTranscriptionHistory {
        HistoryEmptyState(
          systemName: "clock.arrow.circlepath",
          title: "History disabled",
          message: "Transcription history is turned off in settings."
        )
      } else if filteredItems.isEmpty {
        HistoryEmptyState(
          systemName: "text.bubble",
          title: searchText.isEmpty ? "No history yet" : "No matches",
          message: searchText.isEmpty
            ? "New dictations will appear here after they are saved."
            : "Try a different search, day, or app filter."
        )
      } else {
        TLScrollArea(
          contentPadding: EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0),
          spacing: HistoryMetrics.sectionSpacing
        ) {
          ForEach(HistoryDayFilter.orderedDayLabels(for: filteredItems), id: \.self) { day in
            let items = filteredItems.filter { $0.dayLabel == day }
            if !items.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text(day)
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(.secondary)
                VStack(spacing: HistoryMetrics.rowSpacing) {
                  ForEach(items) { item in
                    HistoryRow(item: item) {
                      openItem(item)
                    }
                  }
                }
              }
            }
          }
        }
        .padding(HistoryMetrics.panePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
  }

  @ViewBuilder private var detailSheet: some View {
    if let detailSheetItemID, let item = item(for: detailSheetItemID) {
      Color.black.opacity(0.24)
        .ignoresSafeArea()
        .onTapGesture { self.detailSheetItemID = nil }

      HistoryRecordingDetailsSheet(
        item: item,
        title: item.title,
        close: { self.detailSheetItemID = nil },
        openFileLocation: { openFileLocation(for: item) },
        delete: { deleteItem(item) }
      )
      .transition(.move(edge: .trailing).combined(with: .opacity))
    }
  }

  private func consumeDeepLink() {
    guard let id = deepLinkItemID else { return }
    deepLinkItemID = nil
    store.refreshRecords()
    guard item(for: id) != nil else { return }
    titleDraft = item(for: id)?.title ?? ""
    editingTitleID = nil
    withAnimation(.easeInOut(duration: HistoryMetrics.animationDuration)) {
      route = .detail(id)
    }
  }

  private func item(for id: HistoryItem.ID) -> HistoryItem? {
    if let record = store.records.first(where: { $0.id == id }) {
      return HistoryItem(record: record)
    }
    return store.record(id: id).map(HistoryItem.init(record:))
  }

  private func openItem(_ item: HistoryItem) {
    titleDraft = item.title
    editingTitleID = nil
    withAnimation(.easeInOut(duration: HistoryMetrics.animationDuration)) {
      route = .detail(item.id)
    }
  }

  private func commitTitle(_ item: HistoryItem) {
    let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedTitle.isEmpty {
      store.updateTitle(id: item.id, title: trimmedTitle)
    }
    editingTitleID = nil
  }

  private func copyHeaderItem(_ item: HistoryItem) {
    store.copyToClipboard(item.processedText)
    headerCopiedItemID = item.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
      if headerCopiedItemID == item.id {
        headerCopiedItemID = nil
      }
    }
  }

  private func deleteItem(_ item: HistoryItem) {
    store.deleteTranscript(item.id)
    detailSheetItemID = nil
    editingTitleID = nil
    withAnimation(.easeInOut(duration: HistoryMetrics.animationDuration)) {
      route = .list
    }
  }

  private func openFileLocation(for item: HistoryItem) {
    guard let url = item.audioURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  private func normalizeFilters() {
    if !appFilterOptions.map(\.value).contains(appFilter) {
      appFilter = .all
    }
    if let dayFilter {
      let validDays = Set(HistoryDayFilter.options(for: fetchedItems).compactMap { $0.value })
      if !validDays.contains(dayFilter) {
        self.dayFilter = nil
      }
    }
  }
}

#Preview("History") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    HistoryPane(store: store.history)
      .frame(width: 640, height: 680)
      .background(TLTheme.windowBackground)
  }
}
