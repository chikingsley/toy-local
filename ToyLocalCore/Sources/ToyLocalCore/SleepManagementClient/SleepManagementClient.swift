/// Client for managing system sleep prevention during critical operations.
///
/// On macOS, this uses IOKit power assertions to prevent the display from sleeping
/// while operations like voice recording are in progress.
public protocol SleepManagementClient: Sendable {
  /// Prevent the system from sleeping.
  func preventSleep(reason: String) async

  /// Allow the system to sleep again by releasing any active assertion.
  func allowSleep() async
}
