import SwiftUI

struct TLNotchShape: Shape {
  var topCornerRadius: CGFloat
  var bottomCornerRadius: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { .init(topCornerRadius, bottomCornerRadius) }
    set {
      topCornerRadius = newValue.first
      bottomCornerRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    path.move(to: CGPoint(x: rect.minX, y: rect.minY))

    path.addQuadCurve(
      to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
      control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
    )

    path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

    path.addQuadCurve(
      to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
      control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
    )

    path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

    path.addQuadCurve(
      to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
      control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
    )

    path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.minY),
      control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
    )

    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    return path
  }
}

struct NotchRecorderMock: View {
  let state: RecordingMockState
  let notchSize: CGSize

  @State private var typingStart = Date()

  private let recordingSideExpansion: CGFloat = 90
  private let streamingSideExpansion: CGFloat = 110
  private let activeHeightBonus: CGFloat = 6
  private let transcriptRowHeight: CGFloat = 22
  private let transcriptBottomPad: CGFloat = 8

  private var mainRowHeight: CGFloat { notchSize.height + activeHeightBonus }

  @State private var transcriptRows: Int = 1

  private var pillWidth: CGFloat {
    switch state {
    case .idle: return notchSize.width
    case .recording, .processing: return notchSize.width + recordingSideExpansion * 2
    case .streaming: return notchSize.width + streamingSideExpansion * 2
    }
  }

  private var transcriptPanelHeight: CGFloat {
    transcriptRowHeight * CGFloat(transcriptRows) + transcriptBottomPad
  }

  private var pillHeight: CGFloat {
    switch state {
    case .idle: return notchSize.height
    case .recording, .processing: return mainRowHeight
    case .streaming: return mainRowHeight + transcriptPanelHeight
    }
  }

  private var sideExpansion: CGFloat {
    state == .streaming ? streamingSideExpansion : recordingSideExpansion
  }

  private var sideEdgePadding: CGFloat {
    state == .streaming ? 20 : 16
  }

  private var topCornerRadius: CGFloat {
    state == .streaming ? 12 : 8
  }

  private var bottomCornerRadius: CGFloat {
    state == .streaming ? 22 : 16
  }

  private let expandAnimation = Animation.spring(response: 0.42, dampingFraction: 0.80)
  private let collapseAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0)

  private var pillAnimation: Animation {
    state == .idle ? collapseAnimation : expandAnimation
  }

  private var wingAnimation: Animation {
    state == .idle ? collapseAnimation : expandAnimation.delay(0.09)
  }

  private var maxPillWidth: CGFloat { notchSize.width + streamingSideExpansion * 2 }
  private var maxPillHeight: CGFloat { mainRowHeight + transcriptRowHeight * 2 + transcriptBottomPad }

  var body: some View {
    pill
      .frame(width: maxPillWidth, height: maxPillHeight, alignment: .top)
      .animation(pillAnimation, value: state)
      .onChange(of: state) { newValue in
        if newValue == .streaming {
          typingStart = Date()
          transcriptRows = 1
        }
      }
      .animation(pillAnimation, value: transcriptRows)
      .onAppear {
        typingStart = Date()
      }
  }

  private var pill: some View {
    VStack(spacing: 0) {
      mainRow
      liveTextPanel
    }
    .frame(width: pillWidth, height: pillHeight)
    .background(Color.black)
    .clipShape(
      TLNotchShape(
        topCornerRadius: topCornerRadius,
        bottomCornerRadius: bottomCornerRadius
      )
    )
  }

  private var mainRow: some View {
    ZStack {
      Color.clear

      HStack(spacing: 14) {
        recordButton
        modeChip
        Spacer(minLength: 0)
      }
      .padding(.leading, sideEdgePadding)
      .frame(width: sideExpansion)
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(state != .idle ? 1 : 0)
      .animation(wingAnimation, value: state)

      HStack(spacing: 0) {
        Spacer(minLength: 0)
        if state == .processing {
          TLProcessingDots(tint: .white.opacity(0.85), dotSize: 4)
        } else {
          TLWaveform(
            barCount: 15,
            barWidth: 3,
            spacing: 2,
            minHeight: 4,
            maxHeight: min(20, mainRowHeight - 10),
            tint: .white.opacity(0.9),
            active: state != .idle
          )
        }
      }
      .padding(.trailing, sideEdgePadding)
      .frame(width: sideExpansion)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .opacity(state != .idle ? 1 : 0)
      .animation(wingAnimation, value: state)
    }
    .frame(height: state == .idle ? notchSize.height : mainRowHeight)
  }

  private var recordButton: some View {
    ZStack {
      Circle()
        .fill(.white.opacity(0.14))
        .frame(width: 22, height: 22)

      if state == .streaming {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(Color.red)
          .frame(width: 9, height: 9)
      } else if state == .processing {
        Image(systemName: "sparkles")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))
      } else {
        Circle()
          .fill(Color.red)
          .frame(width: 10, height: 10)
      }
    }
  }

  private var modeChip: some View {
    Image(systemName: "sparkles")
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.white.opacity(0.55))
      .frame(width: 20, height: 20)
      .background(.white.opacity(0.08), in: Circle())
  }

  private var liveTextPanel: some View {
    VStack(spacing: 0) {
      if state == .streaming {
        transcriptText
          .padding(.horizontal, 8)
      }
    }
    .frame(height: state == .streaming ? transcriptPanelHeight : 0)
    .clipped()
  }

  private var transcriptText: some View {
    TimelineView(.animation(minimumInterval: 0.12, paused: state != .streaming)) { context in
      let revealed = revealedTranscript(at: context.date)
      (Text(revealed)
        .foregroundColor(.white.opacity(0.92))
        + Text(revealed.isEmpty ? "" : " ")
        + Text("\u{258E}")
        .foregroundColor(.white.opacity(0.45)))
        .font(.system(size: 12))
        .lineLimit(2)
        .truncationMode(.head)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .onChange(of: revealed) { text in
          let rows = text.count > 52 ? 2 : 1
          if rows != transcriptRows { transcriptRows = rows }
        }
    }
  }

  private func revealedTranscript(at date: Date) -> String {
    let words = recordingMockTranscript.split(separator: " ")
    guard !words.isEmpty else { return "" }

    let perWord = 0.28
    let hold = 1.6
    let cycle = Double(words.count) * perWord + hold
    let elapsed = date.timeIntervalSince(typingStart)
    guard elapsed >= 0 else { return "" }

    let phase = elapsed.truncatingRemainder(dividingBy: cycle)
    let count = min(words.count, Int(phase / perWord) + 1)
    return words.prefix(count).joined(separator: " ")
  }
}

#Preview("Notch") {
  let notchSize = CGSize(width: 196, height: 32)

  return VStack(spacing: 28) {
    ForEach(RecordingMockState.allCases) { state in
      VStack(alignment: .leading, spacing: 6) {
        Text(state.rawValue)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white.opacity(0.4))
          .padding(.leading, 4)

        ZStack(alignment: .top) {
          Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: notchSize.height)
            .frame(maxWidth: .infinity)

          Rectangle()
            .fill(.black)
            .frame(width: notchSize.width, height: notchSize.height)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10))

          NotchRecorderMock(state: state, notchSize: notchSize)
        }
        .frame(width: 520, height: 100, alignment: .top)
      }
    }
  }
  .padding(32)
  .background(Color(white: 0.1))
}
