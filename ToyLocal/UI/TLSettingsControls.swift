import SwiftUI

enum TLMicrophoneSource {
  static let devices = ["Logitech BRIO (Default)", "MacBook Air Microphone", "RØDE Connect System"]
}

struct TLHeaderMicrophoneMenu: View {
  @Binding var selection: String
  var options = TLMicrophoneSource.devices.map {
    TLMenuOption(value: $0, label: $0, systemImage: "headphones")
  }

  var body: some View {
    TLOptionMenu(
      selection: $selection,
      options: options,
      width: TLHeaderMicrophoneMenuMetrics.width,
      panelWidth: TLHeaderMicrophoneMenuMetrics.panelWidth
    )
    .fixedSize()
  }
}

private enum TLHeaderMicrophoneMenuMetrics {
  static let width: CGFloat = 230
  static let panelWidth: CGFloat = 262
}

struct TLSettingsRow<Trailing: View>: View {
  var icon: String?
  let title: String
  var subtitle = ""
  var hint = ""
  var height: CGFloat = 50
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(spacing: 8) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .frame(width: 20)
          .padding(.trailing, 4)
      }
      label
        .frame(maxWidth: .infinity, alignment: .leading)
      trailing
        .fixedSize()
    }
    .padding(.horizontal, 16)
    .frame(height: height)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var label: some View {
    if subtitle.isEmpty {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        if !hint.isEmpty {
          TLInfoHint(hint)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }
}

struct TLDisclosureRow: View {
  let title: String
  @Binding var isOpen: Bool

  var body: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.16)) {
        isOpen.toggle()
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(isOpen ? 90 : 0))
        Text(title)
          .font(.system(size: 13, weight: .semibold))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct TLDestructiveRow: View {
  let title: String
  var systemImage = "trash"
  var action: () -> Void

  var body: some View {
    Button(role: .destructive, action: action) {
      HStack {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
      }
      .foregroundStyle(.red.opacity(0.9))
      .padding(.horizontal, 16)
      .frame(height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct TLActionPill: View {
  let title: String
  var action: () -> Void = {}

  var body: some View {
    Button(title, action: action)
      .font(.system(size: 12, weight: .semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: 8))
      .buttonStyle(.plain)
  }
}
