import AVFoundation
import AppKit
import Observation

enum AppPermissionStatus: Equatable {
  case notDetermined
  case denied
  case restricted
  case granted

  var isGranted: Bool {
    self == .granted
  }
}

@MainActor
protocol PermissionClient {
  var microphoneStatus: AppPermissionStatus { get }
  var accessibilityStatus: AppPermissionStatus { get }
  var systemAudioStatus: AppPermissionStatus { get }

  func requestMicrophone() async
  func openMicrophoneSettings()
  func requestAccessibility()
  func openAccessibilitySettings()
  func openSystemAudioSettings()
}

@MainActor
struct LivePermissionClient: PermissionClient {
  var microphoneStatus: AppPermissionStatus {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    case .denied: .denied
    case .authorized: .granted
    @unknown default: .denied
    }
  }

  var accessibilityStatus: AppPermissionStatus {
    AccessibilityPermission.isTrusted ? .granted : .denied
  }

  var systemAudioStatus: AppPermissionStatus {
    UserDefaults.standard.bool(forKey: SystemAudioPermissionEvidence.successfulCaptureKey)
      ? .granted
      : .notDetermined
  }

  func requestMicrophone() async {
    _ = await AVCaptureDevice.requestAccess(for: .audio)
  }

  func openMicrophoneSettings() {
    openPrivacySettings(pane: "Privacy_Microphone")
  }

  func requestAccessibility() {
    AccessibilityPermission.requestPrompt()
  }

  func openAccessibilitySettings() {
    AccessibilityPermission.openSettings()
  }

  func openSystemAudioSettings() {
    openPrivacySettings(pane: "Privacy_AudioCapture")
  }

  private func openPrivacySettings(pane: String) {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }
}

@MainActor
@Observable
final class PermissionCoordinator {
  private(set) var microphoneStatus: AppPermissionStatus
  private(set) var accessibilityStatus: AppPermissionStatus
  private(set) var systemAudioStatus: AppPermissionStatus
  private(set) var isRequestingMicrophone = false

  @ObservationIgnored private let client: any PermissionClient

  var allRequiredPermissionsGranted: Bool {
    microphoneStatus.isGranted && accessibilityStatus.isGranted
  }

  init(client: any PermissionClient = LivePermissionClient()) {
    self.client = client
    microphoneStatus = client.microphoneStatus
    accessibilityStatus = client.accessibilityStatus
    systemAudioStatus = client.systemAudioStatus
  }

  func refresh() {
    microphoneStatus = client.microphoneStatus
    accessibilityStatus = client.accessibilityStatus
    systemAudioStatus = client.systemAudioStatus
  }

  func grantMicrophone() async {
    guard !isRequestingMicrophone else { return }

    switch client.microphoneStatus {
    case .notDetermined:
      isRequestingMicrophone = true
      await client.requestMicrophone()
      isRequestingMicrophone = false
    case .denied, .restricted:
      client.openMicrophoneSettings()
    case .granted:
      break
    }
    refresh()
  }

  func grantAccessibility() {
    guard !client.accessibilityStatus.isGranted else {
      refresh()
      return
    }

    client.requestAccessibility()
    if !client.accessibilityStatus.isGranted {
      client.openAccessibilitySettings()
    }
    refresh()
  }

  func manageSystemAudioPermission() {
    client.openSystemAudioSettings()
    refresh()
  }
}
