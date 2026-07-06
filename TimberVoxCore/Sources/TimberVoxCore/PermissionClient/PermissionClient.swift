import Foundation

/// A client for managing system permissions in a composable way.
///
/// This client provides a unified interface for checking permission status, requesting permissions,
/// and monitoring app activation events to reactively update permission state.
public protocol PermissionClient: Sendable {
  /// Check the current microphone permission status.
  func microphoneStatus() async -> PermissionStatus

  /// Check the current accessibility permission status (synchronous).
  func accessibilityStatus() -> PermissionStatus

  /// Check the current screen recording permission status (synchronous).
  func screenCaptureStatus() -> PermissionStatus

  /// Request microphone permission from the user.
  func requestMicrophone() async -> Bool

  /// Request accessibility permission from the user.
  func requestAccessibility() async

  /// Request screen recording permission from the user.
  func requestScreenCapture() async -> Bool

  /// Open System Settings to the microphone privacy panel.
  func openMicrophoneSettings() async

  /// Open System Settings to the accessibility privacy panel.
  func openAccessibilitySettings() async

  /// Open System Settings to the screen recording privacy panel.
  func openScreenCaptureSettings() async

  /// Open System Settings to the system audio capture privacy panel.
  func openSystemAudioCaptureSettings() async

  /// Open System Settings to the automation privacy panel.
  func openAutomationSettings() async

  /// Observe app activation events.
  func observeAppActivation() -> AsyncStream<AppActivation>
}
