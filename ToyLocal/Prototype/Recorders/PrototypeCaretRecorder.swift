import SwiftUI

struct CaretPillMock: View {
  let state: RecordingMockState

  private var accent: Color {
    switch state {
    case .recording: .red
    case .processing, .streaming: .blue
    case .idle: .gray
    }
  }

  private var glow: Color {
    switch state {
    case .idle: return .clear
    case .recording: return accent.opacity(0.4)
    case .processing: return accent.opacity(0.3)
    case .streaming: return accent.opacity(0.28)
    }
  }

  var body: some View {
    VStack(spacing: -0.5) {
      ZStack {
        switch state {
        case .idle:
          idleDot
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        case .recording:
          recordingPill
            .transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
        case .processing:
          processingPill
            .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
        case .streaming:
          streamingChip
            .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
        }
      }

      CaretTail()
        .fill(.black.opacity(0.85))
        .frame(width: 10, height: 5)
        .opacity(state == .streaming ? 1 : 0)
        .scaleEffect(state == .streaming ? 1 : 0.3, anchor: .top)
    }
    .compositingGroup()
    .shadow(color: glow, radius: 7)
    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: state)
  }

  private var idleDot: some View {
    Image(systemName: "mic.fill")
      .font(.system(size: 7, weight: .semibold))
      .foregroundStyle(.white.opacity(0.4))
      .frame(width: 16, height: 16)
      .background(.black.opacity(0.55), in: Circle())
      .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
  }

  private var recordingPill: some View {
    HStack(spacing: 5) {
      Image(systemName: "mic.fill")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(accent.opacity(0.95))
      TLWaveform(
        barCount: 7,
        barWidth: 2.5,
        spacing: 2,
        minHeight: 2.5,
        maxHeight: 11,
        tint: .white.opacity(0.9)
      )
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(
      Capsule().fill(
        Color.black.opacity(0.85)
          .shadow(.inner(color: accent.opacity(0.35), radius: 3))
      )
    )
    .overlay(
      Capsule()
        .strokeBorder(accent.opacity(0.35), lineWidth: 0.5)
        .blendMode(.screen)
    )
  }

  private var processingPill: some View {
    HStack(spacing: 6) {
      Image(systemName: "sparkles")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(accent.opacity(0.9))
      TLProcessingDots(tint: .white.opacity(0.85), dotSize: 3.5)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 6)
    .background(
      Capsule().fill(
        Color.black.opacity(0.85)
          .shadow(.inner(color: accent.opacity(0.3), radius: 3))
      )
    )
    .overlay(
      Capsule()
        .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
        .blendMode(.screen)
    )
  }

  private var streamingChip: some View {
    GhostTranscriptTicker()
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        Capsule().fill(
          Color.black.opacity(0.85)
            .shadow(.inner(color: accent.opacity(0.3), radius: 3))
        )
      )
      .overlay(
        Capsule()
          .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
          .blendMode(.screen)
      )
  }
}

private struct GhostTranscriptTicker: View {
  private static let words =
    recordingMockTranscript
    .split(separator: " ")
    .map(String.init)

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.34)) { context in
      let words = Self.words
      let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.34)
      let index = tick % words.count
      let start = max(0, index - 2)
      let visible = words[start...index].joined(separator: " ")

      Text(visible)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(1)
        .frame(width: 116, alignment: .trailing)
        .clipped()
        .mask(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: 0.3),
              .init(color: .black, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .contentTransition(.numericText(countsDown: false))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
    }
  }
}

private struct CaretTail: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

#Preview("Caret Pill") {
  HStack(alignment: .bottom, spacing: 40) {
    ForEach(RecordingMockState.allCases) { s in
      VStack(spacing: 8) {
        Spacer(minLength: 0)
        CaretPillMock(state: s)
        Rectangle()
          .fill(Color.accentColor)
          .frame(width: 2, height: 16)
        Text(s.rawValue)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .frame(height: 110)
    }
  }
  .padding(48)
  .background(Color(white: 0.1))
}
