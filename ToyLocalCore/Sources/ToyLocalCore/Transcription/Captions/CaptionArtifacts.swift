import Foundation

public extension CaptionRenderer {
  static func buildArtifacts(
    _ document: CaptionDocument,
    formats: Set<CaptionArtifactFormat> = Set(CaptionArtifactFormat.allCases),
    options: CaptionRenderOptions = CaptionRenderOptions()
  ) throws -> [CaptionArtifact] {
    try formats
      .sorted { $0.rawValue < $1.rawValue }
      .flatMap { format in
        try artifacts(for: format, document: document, options: options)
      }
  }
}

private let textVariants: [(name: String, includeTimestamps: Bool, includeSpeakers: Bool)] = [
  ("plain", false, false),
  ("speakers", false, true),
  ("timestamps", true, false),
  ("timestamps-speakers", true, true),
]

private let timedVariants: [(name: String, includeSpeakers: Bool)] = [
  ("plain", false),
  ("speakers", true),
]

private func artifacts(
  for format: CaptionArtifactFormat,
  document: CaptionDocument,
  options: CaptionRenderOptions
) throws -> [CaptionArtifact] {
  switch format {
  case .srt:
    try requireTiming(document)
    return try timedVariants.map { variant in
      textArtifact(
        name: "transcript.\(variant.name).srt",
        format: .srt,
        body: try CaptionRenderer.renderSRT(document, options: options.withSpeakers(variant.includeSpeakers))
      )
    }
  case .vtt:
    try requireTiming(document)
    return try timedVariants.map { variant in
      textArtifact(
        name: "transcript.\(variant.name).vtt",
        format: .vtt,
        body: try CaptionRenderer.renderWebVTT(
          document,
          includeCueIDs: true,
          options: options.withSpeakers(variant.includeSpeakers)
        )
      )
    }
  case .docx, .html, .json, .md, .pdf, .txt:
    return try textVariants.map { variant in
      try textVariantArtifact(format: format, variant: variant, document: document)
    }
  }
}

private func textVariantArtifact(
  format: CaptionArtifactFormat,
  variant: (name: String, includeTimestamps: Bool, includeSpeakers: Bool),
  document: CaptionDocument
) throws -> CaptionArtifact {
  let name = "transcript.\(variant.name).\(format.rawValue)"
  let options = VariantOptions(
    includeTimestamps: variant.includeTimestamps,
    includeSpeakers: variant.includeSpeakers
  )
  switch format {
  case .html, .json, .md, .txt:
    return textArtifact(name: name, format: format, body: try textBody(format, document: document, options: options))
  case .docx, .pdf:
    return binaryArtifact(name: name, format: format, body: try binaryBody(format, document: document, options: options))
  case .srt, .vtt:
    throw CaptionRenderingError.invalidArtifactBody
  }
}

private struct VariantOptions {
  let includeTimestamps: Bool
  let includeSpeakers: Bool
}

private func textBody(
  _ format: CaptionArtifactFormat,
  document: CaptionDocument,
  options: VariantOptions
) throws -> String {
  switch format {
  case .txt:
    return CaptionRenderer.renderText(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .md:
    return CaptionRenderer.renderMarkdown(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .html:
    return CaptionRenderer.renderHTML(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .json:
    return try CaptionRenderer.renderJSON(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .docx, .pdf, .srt, .vtt:
    throw CaptionRenderingError.invalidArtifactBody
  }
}

private func binaryBody(
  _ format: CaptionArtifactFormat,
  document: CaptionDocument,
  options: VariantOptions
) throws -> Data {
  switch format {
  case .pdf:
    return CaptionRenderer.renderPDF(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .docx:
    return CaptionRenderer.renderDOCX(
      document,
      includeTimestamps: options.includeTimestamps,
      includeSpeakers: options.includeSpeakers
    )
  case .html, .json, .md, .srt, .txt, .vtt:
    throw CaptionRenderingError.invalidArtifactBody
  }
}

private func requireTiming(_ document: CaptionDocument) throws {
  guard !document.words.isEmpty || !document.turns.isEmpty else {
    throw CaptionRenderingError.missingTimedTranscript
  }
}

private func textArtifact(name: String, format: CaptionArtifactFormat, body: String) -> CaptionArtifact {
  CaptionArtifact(
    name: name,
    contentType: contentType(format),
    encoding: .utf8,
    data: Data(body.utf8)
  )
}

private func binaryArtifact(name: String, format: CaptionArtifactFormat, body: Data) -> CaptionArtifact {
  CaptionArtifact(
    name: name,
    contentType: contentType(format),
    encoding: .base64,
    data: body
  )
}

private func contentType(_ format: CaptionArtifactFormat) -> String {
  switch format {
  case .docx:
    return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  case .html:
    return "text/html; charset=utf-8"
  case .json:
    return "application/json"
  case .md:
    return "text/markdown; charset=utf-8"
  case .pdf:
    return "application/pdf"
  case .srt:
    return "application/x-subrip; charset=utf-8"
  case .txt:
    return "text/plain; charset=utf-8"
  case .vtt:
    return "text/vtt; charset=utf-8"
  }
}

private extension CaptionRenderOptions {
  func withSpeakers(_ includeSpeakers: Bool) -> CaptionRenderOptions {
    CaptionRenderOptions(
      includeSpeakers: includeSpeakers,
      maxCharsPerLine: maxCharsPerLine,
      maxLinesPerCue: maxLinesPerCue,
      maxSecondsPerCue: maxSecondsPerCue,
      strategy: strategy
    )
  }
}
