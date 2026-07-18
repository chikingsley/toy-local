import SwiftUI

/// The permissions section — the ui-prototype's Access tile grid: one tile
/// per permission with a status dot, plus a Ready summary when all granted.
/// Un-granted tiles are buttons that start that permission's grant flow.
struct SettingsAccessGrid: View {
  let permissions: PermissionCoordinator

  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      HStack {
        Text("Access")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        if allGranted {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
              .font(.system(size: 11, weight: .semibold))
            Text("Ready")
              .font(.system(size: 11, weight: .medium))
          }
          .foregroundStyle(.green)
        }
      }

      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3),
        spacing: AppSpacing.sm
      ) {
        SettingsAccessTile(
          icon: "mic",
          label: "Microphone",
          isGranted: permissions.microphoneStatus.isGranted,
          actionLabel: "Grant",
          isBusy: permissions.isRequestingMicrophone
        ) {
          Task { await permissions.grantMicrophone() }
        }

        SettingsAccessTile(
          icon: "accessibility",
          label: "Accessibility",
          isGranted: permissions.accessibilityStatus.isGranted,
          actionLabel: "Grant"
        ) {
          permissions.grantAccessibility()
        }

        SettingsAccessTile(
          icon: "speaker.wave.2",
          label: "System audio",
          isGranted: permissions.systemAudioStatus.isGranted,
          grantedLabel: "Confirmed",
          actionLabel: "Open Settings"
        ) {
          permissions.manageSystemAudioPermission()
        }
      }

      Text(
        "System audio is optional and independent. It shows Confirmed after a successful capture because macOS does not provide a preflight status API for Core Audio taps."
      )
      .font(.system(size: 11))
      .foregroundStyle(theme.mutedForeground)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var allGranted: Bool {
    permissions.microphoneStatus.isGranted
      && permissions.accessibilityStatus.isGranted
      && permissions.systemAudioStatus.isGranted
  }
}

private struct SettingsAccessTile: View {
  let icon: String
  let label: String
  let isGranted: Bool
  var grantedLabel = "Granted"
  let actionLabel: String
  var isBusy = false
  let action: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    Button(action: action) {
      SCCard(size: .sm) {
        SCCardContent {
          VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
              Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isGranted ? .green : theme.mutedForeground)
              Spacer()
              Circle()
                .fill(isGranted ? Color.green : theme.mutedForeground.opacity(0.35))
                .frame(width: 7, height: 7)
                .shadow(color: isGranted ? .green.opacity(0.6) : .clear, radius: 5)
            }

            Text(label)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(theme.foreground)

            Text(isGranted ? grantedLabel : actionLabel)
              .font(.system(size: 10.5))
              .foregroundStyle(isGranted ? theme.mutedForeground : theme.primary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isGranted || isBusy)
    .accessibilityLabel("\(label): \(isGranted ? grantedLabel : "not granted")")
  }
}
