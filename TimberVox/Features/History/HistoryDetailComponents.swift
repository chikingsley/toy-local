import AppKit
import SwiftUI

struct HistoryDetailsSheet: View {
  let record: TranscriptRecord
  let modelDisplayName: String
  let onClose: () -> Void

  var body: some View {
    SCSheetContent(showsCloseButton: false) {
      HStack {
        Button(action: onClose) {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.sc(.ghost, size: .iconSM))
        .accessibilityLabel("Close recording information")

        SCSheetHeader {
          SCSheetTitle("Recording information")
          SCSheetDescription(
            record.createdAt.formatted(date: .abbreviated, time: .shortened)
          )
        }
      }

      ScrollView {
        VStack(spacing: AppSpacing.md) {
          SCCard(size: .sm) {
            SCCardContent {
              SCItem(
                record.modeName ?? "Dictation",
                leading: {
                  Image(systemName: "mic")
                },
                trailing: {
                  HistorySourceApplicationIcon(record: record, size: 24)
                }
              )
            }
          }

          HistoryMetadataSection(title: "Recording", rows: recordingRows)
          if !outcomeRows.isEmpty {
            HistoryMetadataSection(title: "Outcome", rows: outcomeRows)
          }
          HistoryMetadataSection(title: "Transcription", rows: transcriptionRows)

          if !contextRows.isEmpty {
            HistoryMetadataSection(title: "Captured context", rows: contextRows)
          }

          if !performanceRows.isEmpty {
            HistoryMetadataSection(title: "Performance", rows: performanceRows)
          }

          if !artifactRows.isEmpty {
            HistoryMetadataSection(title: "Artifact", rows: artifactRows)
          }

          if !processingRows.isEmpty {
            HistoryMetadataSection(title: "AI processing", rows: processingRows)
          }

          if let audioURL {
            Button {
              NSWorkspace.shared.activateFileViewerSelecting([audioURL])
            } label: {
              Label("Show recording in Finder", systemImage: "folder")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.sc())
          }

          ShareLink(
            item: TimberVoxHistoryDiagnosticTransfer(
              file: TimberVoxHistoryDiagnosticFile(record: record)
            ),
            subject: Text("TimberVox History diagnostic"),
            message: Text("Diagnostic data exported from TimberVox History."),
            preview: SharePreview("TimberVox History diagnostic")
          ) {
            Label("Export diagnostic JSON", systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.sc(.secondary))

          Text("Includes the transcript, captured context, transcription artifact, and AI processing details.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, AppSpacing.md)
      }
    }
  }

  private var recordingRows: [HistoryMetadataValue] {
    var rows = [
      HistoryMetadataValue(
        icon: "waveform",
        label: "Duration",
        value: HomePane.formatDuration(record.durationSeconds)
      ),
      HistoryMetadataValue(
        icon: "text.word.spacing",
        label: "Words",
        value: "\(record.rawTranscriptText.split(whereSeparator: \.isWhitespace).count)"
      ),
    ]
    if let source = record.sourceApplicationName {
      rows.append(HistoryMetadataValue(icon: "app", label: "Source app", value: source))
    }
    return rows
  }

  private var outcomeRows: [HistoryMetadataValue] {
    guard record.status != .succeeded else { return [] }
    var rows = [
      HistoryMetadataValue(
        icon: record.status == .noSpeech ? "waveform.slash" : "exclamationmark.triangle",
        label: "Status",
        value: record.status == .noSpeech ? "No voice detected" : "Failed"
      )
    ]
    if let errorCode = record.errorCode {
      rows.append(HistoryMetadataValue(icon: "number", label: "Error code", value: errorCode))
    }
    if let errorMessage = record.errorMessage {
      rows.append(HistoryMetadataValue(icon: "text.bubble", label: "Error", value: errorMessage))
    }
    return rows
  }

  private var transcriptionRows: [HistoryMetadataValue] {
    let provenance = record.artifact?.provenance
    var rows = [
      HistoryMetadataValue(icon: "waveform", label: "Model", value: modelDisplayName)
    ]
    if let provider = provenance?.provider ?? record.provider {
      rows.append(HistoryMetadataValue(icon: "building.2", label: "Provider", value: provider))
    }
    if let provenance {
      rows.append(
        HistoryMetadataValue(
          icon: "arrow.left.arrow.right",
          label: "Execution",
          value: "\(provenance.executor.rawValue.capitalized) · \(provenance.transport.rawValue.capitalized)"
        )
      )
    }
    if let language = record.language {
      rows.append(HistoryMetadataValue(icon: "globe", label: "Language", value: language))
    }
    return rows
  }

  private var performanceRows: [HistoryMetadataValue] {
    guard let metrics = record.artifact?.metrics else {
      return record.wallLatencyMs.map {
        [HistoryMetadataValue(icon: "clock", label: "Transcription time", value: milliseconds($0))]
      } ?? []
    }
    var rows: [HistoryMetadataValue] = []
    append(metrics.providerLatencyMs, to: &rows, icon: "timer", label: "Provider latency", formatter: milliseconds)
    append(metrics.wallLatencyMs, to: &rows, icon: "clock", label: "Transcription time", formatter: milliseconds)
    append(metrics.firstResultLatencyMs, to: &rows, icon: "bolt", label: "Time to first text", formatter: milliseconds)
    append(metrics.realtimeSpeedFactor, to: &rows, icon: "speedometer", label: "Speed (RTFx)") {
      $0.formatted(.number.precision(.fractionLength(1))) + "× realtime"
    }
    append(metrics.tokensPerSecond, to: &rows, icon: "gauge.with.dots.needle.67percent", label: "Tokens per second") {
      $0.formatted(.number.precision(.fractionLength(1)))
    }
    return rows
  }

  private var artifactRows: [HistoryMetadataValue] {
    guard let artifact = record.artifact else { return [] }
    let content = artifact.content
    var rows = [
      collectionRow("Words", icon: "text.word.spacing", collection: content.words),
      collectionRow("Segments", icon: "list.number", collection: content.segments),
      collectionRow("Speaker turns", icon: "person.2", collection: content.speakerTurns),
      collectionRow("Tokens", icon: "curlybraces", collection: content.tokens),
      collectionRow("Audio events", icon: "waveform.badge.plus", collection: content.audioEvents),
    ]
    let scoredWords = content.words.items.filter { $0.scores != nil }.count
    let logProbabilities = content.words.items.filter { $0.scores?.logProbability != nil }.count
    if scoredWords > 0 {
      rows.append(HistoryMetadataValue(icon: "checkmark.seal", label: "Scored words", value: "\(scoredWords)"))
    }
    if logProbabilities > 0 {
      rows.append(HistoryMetadataValue(icon: "function", label: "Log probabilities", value: "\(logProbabilities)"))
    }
    rows.append(
      HistoryMetadataValue(
        icon: "doc.text.magnifyingglass",
        label: "Provider capture",
        value:
          "\(artifact.providerCapture.response.mediaType) · \(artifact.providerCapture.response.payload.count) fields"
      )
    )
    if !artifact.warnings.isEmpty {
      rows.append(
        HistoryMetadataValue(icon: "exclamationmark.triangle", label: "Warnings", value: "\(artifact.warnings.count)"))
    }
    return rows
  }

  private var processingRows: [HistoryMetadataValue] {
    guard record.transformation != nil || record.transformPreset != nil else { return [] }
    let transform = record.transformation
    var rows: [HistoryMetadataValue] = []
    if let preset = record.transformPreset {
      rows.append(HistoryMetadataValue(icon: "sparkles", label: "Preset", value: preset.capitalized))
    }
    if let outcome = transform?.outcome {
      rows.append(HistoryMetadataValue(icon: "cpu", label: "Model", value: outcome.model))
      rows.append(HistoryMetadataValue(icon: "building.2", label: "Provider", value: outcome.provider))
      if let latency = outcome.providerLatencyMs {
        rows.append(HistoryMetadataValue(icon: "timer", label: "Provider latency", value: milliseconds(latency)))
      }
      let usage = outcome.usage
      if let totalTokens = usage.totalTokens {
        rows.append(HistoryMetadataValue(icon: "number", label: "Tokens", value: "\(totalTokens)"))
      }
      if let effectiveSpeed = outcome.performance?.effectiveOutputTokensPerSecond {
        rows.append(
          HistoryMetadataValue(
            icon: "gauge.with.dots.needle.67percent",
            label: "End-to-end speed",
            value: effectiveSpeed.formatted(.number.precision(.fractionLength(1))) + " tok/s"
          )
        )
      }
      if !outcome.warnings.isEmpty {
        rows.append(
          HistoryMetadataValue(
            icon: "exclamationmark.triangle", label: "Warnings", value: "\(outcome.warnings.count)"))
      }
    } else if let model = record.transformModel {
      rows.append(HistoryMetadataValue(icon: "cpu", label: "Model", value: model))
    }
    if let failure = transform?.failure {
      rows.append(HistoryMetadataValue(icon: "xmark.circle", label: "Status", value: "Failed"))
      rows.append(HistoryMetadataValue(icon: "number", label: "Error code", value: failure.code))
      rows.append(HistoryMetadataValue(icon: "text.bubble", label: "Error", value: failure.message))
      rows.append(
        HistoryMetadataValue(
          icon: "arrow.clockwise",
          label: "Retryable",
          value: failure.retryable ? "Yes" : "No"
        )
      )
    }
    if let transform {
      rows.append(
        HistoryMetadataValue(
          icon: "clock",
          label: "Processing time",
          value: milliseconds(transform.wallLatencyMs)
        )
      )
    }
    return rows
  }

  private var audioURL: URL? {
    guard let path = record.audioPath, FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  private func append(
    _ value: Double?,
    to rows: inout [HistoryMetadataValue],
    icon: String,
    label: String,
    formatter: (Double) -> String
  ) {
    guard let value else { return }
    rows.append(HistoryMetadataValue(icon: icon, label: label, value: formatter(value)))
  }

  private func collectionRow<Item: Codable & Equatable & Sendable>(
    _ label: String,
    icon: String,
    collection: TranscriptionCollection<Item>
  ) -> HistoryMetadataValue {
    let availability = collection.availability.rawValue.replacingOccurrences(of: "_", with: " ")
    let source = collection.source.map { " · \($0.rawValue)" } ?? ""
    return HistoryMetadataValue(
      icon: icon,
      label: label,
      value: "\(collection.items.count) · \(availability)\(source)"
    )
  }

  private func milliseconds(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0))) + " ms"
  }

}

struct HistoryMetadataValue: Identifiable {
  let icon: String
  let label: String
  let value: String

  var id: String { "\(label)-\(value)" }
}

private struct HistoryMetadataSection: View {
  let title: String
  let rows: [HistoryMetadataValue]

  var body: some View {
    SCCard(size: .sm) {
      SCCardHeader {
        SCCardTitle(title)
      }
      SCCardContent {
        VStack(spacing: 0) {
          ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            if index > 0 { SCSeparator().padding(.leading, 40) }
            HistoryMetadataRow(row: row)
          }
        }
      }
    }
  }
}

private struct HistoryMetadataRow: View {
  let icon: String
  let label: String
  let value: String
  @Environment(\.theme) private var theme

  init(row: HistoryMetadataValue) {
    icon = row.icon
    label = row.label
    value = row.value
  }

  var body: some View {
    SCItem(
      label,
      leading: {
        Image(systemName: icon)
          .frame(width: 24, height: 24)
      },
      trailing: {
        Text(value)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(theme.mutedForeground)
          .lineLimit(1)
      }
    )
  }
}
