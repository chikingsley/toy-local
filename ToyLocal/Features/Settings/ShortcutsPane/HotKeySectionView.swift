import SwiftUI
import ToyLocalCore

struct HotKeySectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Section("Push to Talk") {
      let hotKey = store.toyLocalSettings.hotkey
      let key = store.isSettingHotKey ? nil : hotKey.key
      let modifiers = store.isSettingHotKey ? store.currentModifiers : hotKey.modifiers

      VStack(spacing: 12) {
        // Hot key view
        Button {
          store.startSettingHotKey()
        } label: {
          HStack {
            Spacer()
            HotKeyView(modifiers: modifiers, key: key, isActive: store.isSettingHotKey)
              .animation(.spring(), value: key)
              .animation(.spring(), value: modifiers)
            Spacer()
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set recording hotkey")

        if !store.isSettingHotKey,
          hotKey.key == nil,
          !hotKey.modifiers.isEmpty
        {
          ModifierSideControls(
            modifiers: hotKey.modifiers
          ) { kind, side in store.setModifierSide(kind, side) }
          .transition(.opacity)
        }
      }

      // Double-tap toggle (for key+modifier combinations)
      if hotKey.key != nil {
        Label {
          Toggle("Use double-tap only", isOn: $store.toyLocalSettings.useDoubleTapOnly)
        } icon: {
          Image(systemName: "hand.tap")
        }
      }

      // Minimum key time (for modifier-only shortcuts)
      if store.toyLocalSettings.hotkey.key == nil {
        Label {
          Slider(value: $store.toyLocalSettings.minimumKeyTime, in: 0.0...2.0, step: 0.1) {
            Text("Ignore below \(store.toyLocalSettings.minimumKeyTime, specifier: "%.1f")s")
          }
        } icon: {
          Image(systemName: "clock")
        }
      }
    }
  }
}

private struct ModifierSideControls: View {
  var modifiers: Modifiers
  var onSelect: (Modifier.Kind, Modifier.Side) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(modifiers.kinds, id: \.self) { kind in
        if kind.supportsSideSelection {
          let binding = Binding<Modifier.Side>(
            get: { modifiers.side(for: kind) ?? .either },
            set: { onSelect(kind, $0) }
          )

          VStack(alignment: .leading, spacing: 4) {
            Text("\(kind.symbol) \(kind.displayName)")
              .settingsCaption()

            Picker("Modifier side", selection: binding) {
              ForEach(Modifier.Side.allCases, id: \.self) { side in
                Text(side.displayName)
                  .tag(side)
                  .disabled(!kind.supportsSideSelection && side != .either)
              }
            }
            .pickerStyle(.segmented)
          }
        }
      }
    }
  }
}

#Preview {
  Form {
    HotKeySectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
