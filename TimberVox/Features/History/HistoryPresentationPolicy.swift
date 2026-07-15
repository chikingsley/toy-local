import Foundation

enum HistoryTranscriptViewMode: String, CaseIterable {
  case raw
  case segmented
  case processed

  var label: String { rawValue.capitalized }
}

enum HistoryPresentationPolicy {
  static let pageSize = 100
  static let inlineCharacterLimit = 1_200

  static func shouldOpenInDetail(_ record: TranscriptRecord) -> Bool {
    record.historyHeadline.count > inlineCharacterLimit
  }

  static func dayLabel(_ day: Date) -> String {
    if Calendar.current.isDateInToday(day) { return "Today" }
    if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(date: .abbreviated, time: .omitted)
  }
}

extension TranscriptRecord {
  var historyHeadline: String {
    guard status != .succeeded else { return text }
    return errorMessage ?? (status == .noSpeech ? "No voice was detected." : "Dictation failed.")
  }

  var hasTranscriptText: Bool {
    !rawTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var rawTranscriptText: String {
    rawText ?? artifact?.displayText ?? text
  }

  var timedWords: [TranscriptionTimedText] {
    artifact?.content.words.items ?? []
  }

  var timedSegments: [TranscriptionTimedText] {
    if let speakerTurns = artifact?.content.speakerTurns.items, !speakerTurns.isEmpty {
      return speakerTurns
    }
    if let segments = artifact?.content.segments.items, !segments.isEmpty {
      return segments
    }
    return []
  }

  var hasTimedTranscript: Bool {
    !timedWords.isEmpty || !timedSegments.isEmpty
  }

  var transcriptViewerComposition: SCTranscriptComposition {
    if let cacheKey = payloadCacheKey,
      let cached = TranscriptCompositionCache.shared.composition(forKey: cacheKey)
    {
      return cached
    }
    let composition = builtTranscriptViewerComposition
    if let cacheKey = payloadCacheKey {
      TranscriptCompositionCache.shared.store(composition, forKey: cacheKey)
    }
    return composition
  }

  private var builtTranscriptViewerComposition: SCTranscriptComposition {
    let timedItems = timedWords.isEmpty ? timedSegments : timedWords
    var segments: [SCTranscriptSegment] = []
    var words: [SCTranscriptWord] = []

    for timedItem in timedItems {
      let text = timedItem.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { continue }
      if !words.isEmpty, Self.transcriptViewerNeedsLeadingSpace(text) {
        segments.append(SCTranscriptSegment.gap(.init(segmentIndex: segments.count, text: " ")))
      }
      let word = SCTranscriptWord(
        segmentIndex: segments.count,
        wordIndex: words.count,
        text: text,
        startTime: timedItem.startSeconds,
        endTime: timedItem.endSeconds
      )
      segments.append(.word(word))
      words.append(word)
    }
    return SCTranscriptComposition(segments: segments, words: words)
  }

  var hasProcessedTranscript: Bool {
    status == .succeeded
      && (rawText != nil || transformPreset != nil || transformationJSON != nil)
  }

  var availableTranscriptModes: [HistoryTranscriptViewMode] {
    var modes: [HistoryTranscriptViewMode] = [.raw]
    if hasTimedTranscript { modes.append(.segmented) }
    if hasProcessedTranscript { modes.append(.processed) }
    return modes
  }

  var defaultTranscriptMode: HistoryTranscriptViewMode {
    guard status == .succeeded else { return .raw }
    return hasProcessedTranscript ? .processed : .raw
  }

  func transcriptText(for mode: HistoryTranscriptViewMode) -> String {
    switch mode {
    case .raw, .segmented: rawTranscriptText
    case .processed: text
    }
  }

  private static func transcriptViewerNeedsLeadingSpace(_ text: String) -> Bool {
    guard let scalar = text.first?.unicodeScalars.first else { return false }
    return !CharacterSet.punctuationCharacters.contains(scalar)
  }
}

struct HistoryReloadKey: Equatable {
  let query: String
  let pageLimit: Int
}

/// Building the viewer composition walks every timed word, and view bodies
/// recompute it on every render — memoize per row alongside the artifact cache.
private final class TranscriptCompositionCache: @unchecked Sendable {
  static let shared = TranscriptCompositionCache()

  private final class Entry {
    let composition: SCTranscriptComposition

    init(_ composition: SCTranscriptComposition) {
      self.composition = composition
    }
  }

  private let cache: NSCache<NSString, Entry> = {
    let cache = NSCache<NSString, Entry>()
    cache.countLimit = 16
    return cache
  }()

  func composition(forKey key: String) -> SCTranscriptComposition? {
    cache.object(forKey: key as NSString)?.composition
  }

  func store(_ composition: SCTranscriptComposition, forKey key: String) {
    cache.setObject(Entry(composition), forKey: key as NSString)
  }
}
