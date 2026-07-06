import AVFoundation
import SwiftUI

enum RecordingMockState: String, CaseIterable, Identifiable {
  case idle = "Idle"
  case recording = "Recording"
  case processing = "Processing"
  case streaming = "Streaming"

  var id: String { rawValue }
}

enum TLSpeechEnvelope {
  private static let words: [(Double, Double, Double)] = [
    (0.00, 0.34, 0.85), (0.46, 0.22, 0.65), (0.78, 0.55, 1.00),
    (1.48, 0.20, 0.55), (1.80, 0.42, 0.90), (2.42, 0.30, 0.70),
    (3.05, 0.62, 0.95), (3.90, 0.24, 0.60), (4.28, 0.40, 0.80),
    (5.00, 0.30, 0.72),
  ]
  private static let cycle: Double = 6.1  // includes an end-of-sentence pause

  static func level(at t: Double) -> Double {
    let phase = t.truncatingRemainder(dividingBy: cycle)
    var value = 0.0
    for (start, duration, peak) in words {
      let attack = 0.045
      let release = 0.14
      if phase >= start - attack, phase <= start + duration + release {
        let core: Double
        if phase < start {
          core = 1 - (start - phase) / attack
        } else if phase <= start + duration {
          core = 0.7 + 0.3 * sin((phase - start) * 24)
        } else {
          core = 1 - (phase - start - duration) / release
        }
        value = max(value, peak * max(0, core))
      }
    }
    return value
  }
}

@MainActor @Observable
final class TLMicLevel {
  private(set) var level: Double?
  private var engine: AVAudioEngine?

  func start() {
    guard engine == nil else { return }
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else { return }
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      guard let data = buffer.floatChannelData?[0] else { return }
      let count = Int(buffer.frameLength)
      var sum: Float = 0
      for i in 0..<count { sum += data[i] * data[i] }
      let rms = sqrt(sum / Float(max(count, 1)))
      let normalized = min(1, Double(rms) * 18)
      Task { @MainActor [weak self] in self?.level = normalized }
    }
    do {
      try engine.start()
      self.engine = engine
    } catch {
      input.removeTap(onBus: 0)
      level = nil
    }
  }

  func stop() {
    engine?.inputNode.removeTap(onBus: 0)
    engine?.stop()
    engine = nil
    level = nil
  }
}

private struct TLAudioLevelKey: EnvironmentKey {
  static let defaultValue: Double? = nil
}

extension EnvironmentValues {
  var protoAudioLevel: Double? {
    get { self[TLAudioLevelKey.self] }
    set { self[TLAudioLevelKey.self] = newValue }
  }
}

struct TLWaveform: View {
  var barCount: Int = 15
  var barWidth: CGFloat = 3
  var spacing: CGFloat = 2
  var minHeight: CGFloat = 4
  var maxHeight: CGFloat = 22
  var tint: Color = .white
  var active: Bool = true

  @Environment(\.protoAudioLevel) private var liveLevel

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let envelope = active ? (liveLevel ?? TLSpeechEnvelope.level(at: t)) : 0
      HStack(alignment: .center, spacing: spacing) {
        ForEach(0..<barCount, id: \.self) { i in
          let center = 1.0 - abs(Double(i) - Double(barCount - 1) / 2) / (Double(barCount) / 2)
          let weight = 0.5 + center * 0.5
          let jitter = 0.55 + 0.45 * sin(t * 31 + Double(i) * 1.7)
          let level = envelope * weight * jitter
          Capsule()
            .fill(tint)
            .frame(width: barWidth, height: minHeight + (maxHeight - minHeight) * min(1, level))
        }
      }
    }
    .animation(.easeOut(duration: 0.2), value: active)
  }
}

struct TLProcessingDots: View {
  var tint: Color = .white.opacity(0.85)
  var dotSize: CGFloat = 4

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      HStack(spacing: dotSize * 0.9) {
        ForEach(0..<3, id: \.self) { i in
          let phase = (t * 1.6 - Double(i) * 0.22).truncatingRemainder(dividingBy: 1)
          let lift = max(0, sin(phase * .pi * 2))  // rise and settle
          Circle()
            .fill(tint)
            .frame(width: dotSize, height: dotSize)
            .opacity(0.35 + 0.65 * lift)
            .offset(y: -lift * dotSize * 0.6)
        }
      }
    }
  }
}

let recordingMockTranscript = "Okay so the main thing I want to work on today is the recording window"

enum RecordingVariant: String, CaseIterable, Identifiable {
  case notch = "Notch"
  case caret = "Caret"
  case windowSurface = "Surface"
  case snapCapsule = "Snap"
  case cursorTag = "Cursor"
  case original = "Original"

  var id: String { rawValue }
}

struct PrototypeRecordingStage: View {
  @State private var variant: RecordingVariant = .notch
  @State private var state: RecordingMockState = .recording
  @State private var liveMic = false
  @State private var mic = TLMicLevel()

