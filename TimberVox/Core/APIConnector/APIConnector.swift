import Foundation

enum APIConnectorError: LocalizedError {
  case configuration(String)
  case httpStatus(Int)
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .configuration(let message): message
    case .httpStatus(let code): "Server error (HTTP \(code))."
    case .invalidResponse: "The server response was not valid."
    }
  }

  var isTransientHTTPFailure: Bool {
    switch self {
    case .httpStatus(let code):
      [408, 425, 429, 500, 502, 503, 504].contains(code)
    default:
      false
    }
  }
}

enum APIConnectorKeyEncoding: Sendable {
  case camelCase
  case snakeCase
}

struct APIConnector: Sendable {
  static let labBaseURL = URL(string: "https://voice-lab.peacockery.studio")!
  static let productionBaseURL = URL(string: "https://voice.peacockery.studio")!

  static var defaultBaseURL: URL {
    #if DEBUG
      labBaseURL
    #else
      productionBaseURL
    #endif
  }

  var authorization: APIConnectorAuthorization = .shared
  var baseURL: URL
  var session: URLSession = .shared

  func get<Response: Decodable>(
    path: String,
    authorized: Bool = true
  ) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "GET"
    return try await performJSON(request, authorized: authorized)
  }

  func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body,
    keyEncoding: APIConnectorKeyEncoding = .snakeCase
  ) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try APIConnectorCoders.encode(body, keyEncoding: keyEncoding)
    return try await performJSON(request, authorized: true)
  }

  func postEventStream<Body: Encodable>(
    path: String,
    body: Body,
    keyEncoding: APIConnectorKeyEncoding = .snakeCase
  ) async throws -> URLSession.AsyncBytes {
    var request = makeRequest(path: path)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.httpBody = try APIConnectorCoders.encode(body, keyEncoding: keyEncoding)
    let prepared = try await prepare(request, authorized: true)
    let (bytes, response) = try await session.bytes(for: prepared)
    try validate(response)
    return bytes
  }

  func upload(
    fileAt fileURL: URL, to url: URL, headers: [String: String], timeout: TimeInterval
  ) async throws -> String? {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.timeoutInterval = timeout
    let (_, response) = try await session.upload(for: request, fromFile: fileURL)
    try validate(response)
    return (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
  }

  func upload(data: Data, to url: URL, headers: [String: String], timeout: TimeInterval) async throws -> String? {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.timeoutInterval = timeout
    let (_, response) = try await session.upload(for: request, from: data)
    try validate(response)
    return (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
  }

  private func performJSON<Response: Decodable>(
    _ request: URLRequest,
    authorized: Bool
  ) async throws -> Response {
    let prepared = try await prepare(request, authorized: authorized)
    let (data, response) = try await session.data(for: prepared)
    try validate(response)
    return try APIConnectorCoders.decode(Response.self, from: data)
  }

  private func prepare(
    _ request: URLRequest,
    authorized: Bool
  ) async throws -> URLRequest {
    guard authorized else { return request }
    var prepared = request
    let credential = try await authorization.credential()
    prepared.setValue(
      "Bearer \(credential)",
      forHTTPHeaderField: "Authorization"
    )
    return prepared
  }

  private func makeRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func validate(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIConnectorError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIConnectorError.httpStatus(httpResponse.statusCode)
    }
  }
}

enum APIConnectorCoders {
  static func encode<Value: Encodable>(
    _ value: Value,
    keyEncoding: APIConnectorKeyEncoding = .snakeCase
  ) throws -> Data {
    let encoder = TimberVoxJSONCoding.makeEncoder()
    if keyEncoding == .camelCase {
      encoder.keyEncodingStrategy = .useDefaultKeys
    }
    return try encoder.encode(value)
  }

  static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
    try TimberVoxJSONCoding.makeDecoder().decode(type, from: data)
  }
}
