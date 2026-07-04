import SwiftUI

enum TLDestination: Equatable {
  case tab(ActiveTab)
  case historyItem(String)
  case createMode
}

private struct TLNavigateKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable (TLDestination) -> Void = { _ in }
}

extension EnvironmentValues {
  var tlNavigate: @MainActor @Sendable (TLDestination) -> Void {
    get { self[TLNavigateKey.self] }
    set { self[TLNavigateKey.self] = newValue }
  }
}
