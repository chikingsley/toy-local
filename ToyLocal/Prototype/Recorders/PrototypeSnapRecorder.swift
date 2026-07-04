import SwiftUI

struct SnapCapsuleMock: View {
  let state: RecordingMockState

  private var accent: Color {
    switch state {
    case .idle: return .gray
    case .recording: return .red
    case .processing, .streaming: return .blue
    }
  }

  private var backgroundColor: Color {
    accent.mix(with: .black, by: 0.55)
  }

  private var strokeColor: Color {
    accent.mix(with: .white, by: 0.1).opacity(0.6)
  }

  var body: some View {
    if state != .idle {
      TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
        capsule(time: context.date.timeIntervalSinceReferenceDate)
      }
      .transition(.scale(scale: 0.6).combined(with: .opacity))
      .animation(.spring(response: 0.34, dampingFraction: 0.74), value: state)
    }
  }

  private func capsule(time: Double) -> some View {
    HStack(spacing: 10) {
      grabber

      Circle()
        .fill(accent)
        .frame(width: 7, height: 7)
        .shadow(color: accent.opacity(0.8), radius: 3)

      if state == .processing {
        TLProcessingDots(tint: .white.opacity(0.9), dotSize: 4)
          .frame(height: 15)
      } else {
        TLWaveform(
          barCount: 13,
          barWidth: 3,
          spacing: 2.5,
          minHeight: 3,
          maxHeight: 15,
          tint: .white.opacity(0.92),
          active: true
        )
      }
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 9)
    .background(
      Capsule().fill(
        backgroundColor
          .shadow(.inner(color: accent, radius: 4))
      )
    )
    .overlay(
      Capsule()
        .strokeBorder(strokeColor, lineWidth: 1)
        .blendMode(.screen)
    )
    .overlay(shine(time: time))
    .compositingGroup()
    .shadow(color: accent.opacity(0.45), radius: 5)
    .shadow(color: accent.opacity(0.25), radius: 10)
    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
  }

  private var grabber: some View {
    VStack(spacing: 2.5) {
      ForEach(0..<3, id: \.self) { _ in
        Capsule()
          .fill(.white.opacity(0.26))
          .frame(width: 9, height: 1.5)
      }
    }
  }

  @ViewBuilder private func shine(time: Double) -> some View {
    if state == .processing {
      let phase = (time / 1.1).truncatingRemainder(dividingBy: 1)
      Capsule()
        .fill(
          LinearGradient(
            stops: [
              .init(color: .clear, location: max(0, phase - 0.2)),
              .init(color: .white.opacity(0.35), location: phase),
              .init(color: .clear, location: min(1, phase + 0.2)),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
  }
}

struct CursorTagMock: View {
  let state: RecordingMockState

  private var accent: Color {
    switch state {
    case .idle: return .gray
    case .recording: return .red
    case .processing, .streaming: return .blue
    }
  }

  var body: some View {
    if state != .idle {
      tag
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
  }

  private var tag: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(accent)
        .frame(width: 5, height: 5)
        .shadow(color: accent.opacity(0.8), radius: 2)

      if state == .processing {
        TLProcessingDots(tint: .white.opacity(0.9), dotSize: 2.5)
          .frame(height: 7)
      } else {
        TLWaveform(
          barCount: 5,
          barWidth: 1.5,
          spacing: 1.5,
          minHeight: 2,
          maxHeight: 7,
          tint: .white.opacity(0.9),
          active: true
        )
      }
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .background(
      Capsule().fill(
        Color.black.opacity(0.82)
          .shadow(.inner(color: accent.opacity(0.3), radius: 2))
      )
    )
    .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    .compositingGroup()
    .shadow(color: accent.opacity(0.35), radius: 3, x: -1)
    .shadow(color: .black.opacity(0.35), radius: 5, x: -3, y: 1)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
  }
}

#Preview("Snap + Cursor") {
  VStack(spacing: 28) {
    ForEach(RecordingMockState.allCases) { s in
      HStack(spacing: 28) {
        SnapCapsuleMock(state: s)
        CursorTagMock(state: s)
        Text(s.rawValue)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(width: 64, alignment: .leading)
      }
    }
  }
  .padding(48)
  .background(Color(white: 0.1))
}
