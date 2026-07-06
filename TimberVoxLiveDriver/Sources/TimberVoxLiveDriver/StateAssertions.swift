import TimberVoxCore
import Foundation

struct StateExpectation: Decodable {
  var mainExperienceStarted: Bool?
  var visibleWindows: [String]?
  var permissions: PermissionExpectation?
}

struct PermissionExpectation: Decodable {
  var microphone: PermissionMatcher?
  var accessibility: PermissionMatcher?
  var screenCapture: PermissionMatcher?
}

enum PermissionMatcher: String, Decodable {
  case granted
  case denied
  case notDetermined
  case notGranted

  func matches(_ value: String) -> Bool {
    switch self {
    case .granted, .denied, .notDetermined:
      value == rawValue
    case .notGranted:
      value != PermissionMatcher.granted.rawValue
    }
  }
}

func assertState(_ snapshot: DebugStateSnapshot, matches expectation: StateExpectation) throws {
  if let expected = expectation.mainExperienceStarted,
    snapshot.mainExperienceStarted != expected
  {
    throw DriverError(
      "Expected mainExperienceStarted=\(expected), got \(snapshot.mainExperienceStarted)"
    )
  }

  if let expected = expectation.visibleWindows {
    let actual = snapshot.visibleWindows.sorted()
    let expected = expected.sorted()
    guard actual == expected else {
      throw DriverError("Expected visibleWindows=\(expected), got \(actual)")
    }
  }

  if let matcher = expectation.permissions?.microphone,
    !matcher.matches(snapshot.permissions.microphone)
  {
    throw DriverError(
      "Expected microphone permission \(matcher.rawValue), got \(snapshot.permissions.microphone)"
    )
  }

  if let matcher = expectation.permissions?.accessibility,
    !matcher.matches(snapshot.permissions.accessibility)
  {
    throw DriverError(
      "Expected accessibility permission \(matcher.rawValue), got \(snapshot.permissions.accessibility)"
    )
  }

  if let matcher = expectation.permissions?.screenCapture,
    !matcher.matches(snapshot.permissions.screenCapture)
  {
    throw DriverError(
      "Expected screenCapture permission \(matcher.rawValue), got \(snapshot.permissions.screenCapture)"
    )
  }
}
