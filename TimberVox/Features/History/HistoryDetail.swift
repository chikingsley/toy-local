import SwiftUI

private enum HistoryDetailMetrics {
  static let sheetWidth: CGFloat = 330
  static let playbackHeight: CGFloat = 48
  static let playbackButtonSize: CGFloat = 28
  static let playbackTimeWidth: CGFloat = 42
}

struct HistoryDetail: View {
  let item: HistoryItem
  let title: String
  let isPlaying: Bool
  let playbackPosition: TimeInterval
  let playbackDuration: TimeInterval
  let togglePlayback: () -> Void
  let seek: (TimeInterval) -> Void
  @State private var selectedTextView: HistoryTextView = .processed

  private var activeText: String {
    item.text(for: selectedTextView)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      TLScrollArea(
        contentPadding: EdgeInsets(top: 18, leading: 18, bottom: 46, trailing: 18),
        spacing: 18
      ) {
        HStack(alignment: .top, spacing: 14) {
          Text(activeText)
            .font(.system(size: 14, weight: .semibold))
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .mask(
        LinearGradient(
          stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.86),
            .init(color: .clear, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )

      HistoryPlaybackBar(
        duration: item.duration,
        hasAudio: item.audioURL != nil,
        isPlaying: isPlaying,
        position: playbackPosition,
        playbackDuration: playbackDuration,
        togglePlayback: togglePlayback,
        seek: seek
      )

      HStack {
        Text("\(item.app.rawValue) - \(wordCount) words")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
        Picker("", selection: $selectedTextView) {
          ForEach(HistoryTextView.allCases) { textView in
            Text(textView.rawValue).tag(textView)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 174)
      }
      .padding(.top, 8)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(.primary.opacity(0.1))
          .frame(height: 1)
      }
    }
    .padding(HistoryMetrics.panePadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var wordCount: Int {
    activeText.split { $0.isWhitespace || $0.isNewline }.count
  }
}

struct HistoryRecordingDetailsSheet: View {
  let item: HistoryItem
  let title: String
  let close: () -> Void
  let openFileLocation: () -> Void
  let delete: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      sheetHeader

      VStack(alignment: .leading, spacing: 14) {
        Text("\(item.dateLabel) at \(item.timeLabel)")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)

        summaryCard
        recordingSection

        Spacer()

        Button {
          openFileLocation()
        } label: {
          Label("Open File Location", systemImage: "folder")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .frame(height: 34)
        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .disabled(item.audioURL == nil)

        Button(role: .destructive) {
          delete()
        } label: {
          Label("Delete Recording", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.red.opacity(0.9))
        .frame(height: 34)
        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
      }
      .padding(16)
    }
    .frame(width: HistoryDetailMetrics.sheetWidth)
    .frame(maxHeight: .infinity)
    .background(TLTheme.windowBackground)
    .overlay(alignment: .leading) {
      Rectangle().fill(.primary.opacity(0.1)).frame(width: 1)
    }
  }

  private var sheetHeader: some View {
    HStack {
      Button(action: close) {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .bold))
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      Spacer()
      Text("Recording Details")
        .font(.system(size: 13, weight: .semibold))
      Spacer()
      Color.clear.frame(width: 32, height: 32)
    }
    .padding(.horizontal, 12)
    .frame(height: TLTheme.headerHeight)
    .overlay(alignment: .bottom) {
      Rectangle().fill(.primary.opacity(0.1)).frame(height: 1)
    }
  }

  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "sparkles")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(HistoryStyle.accentGreen)
          .frame(width: 36, height: 36)
          .background(HistoryStyle.accentGreen.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 2) {
          Text(item.mode)
            .font(.system(size: 13, weight: .semibold))
          Text(title)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
      }

      HStack(spacing: 8) {
        TLKeyChip(item.duration)
        TLKeyChip("\(wordCount) words")
      }
    }
    .padding(12)
    .historyBorderedCard()
  }

  private var recordingSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Recording")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)

      VStack(spacing: 0) {
        recordingRow(icon: item.app.icon, label: "Source app", value: item.app.rawValue)
        TLDivider(leadingInset: 50)
        recordingRow(icon: "sparkles", label: "Mode", value: item.mode)
        TLDivider(leadingInset: 50)
        recordingRow(icon: "waveform", label: "Audio", value: item.audioURL?.lastPathComponent ?? "Not saved")
      }
      .historyBorderedCard()
    }
  }

  private var wordCount: Int {
    item.processedText.split { $0.isWhitespace || $0.isNewline }.count
  }

  private func recordingRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 28, height: 28)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
      Spacer()
      Text(value)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
  }
}

struct HistoryPlaybackBar: View {
  let duration: String
  let hasAudio: Bool
  let isPlaying: Bool
  let position: TimeInterval
  let playbackDuration: TimeInterval
  let togglePlayback: () -> Void
  let seek: (TimeInterval) -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: togglePlayback) {
        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
          .font(.system(size: 12, weight: .bold))
          .frame(width: HistoryDetailMetrics.playbackButtonSize, height: HistoryDetailMetrics.playbackButtonSize)
          .background(.primary.opacity(0.09), in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(!hasAudio)
      .opacity(hasAudio ? 1 : 0.45)

      Text(HistoryItem.formatDuration(position))
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 32, alignment: .leading)

      Slider(
        value: Binding(get: { position }, set: { seek($0) }),
        in: 0...max(playbackDuration, 0.01)
      )
      .tint(HistoryStyle.playbackBlue)
      .controlSize(.small)
      .disabled(!isPlaying)

      Text(duration)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: HistoryDetailMetrics.playbackTimeWidth, alignment: .trailing)
    }
    .padding(.horizontal, 12)
    .frame(height: HistoryDetailMetrics.playbackHeight)
    .historyBorderedCard()
  }
}
