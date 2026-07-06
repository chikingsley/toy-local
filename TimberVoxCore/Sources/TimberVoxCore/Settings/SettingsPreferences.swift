import Foundation

public enum AppearancePreference: String, Codable, CaseIterable, Sendable {
  case automatic
  case light
  case dark

  public var displayName: String {
    switch self {
    case .automatic: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}

public enum RecordingRetention: String, Codable, CaseIterable, Sendable {
  case forever
  case oneYear
  case sixMonths
  case oneMonth
  case oneWeek

  public var displayName: String {
    switch self {
    case .forever: "Forever"
    case .oneYear: "One year"
    case .sixMonths: "Six months"
    case .oneMonth: "One month"
    case .oneWeek: "One week"
    }
  }

  public func cutoffDate(from now: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .forever:
      nil
    case .oneYear:
      calendar.date(byAdding: .year, value: -1, to: now)
    case .sixMonths:
      calendar.date(byAdding: .month, value: -6, to: now)
    case .oneMonth:
      calendar.date(byAdding: .month, value: -1, to: now)
    case .oneWeek:
      calendar.date(byAdding: .day, value: -7, to: now)
    }
  }
}

public enum ClipboardRestoreBehavior: String, Codable, CaseIterable, Sendable {
  case defaultBehavior
  case restore
  case bypass

  public var displayName: String {
    switch self {
    case .defaultBehavior: "Default"
    case .restore: "Restore"
    case .bypass: "Bypass"
    }
  }
}

public enum SoundEffectsStyle: String, Codable, CaseIterable, Sendable {
  case classic
  case standard
  case off

  public var displayName: String {
    switch self {
    case .classic: "Classic"
    case .standard: "Default"
    case .off: "Off"
    }
  }
}
