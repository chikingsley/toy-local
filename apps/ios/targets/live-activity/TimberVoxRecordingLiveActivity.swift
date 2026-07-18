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
      HStack(spacing: 14) {
        recordingGlyph(phase: context.state.phase)
        VStack(alignment: .leading, spacing: 3) {
          Text(context.attributes.modeName)
            .font(.headline)
          Text(context.state.phase == "finishing" ? "Transcribing…" : "Listening…")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        if context.state.phase == "recording" {
          Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
            .font(.system(.body, design: .monospaced, weight: .semibold))
            .monospacedDigit()
          Button(intent: StopTimberVoxRecordingIntent()) {
            Image(systemName: "stop.fill")
              .frame(width: 34, height: 34)
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)
        }
      }
      .padding(.horizontal, 16)
      .activityBackgroundTint(Color.black.opacity(0.9))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          recordingGlyph(phase: context.state.phase)
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
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(context.state.phase == "finishing" ? "Transcribing…" : "Listening…")
            Spacer()
            if context.state.phase == "recording" {
              Button(intent: StopTimberVoxRecordingIntent()) {
                Label("Stop", systemImage: "stop.fill")
              }
              .buttonStyle(.borderedProminent)
              .tint(.red)
            }
          }
        }
      } compactLeading: {
        Image(systemName: context.state.phase == "finishing" ? "waveform" : "mic.fill")
          .foregroundStyle(context.state.phase == "finishing" ? .cyan : .red)
      } compactTrailing: {
        Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
          .font(.system(.caption2, design: .monospaced, weight: .semibold))
          .monospacedDigit()
      } minimal: {
        Image(systemName: context.state.phase == "finishing" ? "waveform" : "mic.fill")
          .foregroundStyle(context.state.phase == "finishing" ? .cyan : .red)
      }
      .widgetURL(URL(string: "timbervox://session"))
      .keylineTint(.cyan)
    }
  }

  private func recordingGlyph(phase: String) -> some View {
    Image(systemName: phase == "finishing" ? "waveform" : "mic.fill")
      .font(.title3.weight(.semibold))
      .foregroundStyle(phase == "finishing" ? .cyan : .red)
      .frame(width: 38, height: 38)
      .background(.white.opacity(0.1), in: Circle())
  }
}
