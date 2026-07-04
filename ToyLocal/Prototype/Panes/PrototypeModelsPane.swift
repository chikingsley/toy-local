import SwiftUI

private enum LibrarySection: String, CaseIterable, Identifiable {
  case localASR = "Local ASR"
  case cloudASR = "Cloud ASR"
  case cloudText = "Cloud Text"

  var id: String { rawValue }
}

private enum ModelLibraryFilter: String, CaseIterable, Hashable {
  case voice
  case language
  case cloud
  case offline
  case favorites
  case downloaded

  var label: String {
    switch self {
    case .voice: "Voice models"
    case .language: "Language models"
    case .cloud: "Cloud"
    case .offline: "Offline"
    case .favorites: "Favorites"
    case .downloaded: "Downloaded"
    }
  }
}

enum TLModelDownloadState {
  case downloaded
  case downloading(Double)
  case notDownloaded
  case cloud
}

private struct LibraryModel: Identifiable {
  let id: String
  let name: String
  let provider: TLProvider
  let section: LibrarySection
  let note: String
  let primaryMetricLabel: String
  let primaryMetric: Int
  let speed: Int
  var size: String?
  var sizeMB: Double?
  var state: TLModelDownloadState
  var favorite = false

  var isCloud: Bool {
    section == .cloudASR || section == .cloudText
  }

  var isLanguage: Bool {
    section == .cloudText
  }

  var isDownloaded: Bool {
    if case .downloaded = state { return true }
    return false
  }

  func matches(query: String, filter: ModelLibraryFilter?) -> Bool {
    let matchesQuery =
      query.isEmpty
      || [name, provider.displayName, section.rawValue, note]
        .joined(separator: " ")
        .localizedCaseInsensitiveContains(query)

    guard matchesQuery else { return false }
    guard let filter else { return true }

    return switch filter {
    case .voice: !isLanguage
    case .language: isLanguage
    case .cloud: isCloud
    case .offline: !isCloud
    case .favorites: favorite
    case .downloaded: isDownloaded
    }
  }
}

private struct SupportModel: Identifiable {
  let id: String
  let name: String
  let provider: TLProvider
  let usedBy: String
  var size: String
  var sizeMB: Double
  var state: TLModelDownloadState

  func matches(_ query: String) -> Bool {
    guard !query.isEmpty else { return true }
    return [name, provider.displayName, usedBy]
      .joined(separator: " ")
      .localizedCaseInsensitiveContains(query)
  }
}

struct PrototypeModelsPane: View {
  @State private var query = ""
  @State private var activeFilter: ModelLibraryFilter? = nil
  @State private var supportExpanded = false
  @State private var models = Self.makeModels()
  @State private var supportModels = Self.makeSupportModels()

  private var visibleModels: [LibraryModel] {
    models.filter { $0.matches(query: query, filter: activeFilter) }
  }

  private var visibleSupportModels: [SupportModel] {
    supportModels.filter { $0.matches(query) }
  }

  private var supportShouldShowRows: Bool {
    supportExpanded || !query.isEmpty
  }

  private var downloadedLocalModels: [LibraryModel] {
    models.filter { model in
      guard model.section == .localASR else { return false }
      if case .downloaded = model.state { return true }
      return false
    }
  }

  private var downloadingCount: Int {
    let modelDownloads = models.filter {
      if case .downloading = $0.state { return true }
      return false
    }.count
    let supportDownloads = supportModels.filter {
      if case .downloading = $0.state { return true }
      return false
    }.count
    return modelDownloads + supportDownloads
  }

