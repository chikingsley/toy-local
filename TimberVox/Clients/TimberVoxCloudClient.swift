import TimberVoxCore
import Foundation

struct TimberVoxCloudClient {
  var baseURL: URL
  var bearerToken: String?
  var session: URLSession

  init(
    baseURL: URL,
    bearerToken: String? = nil,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.bearerToken = bearerToken
    self.session = session
  }

  func health() async throws -> TimberVoxCloudHealth {
    try await get(path: "/health")
  }

  func createUpload(filename: String, contentType: String) async throws -> TimberVoxCloudUpload {
    try await post(
      path: "/v1/uploads",
      body: CreateUploadRequest(filename: filename, contentType: contentType)
    )
  }

  func upload(data: Data, uploadID: String, contentType: String) async throws {
    var request = makeRequest(path: "/v1/uploads/\(uploadID)")
    request.httpMethod = "PUT"
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")

    let (_, response) = try await session.upload(for: request, from: data)
    try validate(response: response)
  }

  func upload(fileURL: URL, uploadID: String, contentType: String) async throws {
    let data = try Data(contentsOf: fileURL)
    try await upload(data: data, uploadID: uploadID, contentType: contentType)
  }

  func createTranscription(
    inputKey: String,
    asrModel: String,
    diarize: Bool? = nil,
    language: String? = nil,
    transform: TimberVoxCloudTextTransformRequest? = nil
  ) async throws -> TimberVoxCloudJob {
    try await post(
      path: "/v1/transcriptions",
      body: CreateTranscriptionRequest(
        inputKey: inputKey,
        asrModel: asrModel,
        diarize: diarize,
        language: language,
        transform: transform
      )
    )
  }

  func textTransform(
    model: String,
    messages: [TextMessage],
    temperature: Double? = nil
  ) async throws -> TimberVoxCloudTextTransformResponse {
    try await post(
      path: "/v1/text-transforms",
      body: TimberVoxCloudTextTransformRequest(
        model: model,
        messages: messages.map(TimberVoxCloudTextMessage.init),
        temperature: temperature
      )
    )
  }

  func job(id: String) async throws -> TimberVoxCloudJobStatus {
    try await get(path: "/v1/jobs/\(id)")
  }

  private func get<Response: Decodable>(path: String) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "GET"
    return try await performJSON(request)
  }

  private func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body
  ) async throws -> Response {
    var request = makeRequest(path: path)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try TimberVoxCloudCoders.encoder.encode(body)
    return try await performJSON(request)
  }

  private func performJSON<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await session.data(for: request)
    try validate(response: response)
    return try TimberVoxCloudCoders.decoder.decode(Response.self, from: data)
  }

  private func makeRequest(path: String) -> URLRequest {
    let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let bearerToken {
      request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  private func validate(response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TimberVoxCloudError.invalidResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw TimberVoxCloudError.httpStatus(httpResponse.statusCode)
    }
  }
}

enum TimberVoxCloudError: Error, Equatable {
  case invalidResponse
  case httpStatus(Int)
}

struct TimberVoxCloudHealth: Decodable, Equatable {
  var ok: Bool
  var service: String
}

struct TimberVoxCloudUpload: Decodable, Equatable {
  var uploadID: String
  var inputKey: String
  var uploadURL: String

  enum CodingKeys: String, CodingKey {
    case uploadID = "upload_id"
    case inputKey = "input_key"
    case uploadURL = "upload_url"
  }
}

struct TimberVoxCloudJob: Decodable, Equatable {
  var jobID: String
  var status: String

  enum CodingKeys: String, CodingKey {
    case jobID = "job_id"
    case status
  }
}

struct TimberVoxCloudJobStatus: Decodable, Equatable {
  var jobID: String
  var kind: String
  var status: String
  var inputKey: String?
  var result: TimberVoxCloudTranscriptionResult?
  var error: String?
  var createdAt: Date
  var updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case jobID = "job_id"
    case kind
    case status
    case inputKey = "input_key"
    case result
    case error
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

struct TimberVoxCloudTranscriptionResult: Decodable, Equatable {
  var asr: TimberVoxCloudAsrResult
  var rawTranscript: String?
  var transcript: String
  var transform: TimberVoxCloudTransformResult?
}

struct TimberVoxCloudAsrResult: Decodable, Equatable {
  var durationSeconds: Double?
  var language: String?
  var model: String
  var provider: String
  var providerLatencyMs: Int?
  var segments: [TimberVoxCloudTranscriptSegment]?
  var upstreamModel: String
}

struct TimberVoxCloudTranscriptSegment: Decodable, Equatable {
  var endSeconds: Double?
  var speaker: String?
  var startSeconds: Double?
  var text: String

  enum CodingKeys: String, CodingKey {
    case endSeconds
    case speaker
    case startSeconds
    case text
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.endSeconds = try container.decodeIfPresent(Double.self, forKey: .endSeconds)
    if let stringValue = try? container.decodeIfPresent(String.self, forKey: .speaker) {
      self.speaker = stringValue
    } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .speaker) {
      self.speaker = String(intValue)
    } else {
      self.speaker = nil
    }
    self.startSeconds = try container.decodeIfPresent(Double.self, forKey: .startSeconds)
    self.text = try container.decode(String.self, forKey: .text)
  }
}

struct TimberVoxCloudTransformResult: Decodable, Equatable {
  var finishReason: String
  var model: String
  var providerLatencyMs: Int
}

struct TimberVoxCloudTextTransformResponse: Decodable, Equatable {
  var finishReason: String
  var model: String
  var provider: String
  var text: String
  var upstreamModel: String
  var usage: TimberVoxCloudTextTransformUsage
}

struct TimberVoxCloudTextTransformUsage: Decodable, Equatable {
  var inputTokens: Int?
  var outputTokens: Int?
  var totalTokens: Int?
}

private struct CreateUploadRequest: Encodable {
  var filename: String
  var contentType: String
}

private struct CreateTranscriptionRequest: Encodable {
  var inputKey: String
  var asrModel: String
  var diarize: Bool?
  var language: String?
  var transform: TimberVoxCloudTextTransformRequest?
}

struct TimberVoxCloudTextTransformRequest: Encodable, Equatable {
  var model: String
  var messages: [TimberVoxCloudTextMessage]
  var temperature: Double?
}

struct TimberVoxCloudTextMessage: Encodable, Equatable {
  var role: String
  var content: String

  init(role: String, content: String) {
    self.role = role
    self.content = content
  }

  init(_ message: TextMessage) {
    self.role = message.role.rawValue
    self.content = message.content
  }
}

private enum TimberVoxCloudCoders {
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }()

  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
