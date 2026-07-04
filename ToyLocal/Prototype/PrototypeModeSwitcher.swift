import SwiftUI

struct PrototypeModeSwitcher: View {
  struct SwitcherMode: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
  }

  static let mockModes: [SwitcherMode] = [
    .init(icon: "bubble.left.fill", name: "Default"),
    .init(icon: "mic.fill", name: "Voice to text"),
    .init(icon: "envelope.fill", name: "Email"),
    .init(icon: "person.2.wave.2.fill", name: "Meeting Notes"),
  ]

  var activeIndex = 0
  @State private var highlighted = 0

  var body: some View {
    VStack(spacing: 5) {
      ForEach(Array(Self.mockModes.enumerated()), id: \.element.id) { index, mode in
        modeRow(index: index, mode: mode)
      }
      footer
    }
    .padding(7)
    .frame(width: 430)
    .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
  }

  private func modeRow(index: Int, mode: SwitcherMode) -> some View {
    HStack(spacing: 11) {
      Image(systemName: mode.icon)
        .font(.system(size: 13))
        .frame(width: 20)
        .foregroundStyle(index == highlighted ? .primary : .secondary)
      Text(mode.name)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(index == highlighted ? .primary : .secondary)
      Spacer()
      if index == activeIndex {
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.primary)
      } else {
        switcherKeyChip("\(index + 1)")
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(index == highlighted ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .onTapGesture { highlighted = index }
  }

  private var footer: some View {
    HStack(spacing: 6) {
      Image(systemName: "waveform")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
      switcherKeyChip("↑")
      switcherKeyChip("↓")
      Text("Select")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 8)
      switcherKeyChip("⏎")
      Text("Back")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 8)
      switcherKeyChip("^")
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
  }

  private func switcherKeyChip(_ label: String) -> some View {
    Text(label)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(width: 20, height: 20)
      .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
  }
}

#Preview("Mode Switcher") {
  ZStack {
    LinearGradient(
      colors: [Color(red: 0.16, green: 0.18, blue: 0.24), Color(red: 0.08, green: 0.09, blue: 0.12)],
      startPoint: .topLeading, endPoint: .bottomTrailing
    )
    PrototypeModeSwitcher()
  }
  .frame(width: 560, height: 420)
}
