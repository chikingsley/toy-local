import AppKit
import PermissionPilot
import PermissionPilotCore
import SwiftUI

struct PermissionOnboardingView: View {
  @ObservedObject var manager: PermissionManager
  let onFinish: () -> Void

  @State private var hasStarted = false

  private var isComplete: Bool {
    manager.allRequiredGranted
  }

  var body: some View {
    VStack(spacing: 0) {
      if hasStarted {
        permissionsStep
      } else {
        welcomeStep
      }
    }
    .frame(width: 680, height: 680)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("onboarding.root")
    .onAppear {
      manager.refresh()
    }
    .onChange(of: isComplete) { _, complete in
      guard complete else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        onFinish()
      }
    }
  }

  private var welcomeStep: some View {
    VStack(spacing: 22) {
      Spacer()

      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      VStack(spacing: 8) {
        Text("Set up \(AppBrand.name)")
          .font(.largeTitle.weight(.semibold))
          .multilineTextAlignment(.center)
        Text("Grant the permissions \(AppBrand.name) needs for dictation, context, and typing.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 420)
      }

      Button("Get Started") {
        hasStarted = true
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .padding(.top, 8)
      .accessibilityIdentifier("onboarding.getStarted")

      Spacer()
    }
    .padding(32)
  }

  private var permissionsStep: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Permissions")
          .font(.title.weight(.semibold))
        Text("Enable the required permissions, then continue setup.")
          .font(.body)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 10) {
        permissionRow(
          title: "Microphone",
          message: "Records your voice so \(AppBrand.name) can transcribe dictation locally.",
          systemImage: "mic.fill",
          status: manager.status(for: .microphone),
          actionTitle: microphoneActionTitle,
          action: requestMicrophone
        )

        permissionRow(
          title: "Accessibility",
          message: "Handles the global hotkey and places text in the active app.",
          systemImage: "accessibility",
          status: manager.status(for: .accessibility),
          actionTitle: "Allow Accessibility",
          action: requestAccessibility
        )

        permissionRow(
          title: "Screen Recording",
          message: "Captures visible context for Super and Custom prompt modes.",
          systemImage: "rectangle.on.rectangle",
          status: manager.status(for: .screenRecording),
          actionTitle: "Allow Screen Recording",
          action: requestScreenRecording
        )
      }

      if manager.status(for: .accessibility) != .granted {
        Label(
          "After enabling Accessibility in System Settings, return to \(AppBrand.name). This window will update automatically.",
          systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      HStack {
        Button("Refresh") {
          manager.refresh()
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("onboarding.refresh")
        Spacer()
        Button("Continue") {
          onFinish()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isComplete)
        .accessibilityIdentifier("onboarding.continue")
      }
    }
    .padding(32)
    .accessibilityIdentifier("onboarding.permissions")
  }

  private func permissionRow(
    title: String,
    message: String,
    systemImage: String,
    status: PermissionStatus?,
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: systemImage)
        .font(.title3)
        .foregroundStyle(.secondary)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.body.weight(.semibold))
        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      if status == .granted {
        Label("Granted", systemImage: "checkmark.circle.fill")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.green)
      } else {
        Button(actionTitle) {
          action()
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(permissionActionIdentifier(for: title))
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var microphoneActionTitle: String {
    manager.status(for: .microphone) == .denied ? "Open Microphone Settings" : "Allow Microphone"
  }

  private func permissionActionIdentifier(for title: String) -> String {
    switch title {
    case "Microphone":
      "onboarding.microphone.allow"
    case "Accessibility":
      "onboarding.accessibility.allow"
    case "Screen Recording":
      "onboarding.screenRecording.allow"
    default:
      "onboarding.permission.action"
    }
  }

  private func requestMicrophone() {
    manager.request(.microphone)
  }

  private func requestAccessibility() {
    manager.request(.accessibility)
  }

  private func requestScreenRecording() {
    manager.request(.screenRecording)
  }

}

#Preview("Welcome") {
  PermissionOnboardingView(
    manager: PermissionManager(
      required: [.microphone, .accessibility, .screenRecording],
      statuses: [
        .microphone: .notDetermined,
        .accessibility: .denied,
        .screenRecording: .denied,
      ]
    )
  ) {}
}

#Preview("Complete") {
  PermissionOnboardingView(
    manager: PermissionManager(
      required: [.microphone, .accessibility, .screenRecording],
      statuses: [
        .microphone: .granted,
        .accessibility: .granted,
        .screenRecording: .granted,
      ]
    )
  ) {}
}
