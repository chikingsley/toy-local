import SwiftUI

/// Live previews of the recording-indicator styles: each row renders the
/// actual pill at its real recording size with canned spectrum bars, so
/// styles are picked by look rather than by name.
struct SettingsIndicatorPreview: View {
  @Binding var styleRaw: String

  @Environment(\.theme) private var theme

  private static let sampleBars: [Float] = [
    0.18, 0.42, 0.65, 0.38, 0.72, 0.55, 0.83, 0.47,
    0.68, 0.35, 0.58, 0.76, 0.44, 0.62, 0.30, 0.51,
  ]

  var body: some View {
    VStack(spacing: AppSpacing.sm) {
      ForEach(IndicatorStyle.allCases) { style in
        previewRow(for: style)
      }
    }
  }

  private func previewRow(for style: IndicatorStyle) -> some View {
    let isSelected = styleRaw == style.rawValue
    return Button {
      styleRaw = style.rawValue
    } label: {
      HStack(spacing: AppSpacing.lg) {
        Text(style.label)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 72, alignment: .leading)

        Spacer(minLength: AppSpacing.md)

        pillMock(for: style)

        Spacer(minLength: AppSpacing.md)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 15))
          .foregroundStyle(isSelected ? theme.primary : theme.mutedForeground.opacity(0.5))
      }
      .padding(.horizontal, AppSpacing.md)
      .padding(.vertical, AppSpacing.sm)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
          .fill(isSelected ? theme.accent.opacity(0.6) : .clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
          .strokeBorder(isSelected ? theme.ring : theme.border, lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(style.label) indicator style")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder private func pillMock(for style: IndicatorStyle) -> some View {
    switch style {
    case .mini:
      pillSurface(width: 156, height: 36, cornerRadius: 18) {
        SpectrumBars(
          bars: Self.sampleBars,
          color: RecordingPillPalette.recordingRed,
          barWidth: 3,
          barSpacing: 2.5,
          maxBarHeight: 22,
          minBarHeight: 1.5
        )
        .frame(width: 116, height: 16)
      }
    case .large:
      pillSurface(width: 246, height: 88, cornerRadius: 12) {
        VStack(alignment: .leading, spacing: 8) {
          SpectrumBars(
            bars: Self.sampleBars,
            color: RecordingPillPalette.recordingRed,
            barWidth: 4,
            barSpacing: 3,
            maxBarHeight: 26,
            minBarHeight: 2
          )
          .frame(width: 190, height: 28)
          .frame(maxWidth: .infinity)

          VStack(alignment: .leading, spacing: 4) {
            transcriptLine(width: 180)
            transcriptLine(width: 122)
          }
        }
        .padding(.horizontal, 14)
      }
    case .compact:
      ZStack {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .fill(RecordingPillPalette.compactBlue)
          .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
        CompactSpectrumBars(bars: Self.sampleBars)
          .frame(width: 29, height: 6)
      }
      .frame(width: 53, height: 32)
    }
  }

  private func transcriptLine(width: CGFloat) -> some View {
    Capsule()
      .fill(Color.white.opacity(0.35))
      .frame(width: width, height: 4)
  }

  private func pillSurface(
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat,
    @ViewBuilder content: () -> some View
  ) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(RecordingPillPalette.pillSurface)
        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
      content()
    }
    .frame(width: width, height: height)
  }
}
