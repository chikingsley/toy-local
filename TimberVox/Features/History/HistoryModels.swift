import TimberVoxCore
import SwiftUI

private enum HistoryModelMetrics {
  static let generatedTitleLimit = 52
  static let visibleAppFilterLimit = 5
}

enum HistoryScope: Sendable, Equatable {
  case dictations
  case transcriptions
}

enum HistoryTextView: String, CaseIterable, Identifiable {
  case raw = "Raw"
  case processed = "Processed"

  var id: String { rawValue }
}

enum HistoryAppTint: Hashable, Sendable {
  case blue
  case cyan
  case yellow
  case indigo
  case orange
  case gray

  var color: Color {
    switch self {
    case .blue: .blue
    case .cyan: .cyan
    case .yellow: .yellow
    case .indigo: .indigo
    case .orange: .orange
    case .gray: .gray
    }
  }
}

struct HistoryApp: Identifiable, Hashable, Sendable {
  let id: String
  let rawValue: String
  let icon: String
  let tint: HistoryAppTint

  static let xcode = HistoryApp(id: "com.apple.dt.Xcode", rawValue: "Xcode", icon: "hammer.fill", tint: .blue)
  static let mail = HistoryApp(id: "com.apple.mail", rawValue: "Mail", icon: "envelope.fill", tint: .cyan)
  static let notes = HistoryApp(id: "com.apple.Notes", rawValue: "Notes", icon: "note.text", tint: .yellow)
  static let zoom = HistoryApp(id: "us.zoom.xos", rawValue: "Zoom", icon: "video.fill", tint: .indigo)
  static let safari = HistoryApp(id: "com.apple.Safari", rawValue: "Safari", icon: "safari.fill", tint: .blue)
  static let finder = HistoryApp(id: "com.apple.finder", rawValue: "Finder", icon: "folder.fill", tint: .orange)

  static func from(bundleID: String?, name: String?) -> HistoryApp {
    let normalizedBundleID = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowerBundleID = normalizedBundleID?.lowercased() ?? ""
    let lowerName = normalizedName?.lowercased() ?? ""

    if lowerBundleID == "com.apple.dt.xcode" || lowerName == "xcode" { return .xcode }
    if lowerBundleID == "com.apple.mail" || lowerName == "mail" { return .mail }
    if lowerBundleID == "com.apple.notes" || lowerName == "notes" { return .notes }
    if lowerBundleID == "us.zoom.xos" || lowerName.contains("zoom") { return .zoom }
    if lowerBundleID == "com.apple.safari" || lowerName == "safari" { return .safari }
    if lowerBundleID == "com.apple.finder" || lowerName == "finder" { return .finder }

    let fallbackName =
      normalizedName.nonEmpty
      ?? normalizedBundleID?.split(separator: ".").last.map { String($0).capitalized }
      ?? "Unknown app"
    return HistoryApp(
      id: normalizedBundleID.nonEmpty ?? fallbackName.lowercased(),
      rawValue: fallbackName,
      icon: "app.fill",
      tint: .gray
    )
  }
}

struct HistoryItem: Identifiable, Equatable {
  let id: String
  let scope: HistoryScope
  let app: HistoryApp
  let title: String
  let preview: String
  let rawText: String
  let processedText: String
  let date: Date
  let duration: String
  let durationSeconds: TimeInterval
  let mode: String
  let speakers: Int?
  let audioPath: String?

  init(record: TranscriptRecord) {
    let processed = record.finalText
    let raw = record.rawText
    let previewText = processed.nonEmpty ?? raw.nonEmpty ?? "No transcript text."
    self.id = record.id
    self.scope = record.sourceAppBundleID == nil && record.sourceAppName == nil ? .transcriptions : .dictations
    self.app = HistoryApp.from(bundleID: record.sourceAppBundleID, name: record.sourceAppName)
    self.title = record.title.nonEmpty ?? Self.generatedTitle(from: processed.nonEmpty ?? raw)
    self.preview = previewText
    self.rawText = raw
    self.processedText = processed
    self.date = record.createdAt
    self.duration = Self.formatDuration(record.duration)
    self.durationSeconds = record.duration
    self.mode = record.modeName.nonEmpty ?? "Default"
    self.speakers = nil
    self.audioPath = record.audioPath.nonEmpty
  }

