import Foundation

enum DeepLinkCommand: Equatable {
  case settings
  case permissions
  case recordToggle
  case debugState
  case debugCheckPermissions
  case debugShowOnboarding
  case debugDownloadModel(String)
  case debugTranscribeFile(model: String, path: String)
  case debugTextTransform(text: String, mode: String?, model: String?, customInstructions: String?)
  case debugQuit
}

enum DeepLinkRouter {
  static let publicScheme = "timbervox"
  static let debugScheme = "timbervox-debug"

  static func command(for url: URL) -> DeepLinkCommand? {
    guard let scheme = url.scheme?.lowercased() else { return nil }
    let action = normalizedAction(from: url)

    switch scheme {
    case publicScheme:
      switch action {
      case "settings":
        return .settings
      case "permissions", "onboarding":
        return .permissions
      case "record-toggle", "record", "toggle-recording":
        return .recordToggle
      default:
        return nil
      }

    case debugScheme:
      return debugCommand(action: action, url: url)

    default:
      return nil
    }
  }

  private static func debugCommand(action: String, url: URL) -> DeepLinkCommand? {
    switch action {
    case "state":
      return .debugState
    case "check-permissions":
      return .debugCheckPermissions
    case "show-onboarding", "permissions":
      return .debugShowOnboarding
    case "download-model":
      guard let model = queryValue("model", from: url), !model.isEmpty else {
        return nil
      }
      return .debugDownloadModel(model)
    case "transcribe-file":
      guard
        let model = queryValue("model", from: url), !model.isEmpty,
        let path = queryValue("path", from: url), !path.isEmpty
      else {
        return nil
      }
      return .debugTranscribeFile(model: model, path: path)
    case "text-transform":
      guard let text = queryValue("text", from: url), !text.isEmpty else {
        return nil
      }
      return .debugTextTransform(
        text: text,
        mode: queryValue("mode", from: url),
        model: queryValue("model", from: url),
        customInstructions: queryValue("customInstructions", from: url)
          ?? queryValue("custom-instructions", from: url)
          ?? queryValue("instructions", from: url)
      )
    case "quit":
      return .debugQuit
    default:
      return nil
    }
  }

  private static func normalizedAction(from url: URL) -> String {
    let host = url.host(percentEncoded: false) ?? ""
    let path = url.path(percentEncoded: false)
      .split(separator: "/")
      .map(String.init)
      .joined(separator: "/")

    if !host.isEmpty, !path.isEmpty {
      return "\(host)/\(path)".lowercased()
    }
    if !host.isEmpty {
      return host.lowercased()
    }
    return path.lowercased()
  }

  private static func queryValue(_ name: String, from url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first { $0.name == name }?
      .value
  }
}
