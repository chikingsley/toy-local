import SwiftUI

/// The pill itself: near-invisible oval when idle, red level-reactive pill
/// while recording, blue while transcribing — streaming the processed text
/// into the pill as it arrives. Display-only — no click targets.
enum IndicatorStyle: String, CaseIterable, Identifiable {
  case mini, large, compact

  static let defaultValue: Self = .large

  var id: String { rawValue }

  var label: String {
    switch self {
    case .mini: "Mini"
    case .large: "Window"
    case .compact: "Compact"
    }
  }
}

/// What the indicator is showing right now — shared by the pill and the
/// window surface.
enum RecordingPillPhase: Equatable {
  case idle, recording, transcribing
}

/// Shared by the live pill and the Settings style previews.
enum RecordingPillPalette {
  static let recordingRed = Color(red: 0.88, green: 0.27, blue: 0.24)
  static let processingBlue = Color(red: 0.25, green: 0.54, blue: 0.88)
  static let pillSurface = Color(red: 0.04, green: 0.04, blue: 0.045)
  static let compactBlue = Color(nsColor: .systemBlue)
}

struct RecordingPillView: View {
  let dictation: DictationController
  @AppStorage("indicatorStyle") private var styleRaw = IndicatorStyle.defaultValue.rawValue

  private var style: IndicatorStyle {
    IndicatorStyle(rawValue: styleRaw) ?? .defaultValue
  }

  var body: some View {
    VStack {
      Spacer()
      Group {
        if style == .large, phase != .idle {
          RecordingWindowView(dictation: dictation, phase: phase)
        } else {
          pill
        }
      }
      .animation(.spring(response: 0.42, dampingFraction: 0.8), value: phase)
      .animation(.spring(response: 0.42, dampingFraction: 0.8), value: showsProcessingText)
      Spacer().frame(height: 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var phase: RecordingPillPhase {
    switch dictation.state {
    case .idle: .idle
    case .recording: .recording
    case .transcribing: .transcribing
    }
  }

  private var pill: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(phase != .idle && style == .compact ? RecordingPillPalette.compactBlue : RecordingPillPalette.pillSurface)
        .shadow(color: .black.opacity(0.45), radius: 7, y: 2)

      switch phase {
      case .idle:
        EmptyView()
      case .recording:
        recordingContent
          .transition(.opacity)
      case .transcribing:
        transcribingContent
          .transition(.opacity)
      }
    }
    .frame(width: pillSize.width, height: pillSize.height)
  }

  private var cornerRadius: CGFloat {
    if style == .compact && phase != .idle {
      return 13
    }
    return pillSize.height / 2
  }

  private var pillSize: CGSize {
    switch (phase, style) {
    case (.idle, _): CGSize(width: 46, height: 11)
    case (.recording, .mini): CGSize(width: 156, height: 36)
    case (.recording, .large): CGSize(width: 246, height: 56)
    case (.recording, .compact): CGSize(width: 53, height: 32)
    case (.transcribing, .mini): CGSize(width: showsProcessingText ? 280 : 132, height: 34)
    case (.transcribing, .large): CGSize(width: showsProcessingText ? 400 : 180, height: 48)
    case (.transcribing, .compact): CGSize(width: 53, height: 32)
    }
  }

  /// The transform result streams in while transcribing; compact stays dots-only.
  private var showsProcessingText: Bool {
    phase == .transcribing && style != .compact && !dictation.processingText.isEmpty
  }

  @ViewBuilder private var recordingContent: some View {
    if style == .compact {
      CompactSpectrumBars(bars: dictation.spectrum.bars)
        .frame(width: 29, height: 6)
    } else {
      SpectrumBars(
        bars: dictation.spectrum.bars,
        color: RecordingPillPalette.recordingRed,
        barWidth: style == .large ? 5 : 3,
        barSpacing: style == .large ? 3.5 : 2.5,
        maxBarHeight: style == .large ? 38 : 22,
        minBarHeight: style == .large ? 2 : 1.5
      )
      .frame(width: style == .large ? 200 : 116, height: style == .large ? 40 : 16)
      .padding(.horizontal, 14)
    }
  }

  private var transcribingContent: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(style == .compact ? Color.white : RecordingPillPalette.processingBlue)
        .frame(width: 8, height: 8)
      if showsProcessingText {
        Text(dictation.processingText)
          .font(.system(size: style == .large ? 13 : 12, weight: .medium))
          .foregroundStyle(Color.white.opacity(0.92))
          .lineLimit(1)
          .truncationMode(.head)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        PulsingDots(color: style == .compact ? Color.white : RecordingPillPalette.processingBlue)
      }
    }
    .padding(.horizontal, 14)
  }
}

struct SpectrumBars: View {
  let bars: [Float]
  let color: Color
  var barWidth: CGFloat = 3
  var barSpacing: CGFloat = 2.5
  var maxBarHeight: CGFloat = 22
  var minBarHeight: CGFloat = 1.5

  private static let phases: [Double] = (0..<64).map { index in
    let step = Double((index * 7919) % 97)
    return step / 97.0 * 2.0 * Double.pi
  }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      let energy = CGFloat(bars.max() ?? 0)
      HStack(alignment: .center, spacing: barSpacing) {
        ForEach(bars.indices, id: \.self) { index in
          let contrast = pow(CGFloat(bars[index]), 1.6)
          let wobble = energy * 0.22 * CGFloat(sin(time * 11 + Self.phases[index % 64]))
          let value = max(0, min(1, contrast + wobble))
          Capsule()
            .fill(color)
            .frame(width: barWidth, height: minBarHeight + (maxBarHeight - minBarHeight) * value)
        }
      }
    }
    .frame(maxHeight: .infinity, alignment: .center)
    .animation(.spring(response: 0.18, dampingFraction: 0.55), value: bars)
  }
}

struct CompactSpectrumBars: View {
  let bars: [Float]

  private var compactBars: [CGFloat] {
    guard !bars.isEmpty else {
      return Array(repeating: 0, count: 10)
    }

    return (0..<10).map { index in
      let start = index * bars.count / 10
      let end = max(start + 1, (index + 1) * bars.count / 10)
      return CGFloat(bars[start..<min(end, bars.count)].max() ?? 0)
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 1) {
      ForEach(compactBars.indices, id: \.self) { index in
        let value = max(0, min(1, compactBars[index]))
        Capsule()
          .fill(Color.white)
          .frame(width: 2, height: 2 + 4 * value)
      }
    }
    .frame(maxHeight: .infinity, alignment: .center)
    .animation(.spring(response: 0.18, dampingFraction: 0.55), value: bars)
  }
}

struct PulsingDots: View {
  let color: Color
  @State private var animating = false

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: 4, height: 4)
          .opacity(animating ? 0.25 : 1)
          .animation(
            .easeInOut(duration: 0.5)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.16),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
  }
}