  var dayLabel: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(.dateTime.month(.abbreviated).day())
  }

  var timeLabel: String {
    date.formatted(date: .omitted, time: .shortened)
  }

  var dateLabel: String {
    date.formatted(date: .abbreviated, time: .omitted)
  }

  var audioURL: URL? {
    guard let audioPath else { return nil }
    return URL(fileURLWithPath: audioPath)
  }

  func text(for textView: HistoryTextView) -> String {
    switch textView {
    case .raw:
      rawText.nonEmpty ?? "No raw transcript text."
    case .processed:
      processedText.nonEmpty ?? "No processed transcript text."
    }
  }

  static func generatedTitle(from text: String) -> String {
    let compacted = text.split { $0.isWhitespace || $0.isNewline }.joined(separator: " ")
    guard !compacted.isEmpty else { return "Untitled recording" }
    guard compacted.count > HistoryModelMetrics.generatedTitleLimit else { return compacted }
    let end = compacted.index(compacted.startIndex, offsetBy: HistoryModelMetrics.generatedTitleLimit)
    return String(compacted[..<end]) + "..."
  }

  static func formatDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded()))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
  }
}

enum HistoryDayFilter {
  static func options(for items: [HistoryItem]) -> [TLMenuOption<String?>] {
    let labels = orderedDayLabels(for: items)
    return [TLMenuOption(value: String?.none, label: "Any day", systemImage: "calendar")]
      + labels.map { TLMenuOption(value: $0, label: $0, systemImage: "calendar") }
  }

  static func orderedDayLabels(for items: [HistoryItem]) -> [String] {
    var seen = Set<String>()
    return items.sorted { $0.date > $1.date }.compactMap { item in
      seen.insert(item.dayLabel).inserted ? item.dayLabel : nil
    }
  }
}

struct HistoryAppFilter: Hashable, Sendable {
  let id: String
  let label: String
  let systemImage: String
  let matchedAppIDs: Set<String>?

  static let all = HistoryAppFilter(
    id: "all",
    label: "Apps",
    systemImage: "square.grid.2x2",
    matchedAppIDs: nil
  )

  func matches(_ app: HistoryApp) -> Bool {
    guard let matchedAppIDs else { return true }
    return matchedAppIDs.contains(app.id)
  }

  static func options(for items: [HistoryItem]) -> [TLMenuOption<HistoryAppFilter>] {
    let rankedApps = Dictionary(grouping: items, by: \.app.id).values
      .compactMap { group -> (app: HistoryApp, count: Int)? in
        guard let first = group.first else { return nil }
        return (first.app, group.count)
      }
      .sorted {
        if $0.count == $1.count {
          return $0.app.rawValue < $1.app.rawValue
        }
        return $0.count > $1.count
      }

    let visibleApps = rankedApps.prefix(HistoryModelMetrics.visibleAppFilterLimit).map(\.app)
    let overflowApps = rankedApps.dropFirst(HistoryModelMetrics.visibleAppFilterLimit).map(\.app)
    var filters =
      [all]
      + visibleApps.map { app in
        HistoryAppFilter(
          id: app.id,
          label: app.rawValue,
          systemImage: app.icon,
          matchedAppIDs: [app.id]
        )
      }
    if !overflowApps.isEmpty {
      filters.append(
        HistoryAppFilter(
          id: "other",
          label: "Other apps",
          systemImage: "square.stack.3d.up",
          matchedAppIDs: Set(overflowApps.map(\.id))
        )
      )
    }
    return filters.map { TLMenuOption(value: $0, label: $0.label, systemImage: $0.systemImage) }
  }
}

private extension Optional where Wrapped == String {
  var nonEmpty: String? {
    guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}

private extension String {
  var nonEmpty: String? {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}
