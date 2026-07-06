import Foundation

public struct LanguageModelProviderID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public extension LanguageModelProviderID {
  static let anthropic = LanguageModelProviderID(rawValue: "anthropic")
  static let cerebras = LanguageModelProviderID(rawValue: "cerebras")
  static let deepseek = LanguageModelProviderID(rawValue: "deepseek")
  static let google = LanguageModelProviderID(rawValue: "google")
  static let groq = LanguageModelProviderID(rawValue: "groq")
  static let mistral = LanguageModelProviderID(rawValue: "mistral")
  static let openAI = LanguageModelProviderID(rawValue: "openai")
  static let zai = LanguageModelProviderID(rawValue: "zai")
}

public struct LanguageModelSpec: Codable, Equatable, Sendable {
  public let id: String
  public let displayName: String
  public let provider: LanguageModelProviderID
  public let endpoint: URL?
  public let docsURL: URL?
  public let upstreamModel: String?
  public let supportsJSONOutput: Bool

  public init(
    id: String,
    displayName: String,
    provider: LanguageModelProviderID,
    endpoint: URL? = nil,
    docsURL: URL? = nil,
    upstreamModel: String? = nil,
    supportsJSONOutput: Bool = false
  ) {
    self.id = id
    self.displayName = displayName
    self.provider = provider
    self.endpoint = endpoint
    self.docsURL = docsURL
    self.upstreamModel = upstreamModel
    self.supportsJSONOutput = supportsJSONOutput
  }
}

public enum TextMessageRole: String, Codable, Equatable, Sendable {
  case system
  case user
  case assistant
}

public struct TextMessage: Codable, Equatable, Sendable {
  public let role: TextMessageRole
  public let content: String

  public init(role: TextMessageRole, content: String) {
    self.role = role
    self.content = content
  }
}

public struct TextCompletionRequest: Codable, Equatable, Sendable {
  public let modelID: String
  public let messages: [TextMessage]
  public let temperature: Double?

  public init(modelID: String, messages: [TextMessage], temperature: Double? = nil) {
    self.modelID = modelID
    self.messages = messages
    self.temperature = temperature
  }
}

public struct TextCompletion: Codable, Equatable, Sendable {
  public let text: String
  public let providerID: LanguageModelProviderID
  public let modelID: String

  public init(text: String, providerID: LanguageModelProviderID, modelID: String) {
    self.text = text
    self.providerID = providerID
    self.modelID = modelID
  }
}

public protocol TextProvider: Sendable {
  var providerID: LanguageModelProviderID { get }
  var models: [LanguageModelSpec] { get }

  func complete(_ request: TextCompletionRequest) async throws -> TextCompletion
}
