import Foundation

struct CloudTextMessage: Codable, Equatable, Sendable {
  enum Role: String, Codable, Sendable {
    case assistant
    case system
    case user
  }

  var content: String
  var role: Role

  init(content: String, role: Role) {
    self.content = content
    self.role = role
  }

  init(_ message: TextMessage) {
    content = message.content
    switch message.role {
    case .assistant:
      role = .assistant
    case .system:
      role = .system
    case .user:
      role = .user
    }
  }
}

struct CloudTextTransformOutcome: Decodable, Equatable, Sendable {
  var finishReason: String
  var model: String
  var provider: String
  var text: String
  var upstreamModel: String
  var usage: CloudTextUsage
}

struct CloudTextUsage: Decodable, Equatable, Sendable {
  var inputTokens: Int?
  var outputTokens: Int?
  var totalTokens: Int?
}

struct CloudTextTransformRequest: Encodable, Equatable, Sendable {
  var messages: [CloudTextMessage]
  var model: String
  var providerOptions: [String: [String: CloudJSONValue]]
  var temperature: Double?

  init(
    messages: [CloudTextMessage],
    model: String,
    providerOptions: [String: [String: CloudJSONValue]] = [:],
    temperature: Double? = nil
  ) {
    self.messages = messages
    self.model = model
    self.providerOptions = providerOptions
    self.temperature = temperature
  }
}

struct CloudTextTransformClient: Sendable {
  static let production = CloudTextTransformClient(baseURL: CloudHTTPClient.productionBaseURL)

  var api: CloudHTTPClient

  init(baseURL: URL, session: URLSession = .shared) {
    api = CloudHTTPClient(baseURL: baseURL, session: session)
  }

  func transform(
    messages: [CloudTextMessage],
    model: String,
    providerOptions: [String: [String: CloudJSONValue]] = [:],
    temperature: Double? = nil
  ) async throws -> CloudTextTransformOutcome {
    try await transform(
      request: CloudTextTransformRequest(
        messages: messages,
        model: model,
        providerOptions: providerOptions,
        temperature: temperature
      )
    )
  }

  func transform(request: CloudTextTransformRequest) async throws -> CloudTextTransformOutcome {
    try await api.post(path: "v1/text", body: request)
  }
}

enum CloudJSONValue: Codable, Equatable, Sendable {
  case array([CloudJSONValue])
  case bool(Bool)
  case null
  case number(Double)
  case object([String: CloudJSONValue])
  case string(String)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([CloudJSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: CloudJSONValue].self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    case .number(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    case .string(let value):
      try container.encode(value)
    }
  }
}
