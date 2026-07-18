import SwiftUI

/// A grouped settings card — the ui-prototype's `SettingsCard`: an optional
/// title and one-line description followed by composed content.
struct AppSettingsCard<Content: View>: View {
  let title: String?
  let description: String?
  private let content: Content

  init(
    _ title: String? = nil,
    description: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.description = description
    self.content = content()
  }

  var body: some View {
    SCCard(size: .sm) {
      VStack(alignment: .leading, spacing: AppSpacing.sm) {
        if title != nil || description != nil {
          SCCardHeader {
            if let title {
              SCCardTitle(title)
            }
            if let description {
              SCCardDescription(description)
            }
          }
        }
        SCCardContent {
          VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
          }
        }
      }
    }
  }
}

enum AppSettingsRowSize {
  case compact
  case regular

  var labelFont: Font {
    switch self {
    case .compact: .system(size: 13, weight: .medium)
    case .regular: .system(size: 14, weight: .semibold)
    }
  }

  var detailFont: Font {
    switch self {
    case .compact: .system(size: 11)
    case .regular: .caption
    }
  }

  var minimumHeight: CGFloat {
    switch self {
    case .compact: 28
    case .regular: 32
    }
  }
}

/// One settings row: label with an optional caption underneath, and whatever
/// control lives at the trailing edge (switch, select, shortcut recorder,
/// plain value text).
struct AppSettingsRow<Trailing: View>: View {
  let label: String
  let hint: String?
  let detail: String?
  let size: AppSettingsRowSize
  private let trailing: Trailing

  @Environment(\.theme) private var theme

  init(
    _ label: String,
    hint: String? = nil,
    detail: String? = nil,
    size: AppSettingsRowSize = .compact,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.label = label
    self.hint = hint
    self.detail = detail
    self.size = size
    self.trailing = trailing()
  }

  var body: some View {
    HStack(alignment: detail == nil ? .center : .top, spacing: AppSpacing.lg) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: AppSpacing.xs) {
          Text(label)
            .font(size.labelFont)

          if let hint {
            Image(systemName: "questionmark.circle")
              .font(.caption)
              .foregroundStyle(theme.mutedForeground)
              .help(hint)
          }
        }

        if let detail {
          Text(detail)
            .font(size.detailFont)
            .foregroundStyle(theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: AppSpacing.lg)
      trailing
    }
    .frame(minHeight: size.minimumHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// An info row: label on the left, a muted plain value on the right.
struct AppSettingsInfoRow: View {
  let label: String
  var detail: String?
  let value: String

  @Environment(\.theme) private var theme

  var body: some View {
    AppSettingsRow(label, detail: detail) {
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(theme.mutedForeground)
    }
  }
}