  private var storageSummary: String {
    let sizeMB = downloadedLocalModels.compactMap(\.sizeMB).reduce(0, +)
    let sizeText =
      sizeMB >= 1000
      ? String(format: "%.1f GB", sizeMB / 1000)
      : "\(Int(sizeMB)) MB"
    return "\(downloadedLocalModels.count) local models · \(sizeText) on disk"
  }

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        headerContent
      } trailing: {
        headerActions
      }

      TLPane {
        ForEach(LibrarySection.allCases) { section in
          modelSection(section)
        }
        supportSection
      }

      storageFooter
    }
  }

  private var headerContent: some View {
    TLSearchField(placeholder: "Search models…", text: $query)
      .frame(maxWidth: .infinity)
  }

  private var headerActions: some View {
    HStack(spacing: 8) {
      if let activeFilter {
        ModelFilterChip(title: activeFilter.label) {
          self.activeFilter = nil
        }
      }
      ModelLibraryFilterMenu(selection: $activeFilter)
    }
  }

  private func modelSection(_ section: LibrarySection) -> some View {
    let rows = visibleModels.filter { $0.section == section }
    return VStack(alignment: .leading, spacing: 8) {
      Text(section.rawValue)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)

      TLSettingsCard {
        if rows.isEmpty {
          emptyRow
        } else {
          ForEach(rows) { model in
            ModelInventoryRow(
              provider: model.provider,
              title: "\(model.name) · \(model.note)",
              sizeText: model.size,
              state: model.state,
              startDownload: { setModelState(.downloading(0.06), id: model.id) },
              cancelDownload: { setModelState(.notDownloaded, id: model.id) },
              delete: { setModelState(.notDownloaded, id: model.id) }
            ) {
              HStack(spacing: 12) {
                MetricDots(label: model.primaryMetricLabel, filled: model.primaryMetric)
                MetricDots(label: "Speed", filled: model.speed)
              }
              .fixedSize(horizontal: true, vertical: false)
            }
            if model.id != rows.last?.id {
            }
          }
        }

      }
    }
  }

  private var supportSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(.easeInOut(duration: 0.16)) {
          supportExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(supportShouldShowRows ? 90 : 0))
          Text("Support models")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          TLInfoHint("Support models are downloaded when a feature needs them. They are not normal dictation choices.")
          Spacer()
          Text(supportShouldShowRows ? "\(visibleSupportModels.count) shown" : "Collapsed")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
      .buttonStyle(.plain)

      TLSettingsCard {
        if supportShouldShowRows {
          if visibleSupportModels.isEmpty {
            emptyRow
          } else {
            ForEach(visibleSupportModels) { model in
              ModelInventoryRow(
                provider: model.provider,
                title: "\(model.name) · \(model.usedBy)",
                sizeText: model.size,
                state: model.state,
                startDownload: { setSupportState(.downloading(0.06), id: model.id) },
                cancelDownload: { setSupportState(.notDownloaded, id: model.id) },
                delete: { setSupportState(.notDownloaded, id: model.id) }
              ) {
                Text("Support asset")
                  .font(.system(size: 11))
                  .foregroundStyle(.tertiary)
              }
              if model.id != visibleSupportModels.last?.id {
              }
            }
          }
        } else {
          HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
              Text("Silence detection, speaker recognition, voice commands")
                .font(.system(size: 13))
              Text("Downloaded only when those features are enabled.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(supportModels.count) assets")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
        }

      }
    }
  }

  private var emptyRow: some View {
    Text("No models match this search")
      .font(.system(size: 12))
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
  }

  private var storageFooter: some View {
    HStack(spacing: 8) {
      Image(systemName: "internaldrive")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      Text(storageSummary)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      if downloadingCount > 0 {
        Text("\(downloadingCount) downloading")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color(hex: Shadcn.orange400))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color(hex: Shadcn.orange400).opacity(0.13), in: RoundedRectangle(cornerRadius: TLTheme.chipRadius))
      }
      Spacer()
      Button {
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "folder")
            .font(.system(size: 10))
          Text("Show in Finder")
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .background(.primary.opacity(0.03))
    .overlay(alignment: .top) {
      Rectangle().fill(TLTheme.hairline).frame(height: 1)
    }
  }

  private func setModelState(_ state: TLModelDownloadState, id: String) {
    guard let index = models.firstIndex(where: { $0.id == id }) else { return }
    models[index].state = state
  }

  private func setSupportState(_ state: TLModelDownloadState, id: String) {
    guard let index = supportModels.firstIndex(where: { $0.id == id }) else { return }
    supportModels[index].state = state
  }
}

private struct ModelFilterChip: View {
  let title: String
  let clear: () -> Void

