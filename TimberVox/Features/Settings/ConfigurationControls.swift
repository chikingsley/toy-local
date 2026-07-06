import TimberVoxCore
import SwiftUI

enum ConfigurationRoute {
  case main, advanced
}

enum ConfigurationThemeChoice: String, CaseIterable, Identifiable {
  case automatic, light, dark

  var id: String { rawValue }

  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var preference: AppearancePreference {
    switch self {
    case .automatic: .automatic
    case .light: .light
    case .dark: .dark
    }
  }

  var label: String {
    switch self {
    case .automatic: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var assetName: String {
    switch self {
    case .automatic: "appearance-auto"
    case .light: "appearance-light"
    case .dark: "appearance-dark"
    }
  }
}

struct ConfigurationVisualRow<Content: View>: View {
  let title: String
  var subtitle = ""
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      content
        .frame(maxWidth: 420, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

struct ConfigurationVisualChoiceGroup<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      content
    }
  }
}

struct ConfigurationVisualChoice<Preview: View>: View {
  enum Size {
    case regular, large

    var previewSize: CGSize {
      switch self {
      case .regular: CGSize(width: 82, height: 58)
      case .large: CGSize(width: 118, height: 76)
      }
    }

    var columnWidth: CGFloat {
      switch self {
      case .regular: 84
      case .large: 118
      }
    }
  }

  var size: Size = .regular
  let label: String
  let selected: Bool
  let action: () -> Void
  @ViewBuilder var preview: Preview
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 6) {
      Button(action: action) {
        preview
          .frame(width: size.previewSize.width, height: size.previewSize.height)
          .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .strokeBorder(
                selected
                  ? Color.accentColor
                  : (hovering ? Color.primary.opacity(0.22) : TLTheme.borderStroke),
                lineWidth: selected ? 1.4 : 1
              )
          )
          .contentShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }

      Text(label)
        .font(.system(size: 11, weight: selected ? .semibold : .medium))
        .foregroundStyle(selected ? .primary : .secondary)
    }
    .frame(width: size.columnWidth)
  }
}

struct ConfigurationRecordingWindowRow<Content: View>: View {
  let title: String
  var subtitle = ""
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }

      content
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

struct ConfigurationThemeThumbnail: View {
  let choice: ConfigurationThemeChoice

  var body: some View {
    Image(choice.assetName)
      .resizable()
      .scaledToFill()
      .frame(width: 82, height: 58)
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

struct ConfigurationMenuRow<Value: Hashable & Sendable>: View {
  var icon: String?
  let title: String
  var hint = ""
  let options: [TLMenuOption<Value>]
  @Binding var selection: Value

  var body: some View {
    TLSettingsRow(icon: icon, title: title, hint: hint) {
      TLOptionMenu(
        selection: $selection,
        options: options
      )
    }
  }
}

struct ConfigurationHeaderPill: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .semibold))
      Text(text)
        .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 9)
    .frame(height: 28)
    .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: TLTheme.fieldRadius))
  }
}

struct ConfigurationPermissionPill: View {
  let name: String
  let granted: Bool

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .font(.system(size: 10))
        .foregroundStyle(granted ? Color(hex: Shadcn.green500) : Color(hex: Shadcn.orange400))
      Text(name)
        .font(.system(size: 11))
        .foregroundStyle(granted ? .secondary : .primary)
      if !granted {
        Text("Grant")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color(hex: Shadcn.orange400))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      granted ? TLTheme.fieldSurface : Color(hex: Shadcn.orange400).opacity(0.14),
      in: Capsule()
    )
  }
}
