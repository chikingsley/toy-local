import SwiftUI

enum TLModelDownloadState: Equatable {
  case downloaded
  case downloading(Double)
  case notDownloaded
  case cloud
}

struct ModelDownloadControl: View {
  let state: TLModelDownloadState
  var hovering = false
  var startDownload: () -> Void = {}
  var cancelDownload: () -> Void = {}
  var delete: () -> Void = {}

  private enum Metrics {
    static let compactButtonSize: CGFloat = 22
    static let buttonSize: CGFloat = 24
    static let compactCornerRadius: CGFloat = 5
    static let trashFontSize: CGFloat = 11
    static let progressFontSize: CGFloat = 6
    static let progressIconSize: CGFloat = 16
    static let downloadFontSize: CGFloat = 15
    static let cloudFontSize: CGFloat = 13
  }

  var body: some View {
    switch state {
    case .downloaded:
      Button(action: delete) {
        Image(systemName: "trash")
          .font(.system(size: Metrics.trashFontSize))
          .foregroundStyle(hovering ? TLTheme.destructive.opacity(0.9) : Color.secondary.opacity(0.7))
          .frame(width: Metrics.compactButtonSize, height: Metrics.compactButtonSize)
          .background(.primary.opacity(hovering ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: Metrics.compactCornerRadius))
      }
      .buttonStyle(.plain)
      .help("Delete model")
    case .downloading(let progress):
      Button(action: cancelDownload) {
        ZStack {
          if hovering {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: Metrics.progressIconSize))
              .foregroundStyle(.secondary)
          } else {
            TLProgressRing(progress: progress)
            Text(progress.formatted(.percent.precision(.fractionLength(0))))
              .font(.system(size: Metrics.progressFontSize, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
      }
      .buttonStyle(.plain)
      .help(hovering ? "Cancel download" : "Downloading...")
    case .notDownloaded:
      Button(action: startDownload) {
        Image(systemName: "arrow.down.circle")
          .font(.system(size: Metrics.downloadFontSize))
          .foregroundStyle(TLTheme.accentBlue)
          .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
      }
      .buttonStyle(.plain)
      .help("Download")
    case .cloud:
      Image(systemName: "cloud")
        .font(.system(size: Metrics.cloudFontSize))
        .foregroundStyle(.secondary)
        .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
        .help("Cloud model")
    }
  }
}

private struct TLProgressRing: View {
  let progress: Double

  private enum Metrics {
    static let size: CGFloat = 18
    static let lineWidth: CGFloat = 2
    static let rotationDegrees = -90.0
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.25), lineWidth: Metrics.lineWidth)
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(TLTheme.accentBlue, style: StrokeStyle(lineWidth: Metrics.lineWidth, lineCap: .round))
        .rotationEffect(.degrees(Metrics.rotationDegrees))
    }
    .frame(width: Metrics.size, height: Metrics.size)
  }
}