  var body: some View {
    Button(action: clear) {
      HStack(spacing: 6) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(TLTheme.chipSurface, in: Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

private struct ModelLibraryFilterMenu: View {
  @Binding var selection: ModelLibraryFilter?

  @State private var presentationID = UUID()
  @State private var anchorFrame: CGRect = .zero
  @State private var hovering = false
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  var body: some View {
    Button {
      toggleMenu()
    } label: {
      Image(systemName: "line.3.horizontal.decrease")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(selection == nil ? .secondary : TLTheme.accentBlue)
        .frame(width: 28, height: 28)
        .background(
          selection == nil
            ? Color.primary.opacity(hovering ? 0.08 : 0.0)
            : TLTheme.accentBlue.opacity(0.16),
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
      spacing: 6,
      estimatedSize: CGSize(width: 178, height: 202),
      blocksBackground: true
    ) {
      ModelLibraryFilterPanel(selection: $selection)
    }
  }
}

private struct ModelLibraryFilterPanel: View {
  @Binding var selection: ModelLibraryFilter?

  var body: some View {
    VStack(spacing: 1) {
      ForEach(ModelLibraryFilter.allCases, id: \.self) { filter in
        ModelLibraryFilterRow(
          title: filter.label,
          isSelected: selection == filter
        ) {
          selection = selection == filter ? nil : filter
        }
      }
    }
    .padding(6)
    .frame(width: 178)
    .background(tlPopoverSurface, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
    )
  }
}

private struct ModelLibraryFilterRow: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        ZStack {
          Circle()
            .strokeBorder(isSelected ? TLTheme.accentBlue : Color.secondary.opacity(0.45), lineWidth: 1)
            .background(
              Circle().fill(isSelected ? TLTheme.accentBlue : Color.clear)
            )
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.white)
          }
        }
        .frame(width: 16, height: 16)

        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
        Spacer()
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(hovering ? TLTheme.hoverFill : Color.clear)
      )
      .contentShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct ModelInventoryRow<Subtitle: View>: View {
  let provider: TLProvider
  var sizeText: String?
  let state: TLModelDownloadState
  let startDownload: () -> Void
  let cancelDownload: () -> Void
  let delete: () -> Void
  let title: String
  @ViewBuilder var subtitle: Subtitle
  @State private var hovering = false

  init(
    provider: TLProvider,
    title: String,
    sizeText: String? = nil,
    state: TLModelDownloadState,
    startDownload: @escaping () -> Void,
    cancelDownload: @escaping () -> Void,
    delete: @escaping () -> Void,
    @ViewBuilder subtitle: () -> Subtitle
  ) {
    self.provider = provider
    self.title = title
    self.sizeText = sizeText
    self.state = state
    self.startDownload = startDownload
    self.cancelDownload = cancelDownload
    self.delete = delete
    self.subtitle = subtitle()
  }

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      TLProviderLogo(provider: provider)

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        subtitle
      }

      Spacer(minLength: 12)

      if let sizeText {
        Text(sizeText)
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
          .frame(width: 54, alignment: .trailing)
      }

      ModelDownloadControl(
        state: state,
        hovering: hovering,
        startDownload: startDownload,
        cancelDownload: cancelDownload,
        delete: delete
      )
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(hovering ? Color.primary.opacity(0.03) : .clear)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
}

struct ModelDownloadControl: View {
  let state: TLModelDownloadState
  var hovering = false
  var startDownload: () -> Void = {}
  var cancelDownload: () -> Void = {}
  var delete: () -> Void = {}

