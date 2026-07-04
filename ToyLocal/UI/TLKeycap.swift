import SwiftUI

struct TLKeycap: View {
  let label: String
  var size: CGFloat = 26

  init(_ label: String, size: CGFloat = 26) {
    self.label = label
    self.size = size
  }

  var body: some View {
    Text(label)
      .font(.system(size: size * 0.46, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, label.count > 1 ? 7 : 0)
      .frame(minWidth: size)
      .frame(height: size)
      .background(
        RoundedRectangle(cornerRadius: size * 0.22)
          .fill(
            Color.black.mix(with: .white, by: 0.2)
              .shadow(.inner(color: .white.opacity(0.3), radius: 1, y: 1))
              .shadow(.inner(color: .white.opacity(0.1), radius: 4, y: 5))
              .shadow(.inner(color: .black.opacity(0.3), radius: 1, y: -2))
          )
      )
      .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
  }
}

struct TLShortcutRecorder: View {
  static let keySize: CGFloat = 26
  private static let keySpacing: CGFloat = 5
  static let chipSize = CGSize(
    width: keySize * 3 + keySpacing * 2,
    height: keySize
  )

  @Binding var keys: [String]
  var defaultKeys: [String] = []
  private let externalIsRecording: Binding<Bool>?
  private let onBeginRecording: (() -> Void)?
  private let onCancelRecording: (() -> Void)?
  private let onClear: (() -> Void)?
  private let onReset: (() -> Void)?

  @State private var localIsRecording = false
  @State private var priorKeys: [String] = []
  @State private var pulsing = false
  @State private var resetSpins = 0

  init(
    keys: Binding<[String]>,
    defaultKeys: [String] = [],
    isRecording: Binding<Bool>? = nil,
    onBeginRecording: (() -> Void)? = nil,
    onCancelRecording: (() -> Void)? = nil,
    onClear: (() -> Void)? = nil,
    onReset: (() -> Void)? = nil
  ) {
    _keys = keys
    self.defaultKeys = defaultKeys
    self.externalIsRecording = isRecording
    self.onBeginRecording = onBeginRecording
    self.onCancelRecording = onCancelRecording
    self.onClear = onClear
    self.onReset = onReset
  }

  private var isRecording: Bool {
    externalIsRecording?.wrappedValue ?? localIsRecording
  }

  private var chipShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: Self.keySize * 0.22)
  }

  var body: some View {
    HStack(spacing: 6) {
      if isRecording {
        cancelButton
        recordingChip
      } else if keys.isEmpty {
        recordPrompt
      } else {
        sideButton
        keycapCluster
      }
    }
    .frame(height: Self.chipSize.height)
    .animation(.easeInOut(duration: 0.15), value: isRecording)
    .animation(.easeInOut(duration: 0.15), value: keys.isEmpty)
  }

  private func beginRecording() {
    priorKeys = keys
    pulsing = false
    if let onBeginRecording {
      onBeginRecording()
    } else {
      localIsRecording = true
    }
  }

  private func cancelRecording() {
    if let onCancelRecording {
      onCancelRecording()
    } else {
      localIsRecording = false
      keys = priorKeys
    }
  }

  private var recordPrompt: some View {
    Button(action: beginRecording) {
      Text("Record shortcut")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Record shortcut")
  }

  private var keycapCluster: some View {
    Button(action: beginRecording) {
      HStack(spacing: Self.keySpacing) {
        ForEach(keys.indices, id: \.self) { index in
          TLKeycap(keys[index], size: Self.keySize)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Record shortcut")
  }

  @ViewBuilder private var sideButton: some View {
    if defaultKeys.isEmpty {
      Button {
        if let onClear {
          onClear()
        } else {
          keys = []
        }
      } label: {
        sideButtonLabel("xmark")
      }
      .buttonStyle(.plain)
      .help("Clear shortcut")
    } else {
      Button {
        resetSpins -= 1
        withAnimation(.easeInOut(duration: 0.15)) {
          if let onReset {
            onReset()
          } else {
            keys = defaultKeys
          }
        }
      } label: {
        sideButtonLabel("arrow.counterclockwise")
          .rotationEffect(.degrees(Double(resetSpins) * 360))
          .animation(.easeInOut(duration: 0.45), value: resetSpins)
      }
      .buttonStyle(.plain)
      .help("Reset to default")
    }
  }

  private var cancelButton: some View {
    Button {
      cancelRecording()
    } label: {
      sideButtonLabel("xmark")
    }
    .buttonStyle(.plain)
    .help("Cancel recording")
  }

  private func sideButtonLabel(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(width: 18, height: 22)
      .contentShape(Rectangle())
  }

  private var recordingChip: some View {
    Text("Recording…")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.accentColor)
      .frame(width: Self.chipSize.width, height: Self.chipSize.height)
      .background(Color.accentColor.opacity(pulsing ? 0.2 : 0.08), in: chipShape)
      .overlay(
        chipShape
          .strokeBorder(Color.accentColor.opacity(pulsing ? 0.65 : 0.25), lineWidth: 1)
      )
      .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
      .onAppear { pulsing = true }
      .onDisappear { pulsing = false }
  }
}

#Preview("Shortcut recorder states") {
  struct RecorderDemo: View {
    @State private var chord = ["⌥", "⇧", "K"]
    @State private var single = ["⌥"]
    @State private var escape = ["esc"]
    @State private var mouse: [String] = []

    var body: some View {
      VStack(alignment: .trailing, spacing: 14) {
        TLShortcutRecorder(keys: $chord, defaultKeys: ["⌥", "⇧", "K"])
        TLShortcutRecorder(keys: $single, defaultKeys: ["⌥"])
        TLShortcutRecorder(keys: $escape, defaultKeys: ["esc"])
        TLShortcutRecorder(keys: $mouse)
      }
      .padding(24)
    }
  }
  return RecorderDemo()
    .background(Color(white: 0.12))
}
