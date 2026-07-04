import SwiftUI

enum TLIconTileStyle {
  case colored(Color)
  case muted
  case transparent
}

struct TLIconTile: View {
  let systemName: String
  let style: TLIconTileStyle
  var size: CGFloat = 18
  var isSelected = false
  var foregroundOverride: Color?

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: size * 0.62, weight: .semibold))
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
      .frame(width: size)
  }

  private var foreground: Color {
    if let foregroundOverride {
      return foregroundOverride
    }

    return switch style {
    case .colored:
      Color.white
    case .muted, .transparent:
      isSelected ? Color.primary : Color.secondary
    }
  }

  @ViewBuilder private var background: some View {
    switch style {
    case .colored(let color):
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .fill(color)
    case .muted:
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .fill(Color.primary.opacity(isSelected ? 0.16 : 0.08))
    case .transparent:
      Color.clear
    }
  }
}

struct TLIconButton: View {
  let systemName: String
  var style: TLIconTileStyle = .transparent
  var tileSize: CGFloat = 22
  var hitSize: CGFloat = 28
  var iconSize: CGFloat?
  var foreground: Color?
  var help: String = ""
  var action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      TLIconTile(
        systemName: systemName,
        style: resolvedStyle,
        size: tileSize,
        foregroundOverride: foreground
      )
      .font(.system(size: iconSize ?? tileSize * 0.62, weight: .semibold))
      .frame(width: hitSize, height: hitSize)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(help)
    .onHover { hovering = $0 }
  }

  private var resolvedStyle: TLIconTileStyle {
    switch style {
    case .transparent where hovering:
      .muted
    default:
      style
    }
  }
}
