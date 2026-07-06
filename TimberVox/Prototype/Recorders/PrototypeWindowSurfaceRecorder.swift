import SwiftUI

struct WindowSurfaceMock: View {
  let state: RecordingMockState
  let width: CGFloat

  @State private var streamStart: Date?
  @State private var highWaterHeight: CGFloat = 0

  private static let words: [String] =
    recordingMockTranscript
    .split(separator: " ")
    .map(String.init)

  private let wordInterval: TimeInterval = 0.26

  var body: some View {
    ZStack(alignment: .top) {
      if state != .idle {
        surface
          .transition(
            .opacity
              .combined(with: .scale(scale: 0.94, anchor: .top))
          )
      }
    }
    .frame(width: width, alignment: .top)
    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: state)
    .onAppear {
      if state != .idle { streamStart = Date() }
    }
    .onChange(of: state) { _, newValue in
      switch newValue {
      case .recording:
        streamStart = Date()
        highWaterHeight = 0
      case .streaming, .processing:
        if streamStart == nil { streamStart = Date() }
      case .idle:
        streamStart = nil
        highWaterHeight = 0
      }
    }
  }

  private var surface: some View {
    content
      .padding(.horizontal, 14)
      .padding(.vertical, state == .streaming ? 12 : 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        GeometryReader { proxy in
          Color.clear.preference(
            key: SurfaceHeightPreferenceKey.self,
            value: proxy.size.height
          )
        }
      )
      .onPreferenceChange(SurfaceHeightPreferenceKey.self) { height in
        if state == .streaming, height > highWaterHeight {
          highWaterHeight = height
        }
      }
      .frame(
        minHeight: state == .streaming ? highWaterHeight : 0,
        alignment: .top
      )
      .background(.ultraThinMaterial)
      .background(Color.black.opacity(0.55))
      .overlay(alignment: .top) {
        if state == .streaming { topShimmer }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
      .animation(.spring(response: 0.38, dampingFraction: 0.85), value: highWaterHeight)
  }

  @ViewBuilder private var content: some View {
    VStack(alignment: .leading, spacing: 10) {
      statusRow

      if state == .streaming {
        streamingBody
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  private var statusRow: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(spacing: 10) {
        RecordDot(color: state == .processing ? .blue : .red)

        if state == .processing {
          TLProcessingDots(tint: .white.opacity(0.85), dotSize: 3.5)
          Text("Processing…")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .transition(.opacity)
        } else {
          TLWaveform(
            barCount: state == .streaming ? 12 : 15,
            barWidth: 2.5,
            spacing: 2,
            minHeight: 3,
            maxHeight: state == .streaming ? 12 : 16,
            tint: .white.opacity(0.85),
            active: true
          )
          if state == .recording {
            Text("Listening…")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)
              .transition(.opacity)
          }
        }

        Spacer(minLength: 0)

        modeChip
        Text(elapsedString(context.date.timeIntervalSince(streamStart ?? context.date)))
          .font(.system(size: 11, weight: .regular).monospacedDigit())
          .foregroundStyle(.tertiary)
          .opacity(streamStart == nil ? 0 : 1)
      }
      .frame(height: 20)
    }
  }

  private var modeChip: some View {
    Text("Default")
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(.white.opacity(0.75))
      .padding(.horizontal, 7)
      .padding(.vertical, 2.5)
      .background(
        Capsule().fill(Color.white.opacity(0.08))
      )
      .overlay(
        Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
      )
  }

  private var streamingBody: some View {
    TimelineView(.periodic(from: .now, by: 0.1)) { context in
      let elapsed = context.date.timeIntervalSince(streamStart ?? context.date)
      let visible = min(
        Self.words.count,
        max(1, Int(elapsed / wordInterval) + 1)
      )

      let _ = elapsed
      transcriptText(visibleWords: visible)
        .font(.system(size: 13))
        .lineSpacing(5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.18), value: visible)
    }
  }

  private func transcriptText(visibleWords: Int) -> Text {
    var result = Text(verbatim: "")
    for (index, word) in Self.words.prefix(visibleWords).enumerated() {
      let isLatest = index == visibleWords - 1
      let piece = Text(verbatim: index == 0 ? word : " " + word)
        .foregroundColor(isLatest ? .white : .white.opacity(0.72))
        .fontWeight(isLatest ? .medium : .regular)
      result = result + piece
    }
    return result
  }

  private func elapsedString(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let minutes = total / 60
    let seconds = total % 60
    return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
  }

  private var topShimmer: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let phase = CGFloat((t * 0.45).truncatingRemainder(dividingBy: 1))
      let bandWidth = width * 0.35
      let travel = width + bandWidth

      LinearGradient(
        stops: [
          .init(color: .white.opacity(0), location: 0),
          .init(color: .white.opacity(0.55), location: 0.5),
          .init(color: .white.opacity(0), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: bandWidth, height: 1.5)
      .offset(x: -bandWidth + phase * travel)
      .frame(maxWidth: .infinity, alignment: .leading)
      .clipped()
    }
    .frame(height: 1.5)
    .allowsHitTesting(false)
  }
}

private struct SurfaceHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct RecordDot: View {
  var color: Color = .red

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 7, height: 7)
      .shadow(color: color.opacity(0.6), radius: 3)
  }
}

#Preview("Window Surface") {
  VStack(spacing: 28) {
    WindowSurfaceMock(state: .recording, width: 560)
    WindowSurfaceMock(state: .streaming, width: 560)
  }
  .padding(40)
  .background(Color(white: 0.1))
}
