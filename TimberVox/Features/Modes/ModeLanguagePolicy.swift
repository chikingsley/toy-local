import Foundation

enum ModeLanguagePolicy {
  static let automaticName = "Automatic"

  static func allowedLanguageNames(languages: [Language], supportedCodes: Set<String>) -> [String] {
    let names = languages.compactMap { language -> String? in
      guard let code = language.code else { return nil }
      guard !supportedCodes.isEmpty else { return language.name }
      return supportedCodes.contains(code) ? language.name : nil
    }
    return [automaticName] + names
  }

  static func isSupported(code: String?, supportedCodes: Set<String>) -> Bool {
    guard let code else { return true }
    guard !supportedCodes.isEmpty else { return true }
    return supportedCodes.contains(code)
  }
}