  private let stageSize = CGSize(width: 900, height: 620)
  private let notchSize = CGSize(width: 196, height: 32)

  var body: some View {
    VStack(spacing: 0) {
      stage
        .environment(\.protoAudioLevel, liveMic ? mic.level : nil)
      controls
    }
    .background(Color(white: 0.08))
    .onChange(of: liveMic) { _, on in
      if on { mic.start() } else { mic.stop() }
    }
  }

  private var stage: some View {
    ZStack(alignment: .topLeading) {
      LinearGradient(
        colors: [Color(red: 0.13, green: 0.16, blue: 0.26), Color(red: 0.05, green: 0.06, blue: 0.10)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )

      HStack {
        Text("\u{F8FF}  TimberVox  File  Edit  View")
          .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.78))
          .padding(.leading, 16)
        Spacer()
        Text("Fri Jul 4  10:12 AM")
          .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.78))
          .padding(.trailing, 16)
      }
      .frame(height: notchSize.height)
      .background(.black.opacity(0.28))

      Rectangle()
        .fill(.black)
        .frame(width: notchSize.width, height: notchSize.height)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
        .frame(maxWidth: .infinity)

      fakeAppWindow
        .frame(width: 560, height: 380)
        .offset(x: 170, y: 96)

      if variant == .cursorTag {
        Image(systemName: "cursorarrow")
          .font(.system(size: 16))
          .foregroundStyle(.white)
          .offset(x: cursorPoint.x, y: cursorPoint.y)
      }

      overlays
    }
    .frame(width: stageSize.width, height: stageSize.height)
    .clipped()
  }

  private var caretPoint: CGPoint { CGPoint(x: 170 + 36 + 306, y: 96 + 64 + 58) }
  private var cursorPoint: CGPoint { CGPoint(x: 620, y: 330) }

  private var fakeAppWindow: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { _ in Circle().fill(.white.opacity(0.25)).frame(width: 10, height: 10) }
        Spacer()
        Text("Notes — Untitled").font(.system(size: 11)).foregroundStyle(.secondary)
        Spacer()
      }
      .padding(10)
      .background(.white.opacity(0.06))

      VStack(alignment: .leading, spacing: 7) {
        Text("Meeting follow-ups").font(.system(size: 15, weight: .semibold))
        Text("— Ship the sidebar reorganization this week")
        Text("— Ask Priya about the release notes draft")
        HStack(spacing: 0) {
          Text("— ")
          Text(state == .streaming ? recordingMockTranscript : "")
            .foregroundStyle(.white.opacity(0.9))
          Rectangle().fill(Color.accentColor).frame(width: 2, height: 16)
        }
      }
      .font(.system(size: 13))
      .foregroundStyle(.white.opacity(0.75))
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(Color(red: 0.13, green: 0.13, blue: 0.15))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
  }

  @ViewBuilder private var overlays: some View {
    switch variant {
    case .notch:
      NotchRecorderMock(state: state, notchSize: notchSize)
        .frame(maxWidth: .infinity)
    case .caret:
      CaretPillMock(state: state)
        .offset(x: caretPoint.x - 60, y: caretPoint.y - 40)
    case .windowSurface:
      WindowSurfaceMock(state: state, width: 560)
        .offset(x: 170, y: 96 + 380 + 8)
    case .snapCapsule:
      SnapCapsuleMock(state: state)
        .frame(maxWidth: .infinity)
        .offset(y: stageSize.height - 64)
    case .cursorTag:
      CursorTagMock(state: state)
        .offset(x: cursorPoint.x + 18, y: cursorPoint.y + 6)
    case .original:
      OriginalCapsuleMock(state: state)
        .frame(maxWidth: .infinity)
        .offset(y: stageSize.height - 64)
    }
  }

  private var controls: some View {
    HStack(spacing: 14) {
      Picker("", selection: $variant) {
        ForEach(RecordingVariant.allCases) { v in Text(v.rawValue).tag(v) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      Picker("", selection: $state) {
        ForEach(RecordingMockState.allCases) { s in Text(s.rawValue).tag(s) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 320)

      Toggle("Live Mic", isOn: $liveMic)
        .toggleStyle(.switch)
        .controlSize(.small)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.black.opacity(0.35))
  }
}

struct OriginalCapsuleMock: View {
  let state: RecordingMockState

  private var status: TranscriptionIndicatorView.Status {
    switch state {
    case .idle: .hidden
    case .recording: .recording
    case .processing: .transcribing
    case .streaming: .alwaysOnListening
    }
  }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: state != .recording && state != .streaming)) { context in
      let level = TLSpeechEnvelope.level(at: context.date.timeIntervalSinceReferenceDate)
      let meterLevel = (state == .recording || state == .streaming) ? level : 0
      TranscriptionIndicatorView(
        status: status,
        meter: Meter(averagePower: meterLevel * 0.35, peakPower: meterLevel * 0.45)
      )
    }
  }
}

#Preview("Recording Stage") {
  PrototypeRecordingStage()
}
