import Foundation

/// A client for managing system permissions (microphone, accessibility) in a composable way.
///
/// This client provides a unified interface for checking permission status, requesting permissions,
/// and monitoring app activation events to reactively update permission state.
public protocol PermissionClient: Sendable {
  /// Check the current microphone permission status.
  func microphoneStatus() async -> PermissionStatus

  /// Check the current accessibility permission status (synchronous).
  func accessibilityStatus() -> PermissionStatus

  /// Check the current input monitoring permission status (synchronous).
  func inputMonitoringStatus() -> PermissionStatus

  /// Request microphone permission from the user.
  func requestMicrophone() async -> Bool

  /// Request accessibility permission from the user.
  func requestAccessibility() async

  /// Request input monitoring permission from the user.
  func requestInputMonitoring() async -> Bool

  /// Open System Settings to the microphone privacy panel.
  func openMicrophoneSettings() async

  /// Open System Settings to the accessibility privacy panel.
  func openAccessibilitySettings() async

  /// Open System Settings to the Input Monitoring privacy panel.
  func openInputMonitoringSettings() async

  /// Observe app activation events.
  func observeAppActivation() -> AsyncStream<AppActivation>
}
