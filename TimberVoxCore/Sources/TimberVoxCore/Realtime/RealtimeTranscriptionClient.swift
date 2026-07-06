import Foundation

public struct RealtimeSessionOptions: Sendable {
  public var model: String
  public var language: String?
  public var sampleRate: Int
  public var encoding: String
  public var interimResults: Bool
  public var punctuate: Bool

  public init(
    model: String,
    language: String? = nil,
    sampleRate: Int = 16_000,
    encoding: String = "linear16",
    interimResults: Bool = true,
    punctuate: Bool = true
  ) {
    self.model = model
    self.language = language
    self.sampleRate = sampleRate
    self.encoding = encoding
    self.interimResults = interimResults
    self.punctuate = punctuate
  }
}

public enum RealtimeClientError: Error, Equatable {
  case invalidBaseURL
  case notConnected
}

/// WebSocket client for the TimberVox Cloud `GET /v1/realtime` route, built on
/// `URLSessionWebSocketTask`. Binary frames carry audio; text frames carry JSON events.
public actor RealtimeTranscriptionClient {
  private let baseURL: URL
  private let bearerToken: String?
  private let urlSession: URLSession
  private var task: URLSessionWebSocketTask?
  private var receiveLoop: Task<Void, Never>?
  private var continuation: AsyncThrowingStream<RealtimeTranscriptionEvent, Error>.Continuation?

  public init(baseURL: URL, bearerToken: String? = nil, urlSession: URLSession = .shared) {
    self.baseURL = baseURL
    self.bearerToken = bearerToken
    self.urlSession = urlSession
  }

  public func connect(options: RealtimeSessionOptions) throws -> AsyncThrowingStream<RealtimeTranscriptionEvent, Error> {
    disconnect()

    let request = try makeRequest(options: options)
    let task = urlSession.webSocketTask(with: request)
    self.task = task

    let (stream, continuation) = AsyncThrowingStream<RealtimeTranscriptionEvent, Error>.makeStream()
    self.continuation = continuation
    task.resume()
    startReceiveLoop(task: task)
    return stream
  }

  public func sendAudio(_ data: Data) async throws {
    guard let task else { throw RealtimeClientError.notConnected }
    try await task.send(.data(data))
  }

  public func sendPCM(_ samples: [Float]) async throws {
    try await sendAudio(RealtimeAudioEncoder.linear16Data(from: samples))
  }

  public func requestClose() async throws {
    guard let task else { throw RealtimeClientError.notConnected }
    try await task.send(.string(#"{"type":"close"}"#))
  }

  public func disconnect() {
    receiveLoop?.cancel()
    receiveLoop = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
    continuation?.finish()
    continuation = nil
  }

  private func startReceiveLoop(task: URLSessionWebSocketTask) {
    receiveLoop = Task { [weak self] in
      while !Task.isCancelled {
        do {
          let message = try await task.receive()
          await self?.handle(message: message)
        } catch {
          await self?.finishStream(error: error)
          return
        }
      }
    }
  }

  private func handle(message: URLSessionWebSocketTask.Message) {
    switch message {
    case .string(let text):
      if let event = RealtimeEventParser.parse(text) {
        continuation?.yield(event)
        if event == .sessionEnded {
          finishStream(error: nil)
        }
      }
    case .data:
      break
    @unknown default:
      break
    }
  }

  private func finishStream(error: Error?) {
    if let error, !isNormalClosure(error) {
      continuation?.finish(throwing: error)
    } else {
      continuation?.finish()
    }
    continuation = nil
    receiveLoop?.cancel()
    receiveLoop = nil
    task = nil
  }

  private func isNormalClosure(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == NSPOSIXErrorDomain && nsError.code == 57
  }

  private func makeRequest(options: RealtimeSessionOptions) throws -> URLRequest {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw RealtimeClientError.invalidBaseURL
    }
    components.scheme = components.scheme == "https" ? "wss" : "ws"
    components.path = "/v1/realtime"

    var queryItems = [
      URLQueryItem(name: "model", value: options.model),
      URLQueryItem(name: "encoding", value: options.encoding),
      URLQueryItem(name: "sample_rate", value: String(options.sampleRate)),
      URLQueryItem(name: "interim_results", value: options.interimResults ? "true" : "false"),
      URLQueryItem(name: "punctuate", value: options.punctuate ? "true" : "false"),
    ]
    if let language = options.language {
      queryItems.append(URLQueryItem(name: "language", value: language))
    }
    components.queryItems = queryItems

    guard let url = components.url else {
      throw RealtimeClientError.invalidBaseURL
    }

    var request = URLRequest(url: url)
    if let bearerToken {
      request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }
}

public enum RealtimeAudioEncoder {
  public static func linear16Data(from samples: [Float]) -> Data {
    var data = Data(capacity: samples.count * MemoryLayout<Int16>.size)
    for sample in samples {
      let clamped = max(-1.0, min(1.0, sample))
      let value = Int16(clamped * Float(Int16.max))
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    return data
  }
}
