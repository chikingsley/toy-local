import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct TimberVoxRecordingWidgetBundle: WidgetBundle {
  var body: some Widget {
    TimberVoxRecordingLiveActivity()
  }
}

struct TimberVoxRecordingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TimberVoxRecordingAttributes.self) { context in
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          sessionGlyph(phase: context.state.phase)

          HStack(spacing: 6) {
            Text("TimberVox")
              .font(.subheadline.weight(.semibold))
            Text(statusLabel(phase: context.state.phase))
              .font(.caption2.weight(.semibold))
              .foregroundStyle(statusColor(phase: context.state.phase))
          }

          Spacer(minLength: 8)

          if context.state.phase == "recording" {
            Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
              .font(.system(.caption2, design: .monospaced, weight: .semibold))
              .monospacedDigit()
              .foregroundStyle(TimberVoxActivityPalette.slate)
              .frame(width: 44, alignment: .trailing)
          }
        }

        activitySignal(state: context.state)
          .frame(maxWidth: .infinity)
          .frame(height: 18)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .foregroundStyle(.white)
      .activityBackgroundTint(TimberVoxActivityPalette.ink)
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          sessionGlyph(phase: context.state.phase)
        }

        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.modeName)
            .font(.headline)
            .lineLimit(1)
        }

        DynamicIslandExpandedRegion(.trailing) {
          if context.state.phase == "recording" {
            Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
              .font(.system(.caption, design: .monospaced, weight: .semibold))
              .monospacedDigit()
              .foregroundStyle(TimberVoxActivityPalette.slate)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          activitySignal(state: context.state)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: compactGlyph(phase: context.state.phase))
          .foregroundStyle(statusColor(phase: context.state.phase))
      } compactTrailing: {
        if context.state.displayMode == "words", !context.state.partialTranscript.isEmpty {
          LiveTranscriptLine(text: context.state.partialTranscript)
            .frame(width: 52)
        } else {
          TimberlineWaveform(levels: context.state.audioLevels, barCount: 7)
            .frame(width: 48, height: 18)
        }
      } minimal: {
        Image(systemName: compactGlyph(phase: context.state.phase))
          .foregroundStyle(statusColor(phase: context.state.phase))
      }
      .widgetURL(URL(string: "timbervox://session"))
      .keylineTint(TimberVoxActivityPalette.cyan)
    }
  }

  @ViewBuilder
  private func activitySignal(
    state: TimberVoxRecordingAttributes.ContentState
  ) -> some View {
    if state.displayMode == "words", !state.partialTranscript.isEmpty {
      LiveTranscriptLine(text: state.partialTranscript)
    } else {
      TimberlineWaveform(levels: state.audioLevels, barCount: 18)
    }
  }

  private func sessionGlyph(phase: String) -> some View {
    Image(systemName: compactGlyph(phase: phase))
      .font(.callout.weight(.semibold))
      .foregroundStyle(statusColor(phase: phase))
      .frame(width: 32, height: 32)
      .background(TimberVoxActivityPalette.midnight, in: Circle())
  }

  private func compactGlyph(phase: String) -> String {
    switch phase {
    case "processing", "finalizing": "ellipsis"
    case "failed": "exclamationmark"
    case "ready": "mic"
    default: "mic.fill"
    }
  }

  private func statusLabel(phase: String) -> String {
    switch phase {
    case "ready": "READY"
    case "processing", "finalizing": "PROCESSING"
    case "failed": "FAILED"
    default: "LISTENING"
    }
  }

  private func statusColor(phase: String) -> Color {
    switch phase {
    case "ready": TimberVoxActivityPalette.slate
    case "failed": TimberVoxActivityPalette.coral
    default: TimberVoxActivityPalette.cyan
    }
  }
}

private struct TimberlineWaveform: View {
  let levels: [Double]
  let barCount: Int

  var body: some View {
    GeometryReader { geometry in
      let values = displayedLevels
      let spacing = max(1, geometry.size.width / CGFloat(barCount * 5))
      HStack(alignment: .center, spacing: spacing) {
        ForEach(Array(values.enumerated()), id: \.offset) { _, level in
          Capsule()
            .fill(
              LinearGradient(
                colors: [TimberVoxActivityPalette.blue, TimberVoxActivityPalette.cyan],
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .frame(
              maxWidth: .infinity,
              minHeight: 2,
              maxHeight: max(2, geometry.size.height * CGFloat(0.16 + level * 0.84))
            )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .animation(.smooth(duration: 0.22), value: levels)
    .accessibilityLabel("Live microphone level")
  }

  private var displayedLevels: [Double] {
    let bounded = levels.suffix(barCount).map { min(1, max(0, $0)) }
    if bounded.count == barCount { return Array(bounded) }
    return Array(repeating: 0.08, count: barCount - bounded.count) + bounded
  }
}

private struct LiveTranscriptLine: View {
  let text: String

  var body: some View {
    HStack(spacing: 7) {
      Text(text)
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .truncationMode(.head)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .mask {
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .white, location: 0.16),
              .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        }
      Image(systemName: "mic.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(TimberVoxActivityPalette.cyan)
    }
    .foregroundStyle(.white)
    .contentTransition(.interpolate)
    .accessibilityLabel(text)
  }
}

private enum TimberVoxActivityPalette {
  static let ink = Color(red: 0.043, green: 0.063, blue: 0.094)
  static let midnight = Color(red: 0.067, green: 0.098, blue: 0.153)
  static let blue = Color(red: 0.231, green: 0.510, blue: 0.965)
  static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)
  static let coral = Color(red: 0.984, green: 0.443, blue: 0.522)
  static let slate = Color(red: 0.580, green: 0.639, blue: 0.722)
}
