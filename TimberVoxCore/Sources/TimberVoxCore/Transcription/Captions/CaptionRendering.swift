import Foundation

public enum CaptionRenderer {}

public extension CaptionRenderer {
  static func render(
    _ document: CaptionDocument,
    format: CaptionRenderFormat,
    options: CaptionRenderOptions = CaptionRenderOptions()
  ) throws -> String {
    switch format {
    case .html(let includeTimestamps, let includeSpeakers, let title):
      return renderHTML(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers, title: title)
    case .json(let includeTimestamps, let includeSpeakers):
      return try renderJSON(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    case .md(let includeTimestamps, let includeSpeakers, let title):
      return renderMarkdown(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers, title: title)
    case .txt(let includeTimestamps, let includeSpeakers):
      return renderText(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    case .srt:
      return try renderSRT(document, options: options)
    case .vtt(let includeCueIDs):
      return try renderWebVTT(document, includeCueIDs: includeCueIDs, options: options)
    }
  }

  static func renderText(
    _ document: CaptionDocument,
    includeTimestamps: Bool = false,
    includeSpeakers: Bool = false
  ) -> String {
    let blocks = transcriptBlocks(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    guard !blocks.isEmpty else { return "" }
    return
      blocks
      .map { block in
        if let header = block.header {
          return "\(header)\n\(block.text)"
        }
        return block.text
      }
      .joined(separator: "\n\n") + "\n"
  }

  static func renderMarkdown(
    _ document: CaptionDocument,
    includeTimestamps: Bool = false,
    includeSpeakers: Bool = false,
    title: String = "Transcript"
  ) -> String {
    let blocks = transcriptBlocks(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
    guard !blocks.isEmpty else {
      return "# \(title)\n"
    }
    let body =
      blocks
      .map { block in
        if let header = block.header {
          return "**\(sanitizeMarkdownHeader(header))**\n\(block.text)"
        }
        return block.text
      }
      .joined(separator: "\n\n")
    return "# \(title)\n\n\(body)\n"
  }

  static func renderHTML(
    _ document: CaptionDocument,
    includeTimestamps: Bool = false,
    includeSpeakers: Bool = false,
    title: String = "Transcript"
  ) -> String {
    let body = transcriptBlocks(document, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
      .map { block in
        let header = block.header.map { "<h5>\(escapeHTML($0))</h5>\n" } ?? ""
        return "\(header)<p>\(escapeHTML(block.text))</p>"
      }
      .joined(separator: "\n")
    return """
      <!DOCTYPE html>
      <html>
      <head>
      <meta charset="UTF-8">
      <title>\(escapeHTML(title))</title>
      </head>
      <body>
      \(body)
      </body>
      </html>

      """
  }

  static func renderJSON(
    _ document: CaptionDocument,
    includeTimestamps: Bool = true,
    includeSpeakers: Bool = true
  ) throws -> String {
    var body: [String: Any] = [
      "metadata": document.metadata,
      "segments": documentTurns(document).map {
        turnJSON($0, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
      },
      "transcript": document.transcript,
      "words": documentWords(document).map {
        wordJSON($0, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers)
      },
    ]
    if let model = document.model {
      body["model"] = model
    }
    if let provider = document.provider {
      body["provider"] = provider
    }
    let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
    guard let text = String(data: data, encoding: .utf8) else {
      throw CaptionRenderingError.invalidArtifactBody
    }
    return text + "\n"
  }

  static func renderSRT(
    _ document: CaptionDocument,
    options: CaptionRenderOptions = CaptionRenderOptions()
  ) throws -> String {
    let cues = try captionCues(document, options: options)
    return cues.enumerated()
      .map { index, cue in
        var text = cue.text
        if options.includeSpeakers, let speakerID = cue.speakerID {
          text = "\(displaySpeaker(speakerID)): \(text)"
        }
        return "\(index + 1)\n\(captionTime(cue.startTime, separator: ",")) --> \(captionTime(cue.endTime, separator: ","))\n\(text)\n"
      }
      .joined(separator: "\n")
  }

  static func renderWebVTT(
    _ document: CaptionDocument,
    includeCueIDs: Bool = false,
    options: CaptionRenderOptions = CaptionRenderOptions()
  ) throws -> String {
    let cues = try captionCues(document, options: options)
    var lines = ["WEBVTT", ""]
    for (index, cue) in cues.enumerated() {
      if includeCueIDs {
        lines.append("cue-\(index + 1)")
      }
      lines.append("\(captionTime(cue.startTime, separator: ".")) --> \(captionTime(cue.endTime, separator: "."))")
      let escaped = escapeWebVTT(cue.text)
      if options.includeSpeakers, let speakerID = cue.speakerID {
        lines.append("<v \(displaySpeaker(speakerID))>\(escaped)")
      } else {
        lines.append(escaped)
      }
      lines.append("")
    }
    return lines.joined(separator: "\n")
  }
}

extension CaptionRenderer {
  private static func captionCues(
    _ document: CaptionDocument,
    options: CaptionRenderOptions
  ) throws -> [CaptionTurn] {
    let turns = captionTurns(document, options: options)
    guard !turns.isEmpty else {
      throw CaptionRenderingError.missingTimedTranscript
    }
    return turns.flatMap { splitTurn($0, options: options) }
  }

  private static func captionTurns(_ document: CaptionDocument, options: CaptionRenderOptions) -> [CaptionTurn] {
    if options.strategy == .speakerSegments || document.words.isEmpty {
      return documentTurns(document)
    }
    return [
      CaptionTurn(
        text: document.words.map(\.text).joined(separator: " "),
        startTime: document.words[0].startTime,
        endTime: document.words[document.words.count - 1].endTime,
        words: document.words
      )
    ]
  }

  private static func documentTurns(_ document: CaptionDocument) -> [CaptionTurn] {
    if !document.turns.isEmpty {
      return document.turns
    }
    if !document.words.isEmpty {
      return [
        CaptionTurn(
          text: document.words.map(\.text).joined(separator: " "),
          startTime: document.words[0].startTime,
          endTime: document.words[document.words.count - 1].endTime,
          words: document.words
        )
      ]
    }
    return []
  }

  private static func documentWords(_ document: CaptionDocument) -> [CaptionWord] {
    if !document.words.isEmpty {
      return document.words
    }
    return document.turns.flatMap(\.words)
  }

  static func transcriptBlocks(
    _ document: CaptionDocument,
    includeTimestamps: Bool,
    includeSpeakers: Bool
  ) -> [TranscriptBlock] {
    let turns = documentTurns(document)
    guard !turns.isEmpty else {
      let text = document.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? [] : [TranscriptBlock(header: nil, text: text)]
    }
    return turns.map { turn in
      TranscriptBlock(
        header: transcriptHeader(turn, includeTimestamps: includeTimestamps, includeSpeakers: includeSpeakers),
        text: turn.text
      )
    }
  }

  private static func transcriptHeader(
    _ turn: CaptionTurn,
    includeTimestamps: Bool,
    includeSpeakers: Bool
  ) -> String? {
    let timestamp = "\(captionTime(turn.startTime, separator: ",")) --> \(captionTime(turn.endTime, separator: ","))"
    let speaker = turn.speakerID.map(displaySpeaker)
    switch (includeTimestamps, includeSpeakers, speaker) {
    case (true, true, let speaker?):
      return "\(timestamp) [\(speaker)]"
    case (true, _, _):
      return timestamp
    case (false, true, let speaker?):
      return "[\(speaker)]"
    default:
      return nil
    }
  }

  private static func splitTurn(_ turn: CaptionTurn, options: CaptionRenderOptions) -> [CaptionTurn] {
    let words = turn.words.isEmpty ? syntheticWords(for: turn) : turn.words
    guard !words.isEmpty else {
      return []
    }
    var cues: [CaptionTurn] = []
    var active: [CaptionWord] = []

    func flush() {
      guard !active.isEmpty else {
        return
      }
      cues.append(cue(from: active, speakerID: turn.speakerID))
      active.removeAll(keepingCapacity: true)
    }

    for word in words {
      if let previous = active.last, previous.speakerID != word.speakerID {
        flush()
      }
      let candidate = active + [word]
      if !active.isEmpty && !cueFits(candidate, options: options) {
        flush()
        active.append(word)
      } else {
        active = candidate
      }
    }
    flush()
    return cues
  }

  private static func cue(from words: [CaptionWord], speakerID: String?) -> CaptionTurn {
    let start = words[0].startTime
    let end = max(words[words.count - 1].endTime, start + 0.5)
    return CaptionTurn(
      text: cueLines(words).joined(separator: "\n"),
      startTime: start,
      endTime: end,
      speakerID: speakerID ?? CaptionDocument.speakerID(from: words),
      words: words
    )
  }

  private static func syntheticWords(for turn: CaptionTurn) -> [CaptionWord] {
    let tokens = turn.text.split(separator: " ").map(String.init)
    guard !tokens.isEmpty else {
      return []
    }
    let duration = max(turn.endTime - turn.startTime, 0.5)
    let step = duration / Double(tokens.count)
    return tokens.enumerated().map { index, token in
      let start = turn.startTime + (Double(index) * step)
      return CaptionWord(
        text: token,
        startTime: start,
        endTime: start + step,
        speakerID: turn.speakerID
      )
    }
  }

  private static func cueFits(_ words: [CaptionWord], options: CaptionRenderOptions) -> Bool {
    guard let first = words.first, let last = words.last else {
      return true
    }
    return last.endTime - first.startTime <= options.maxSecondsPerCue
      && cueLines(words, maxCharsPerLine: options.maxCharsPerLine).count <= options.maxLinesPerCue
  }

  private static func cueLines(_ words: [CaptionWord], maxCharsPerLine: Int = 42) -> [String] {
    var lines: [String] = []
    var active = ""
    for word in words {
      let next = active.isEmpty ? word.text : "\(active) \(word.text)"
      if !active.isEmpty, next.count > maxCharsPerLine {
        lines.append(active)
        active = word.text
      } else {
        active = next
      }
    }
    if !active.isEmpty {
      lines.append(active)
    }
    return lines
  }

  private static func captionTime(_ seconds: TimeInterval, separator: String) -> String {
    let milliseconds = max(0, Int((seconds * 1_000).rounded()))
    let hours = milliseconds / 3_600_000
    let minutes = (milliseconds % 3_600_000) / 60_000
    let secs = (milliseconds % 60_000) / 1_000
    let ms = milliseconds % 1_000
    return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, separator, ms)
  }

  private static func displaySpeaker(_ speakerID: String) -> String {
    if speakerID.hasPrefix("speaker_") {
      let suffix = speakerID.dropFirst("speaker_".count)
      return suffix.allSatisfy(\.isNumber) ? "Speaker \(suffix)" : String(suffix)
    }
    return speakerID
  }

  private static func escapeWebVTT(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }

  private static func wordJSON(
    _ word: CaptionWord,
    includeTimestamps: Bool,
    includeSpeakers: Bool
  ) -> [String: Any] {
    var body: [String: Any] = ["text": word.text]
    if includeTimestamps {
      body["end"] = word.endTime
      body["start"] = word.startTime
    }
    if includeSpeakers, let speakerID = word.speakerID {
      body["speaker"] = speakerID
    }
    if let confidence = word.confidence {
      body["confidence"] = confidence
    }
    return body
  }

  private static func turnJSON(
    _ turn: CaptionTurn,
    includeTimestamps: Bool,
    includeSpeakers: Bool
  ) -> [String: Any] {
    var body: [String: Any] = ["text": turn.text]
    if includeTimestamps {
      body["end"] = turn.endTime
      body["start"] = turn.startTime
    }
    if includeSpeakers, let speakerID = turn.speakerID {
      body["speaker"] = speakerID
    }
    return body
  }

  private static func sanitizeMarkdownHeader(_ value: String) -> String {
    value.filter { !"*_#`]>".contains($0) }
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

}
