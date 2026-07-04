import SwiftUI

enum RecordingSurfaceChoice: String, CaseIterable, Identifiable {
  case classic, mini, notch, cursor, input, none

  var id: String { rawValue }

  var label: String {
    switch self {
    case .classic: "Classic"
    case .mini: "Mini"
    case .notch: "Notch"
    case .cursor: "Cursor"
    case .input: "Input"
    case .none: "None"
    }
  }

  var headerIcon: String {
    switch self {
    case .classic: "waveform"
    case .mini: "waveform.circle"
    case .notch: "macbook"
    case .cursor: "cursorarrow.rays"
    case .input: "text.cursor"
    case .none: "eye.slash"
    }
  }
}

struct RecordingSurfacePreview: View {
  let choice: RecordingSurfaceChoice
  let selected: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))

      switch choice {
      case .classic:
        Capsule()
          .fill(.black.opacity(0.55))
          .frame(width: 92, height: 32)
          .overlay(
            ConfigurationMirroredWaveform(
              color: selected ? .accentColor : .secondary,
              bars: 28,
              height: 18
            )
          )
      case .mini:
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.55))
          .frame(width: 46, height: 36)
          .overlay(
            ConfigurationMirroredWaveform(
              color: selected ? .accentColor : .secondary,
              bars: 9,
              height: 20
            )
          )
      case .notch:
        VStack(spacing: 4) {
          Capsule()
            .fill(.black)
            .frame(width: 58, height: 14)
          Capsule()
            .fill(.black.opacity(0.58))
            .frame(width: 94, height: 28)
            .overlay(
              ConfigurationMirroredWaveform(
                color: selected ? .accentColor : .secondary,
                bars: 18,
                height: 15
              )
            )
        }
      case .cursor:
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 5)
            .fill(.white.opacity(0.07))
            .frame(width: 78, height: 42)
            .overlay(alignment: .leading) {
              Rectangle().fill(.white.opacity(0.65)).frame(width: 1, height: 26).padding(.leading, 27)
            }
          Capsule()
            .fill(.black.opacity(0.72))
            .frame(width: 52, height: 22)
            .overlay(
              ConfigurationMirroredWaveform(
                color: selected ? .accentColor : .secondary,
                bars: 9,
                height: 12
              )
            )
            .offset(x: 42, y: -13)
        }
      case .input:
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.07))
          .frame(width: 86, height: 30)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.72))
              .frame(width: 44, height: 22)
              .overlay(
                ConfigurationMirroredWaveform(
                  color: selected ? .accentColor : .secondary,
                  bars: 8,
                  height: 12
                )
              )
              .padding(.leading, -5)
          }
      case .none:
        Image(systemName: "eye.slash")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct ConfigurationSurfaceDemoRow: View {
  let choice: RecordingSurfaceChoice

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Preview")
          .font(.system(size: 13, weight: .semibold))
        Text(description)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      ConfigurationLiveSurfacePreview(choice: choice)
        .frame(width: 300, height: 146)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private var description: String {
    switch choice {
    case .classic:
      "A stable top overlay with waveform and the current transcript line."
    case .mini:
      "Compact feedback when you only need recording state and level."
    case .notch:
      "A notch-adjacent surface for laptops, drawn as our own Dynamic Island-style variant."
    case .cursor:
      "A small waveform beside the insertion point, backed by Accessibility caret bounds in the real app."
    case .input:
      "Attached to the focused input field when caret bounds are unavailable but the element frame is known."
    case .none:
      "No recording window. Sounds and menu-bar state carry the feedback."
    }
  }
}

private struct ConfigurationLiveSurfacePreview: View {
  let choice: RecordingSurfaceChoice

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.18))
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Circle().fill(.red.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.yellow.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.green.opacity(0.85)).frame(width: 7, height: 7)
        }
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.08))
          .frame(height: 88)
          .overlay(previewOverlay)
      }
      .padding(12)
    }
  }

  @ViewBuilder private var previewOverlay: some View {
    switch choice {
    case .classic:
      VStack(spacing: 10) {
        Capsule()
          .fill(.black.opacity(0.76))
          .frame(width: 190, height: 32)
          .overlay(
            HStack(spacing: 10) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 32, height: 18)
              Text("turn that into a cleaner note")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            }
          )
        Spacer()
      }
      .padding(.top, 8)
    case .mini:
      VStack {
        HStack {
          Spacer()
          RoundedRectangle(cornerRadius: 11)
            .fill(.black.opacity(0.76))
            .frame(width: 46, height: 34)
            .overlay(ConfigurationMirroredWaveform(color: .accentColor, bars: 9, height: 18))
        }
        Spacer()
      }
      .padding(10)
    case .notch:
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black)
          .frame(width: 76, height: 18)
        Capsule()
          .fill(.black.opacity(0.78))
          .frame(width: 168, height: 34)
          .overlay(
            HStack(spacing: 8) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 24, height: 16)
              Text("recording")
                .font(.system(size: 11, weight: .semibold))
            }
          )
        Spacer()
      }
    case .cursor:
      ZStack(alignment: .topLeading) {
        Text("Write the summary here")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.top, 26)
          .padding(.leading, 46)
        Rectangle()
          .fill(.white.opacity(0.75))
          .frame(width: 1, height: 25)
          .padding(.top, 22)
          .padding(.leading, 74)
        Capsule()
          .fill(.black.opacity(0.82))
          .frame(width: 118, height: 26)
          .overlay(
            HStack(spacing: 7) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 9, height: 13)
              Text("capturing...")
                .font(.system(size: 10, weight: .semibold))
            }
          )
          .padding(.top, 5)
          .padding(.leading, 84)
      }
    case .input:
      VStack(spacing: 0) {
        Spacer()
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.28))
          .frame(width: 220, height: 32)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.82))
              .frame(width: 84, height: 24)
              .overlay(ConfigurationMirroredWaveform(color: .accentColor, bars: 14, height: 14))
              .offset(x: -8)
          }
        Spacer()
      }
    case .none:
      VStack(spacing: 8) {
        Image(systemName: "eye.slash")
          .font(.system(size: 20))
          .foregroundStyle(.secondary)
        Text("No overlay")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ConfigurationMirroredWaveform: View {
  var color: Color
  var bars: Int
  var height: CGFloat

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.08)) { context in
      let phase = context.date.timeIntervalSinceReferenceDate
      HStack(alignment: .center, spacing: 1.5) {
        ForEach(0..<bars, id: \.self) { index in
          let midpoint = Double(max(1, bars - 1)) / 2
          let centerDistance = abs(Double(index) - midpoint) / midpoint
          let envelope = 0.45 + 0.55 * (1 - centerDistance)
          let movement = 0.55 + 0.45 * abs(sin(phase * 3.2 + Double(index) * 0.42))
          let barHeight = max(3, height * envelope * movement)

          Capsule()
            .fill(color.opacity(0.72 + 0.26 * movement))
            .frame(width: 2, height: barHeight)
        }
      }
      .frame(height: height)
    }
  }
}
