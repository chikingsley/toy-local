import SwiftUI

/// The window indicator — our take on Superwhisper's larger recording
/// surface (docs/archive/superwhisper-onboarding/superwhisper-large-pill.mov):
/// a wider dark panel with a bar-visualizer waveform, live transcript text
/// while realtime recording, and the processed text streaming in while
/// transcribing. Replaces the old "large" pill rendering.
struct RecordingWindowView: View {
  let dictation: DictationController
  let phase: RecordingPillPhase

  private static let width: CGFloat = 430

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(RecordingPillPalette.pillSurface)
        .shadow(color: .black.opacity(0.45), radius: 7, y: 2)

      content
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
    .frame(width: Self.width)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder private var content: some View {
    switch phase {
    case .idle:
      EmptyView()
    case .recording:
      VStack(spacing: 10) {
        SCBarVisualizer(
          state: .speaking,
          barCount: 28,
          levels: dictation.spectrum,
          minHeight: 8,
          maxHeight: 100,
          centerAlign: true,
          height: 44
        )
        .environment(\.theme, Self.recordingTheme)

        if !dictation.liveTranscript.isEmpty {
          streamingText(dictation.liveTranscript)
        }
      }
    case .transcribing:
      VStack(spacing: 10) {
        SCBarVisualizer(
          state: .thinking,
          barCount: 28,
          minHeight: 8,
          maxHeight: 40,
          centerAlign: true,
          height: 24
        )
        .environment(\.theme, Self.processingTheme)

        if dictation.processingText.isEmpty {
          PulsingDots(color: RecordingPillPalette.processingBlue)
        } else {
          streamingText(dictation.processingText)
        }
      }
    }
  }

  /// The newest words matter most, so show the tail of the text.
  private func streamingText(_ text: String) -> some View {
    Text(String(text.suffix(240)))
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(Color.white.opacity(0.92))
      .lineLimit(3, reservesSpace: false)
      .truncationMode(.head)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private static let recordingTheme: Theme = {
    var theme = Theme.timberVox
    theme.primary = RecordingPillPalette.recordingRed
    theme.border = RecordingPillPalette.recordingRed.opacity(0.25)
    return theme
  }()

  private static let processingTheme: Theme = {
    var theme = Theme.timberVox
    theme.primary = RecordingPillPalette.processingBlue
    theme.border = RecordingPillPalette.processingBlue.opacity(0.3)
    return theme
  }()
}

extension AudioSpectrumMonitor: SCAudioLevelProvider {
  nonisolated func levels(bandCount: Int) -> [Float] {
    MainActor.assumeIsolated {
      let source = bars
      guard bandCount != source.count, !source.isEmpty else { return source }
      return (0..<bandCount).map { index in
        source[index * source.count / bandCount]
      }
    }
  }
}