  var body: some View {
    switch state {
    case .downloaded:
      Button(action: delete) {
        Image(systemName: "trash")
          .font(.system(size: 11))
          .foregroundStyle(hovering ? Color.red.opacity(0.9) : Color.secondary.opacity(0.7))
          .frame(width: 22, height: 22)
          .background(.primary.opacity(hovering ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 5))
      }
      .buttonStyle(.plain)
      .help("Delete model")
    case .downloading(let progress):
      Button(action: cancelDownload) {
        ZStack {
          if hovering {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 16))
              .foregroundStyle(.secondary)
          } else {
            ProgressRing(progress: progress)
            Text(progress.formatted(.percent.precision(.fractionLength(0))))
              .font(.system(size: 6, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
      .help(hovering ? "Cancel download" : "Downloading…")
    case .notDownloaded:
      Button(action: startDownload) {
        Image(systemName: "arrow.down.circle")
          .font(.system(size: 15))
          .foregroundStyle(TLTheme.accentBlue)
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
      .help("Download")
    case .cloud:
      Image(systemName: "cloud")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)
        .help("Cloud model")
    }
  }
}

private struct MetricDots: View {
  let label: String
  let filled: Int
  var total = 5

  private var labelWidth: CGFloat {
    switch label {
    case "Intelligence":
      return 66
    case "Accuracy":
      return 54
    default:
      return 38
    }
  }

  var body: some View {
    HStack(spacing: 5) {
      Text(label)
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: labelWidth, alignment: .leading)
      HStack(spacing: 2.5) {
        ForEach(0..<total, id: \.self) { index in
          Circle()
            .fill(index < filled ? Color.secondary.opacity(0.95) : Color.secondary.opacity(0.24))
            .frame(width: 4.5, height: 4.5)
        }
      }
    }
  }
}

private struct ProgressRing: View {
  let progress: Double

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.25), lineWidth: 2)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(TLTheme.accentBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .frame(width: 18, height: 18)
  }
}

private extension PrototypeModelsPane {
  static func makeModels() -> [LibraryModel] {
    [
      LibraryModel(
        id: "parakeet-v3",
        name: "Parakeet TDT v3",
        provider: .fluidAudio,
        section: .localASR,
        note: "25 languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 5,
        speed: 5,
        size: "650 MB",
        sizeMB: 650,
        state: .downloaded,
        favorite: true
      ),
      LibraryModel(
        id: "parakeet-eou-160",
        name: "Parakeet EOU 160 ms",
        provider: .fluidAudio,
        section: .localASR,
        note: "English",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 4,
        speed: 5,
        size: "200 MB",
        sizeMB: 200,
        state: .downloaded
      ),
      LibraryModel(
        id: "parakeet-110m",
        name: "Parakeet TDT-CTC 110M",
        provider: .fluidAudio,
        section: .localASR,
        note: "English",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 4,
        speed: 5,
        size: "350 MB",
        sizeMB: 350,
        state: .downloaded
      ),
      LibraryModel(
        id: "cohere-transcribe",
        name: "Cohere Transcribe",
        provider: .cohere,
        section: .localASR,
        note: "14 languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 5,
        speed: 3,
        size: "2.2 GB",
        sizeMB: 2200,
        state: .downloading(0.31)
      ),
      LibraryModel(
        id: "nemotron-multilingual-2240",
        name: "Nemotron Multilingual 2240 ms",
        provider: .fluidAudio,
        section: .localASR,
        note: "8 languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 5,
        speed: 3,
        size: "1.4 GB",
        sizeMB: 1400,
        state: .notDownloaded
      ),
      LibraryModel(
        id: "deepgram-nova-3",
        name: "Deepgram Nova 3",
        provider: .deepgram,
        section: .cloudASR,
        note: "Multilingual",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 5,
        speed: 5,
        state: .cloud,
        favorite: true
      ),
      LibraryModel(
        id: "scribe-v2",
        name: "Scribe v2",
        provider: .elevenLabs,
        section: .cloudASR,
        note: "90+ languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 5,
        speed: 4,
        state: .cloud
      ),
      LibraryModel(
        id: "scribe-v2-realtime",
        name: "Scribe v2 Realtime",
        provider: .elevenLabs,
        section: .cloudASR,
        note: "90+ languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 4,
        speed: 5,
        state: .cloud
      ),
      LibraryModel(
        id: "voxtral-mini",
        name: "Voxtral Mini",
        provider: .mistral,
        section: .cloudASR,
        note: "13 languages",
        primaryMetricLabel: "Accuracy",
        primaryMetric: 4,
        speed: 4,
        state: .cloud
      ),
      LibraryModel(
        id: "claude-sonnet",
        name: "Claude Sonnet",
        provider: .anthropic,
        section: .cloudText,
        note: "Text",
        primaryMetricLabel: "Intelligence",
        primaryMetric: 5,
        speed: 3,
        state: .cloud
      ),
      LibraryModel(
        id: "gpt-5-mini",
        name: "GPT-5 mini",
        provider: .openAI,
        section: .cloudText,
        note: "Text",
        primaryMetricLabel: "Intelligence",
        primaryMetric: 3,
        speed: 5,
        state: .cloud,
        favorite: true
      ),
      LibraryModel(
        id: "mistral-text",
        name: "Mistral Text",
        provider: .mistral,
        section: .cloudText,
        note: "Text",
        primaryMetricLabel: "Intelligence",
        primaryMetric: 3,
        speed: 4,
        state: .cloud
      ),
    ]
  }

  static func makeSupportModels() -> [SupportModel] {
    [
      SupportModel(
        id: "silero-vad",
        name: "Silero VAD",
        provider: .fluidAudio,
        usedBy: "Silence removal",
        size: "5 MB",
        sizeMB: 5,
        state: .notDownloaded
      ),
      SupportModel(
        id: "sortformer",
        name: "Sortformer",
        provider: .fluidAudio,
        usedBy: "Speaker recognition",
        size: "300 MB",
        sizeMB: 300,
        state: .notDownloaded
      ),
      SupportModel(
        id: "ls-eend-ami",
        name: "LS-EEND AMI",
        provider: .fluidAudio,
        usedBy: "Speaker recognition",
        size: "120 MB",
        sizeMB: 120,
        state: .notDownloaded
      ),
      SupportModel(
        id: "keyword-spotting",
        name: "Custom Vocabulary / Keyword Spotting",
        provider: .fluidAudio,
        usedBy: "Hot Mic voice commands",
        size: "120 MB",
        sizeMB: 120,
        state: .notDownloaded
      ),
    ]
  }
}

#Preview("Model library") {
  TLFloatingHost {
    PrototypeModelsPane()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
