import Foundation

actor TimberVoxNativeRealtimeClient {
  typealias PartialHandler = @Sendable (String) async -> Void

  private let baseURL: URL
  private let credential: String
  private let partialHandler: PartialHandler
  private let session: URLSession

  private var committedSegments: [String] = []
  private var deltaTranscript = ""
  private var interimTranscript = ""
  private var lastSequence = -1
  private var receiveTask: Task<Void, Never>?
  private var sessionID: String?
  private var task: URLSessionWebSocketTask?
  private var terminalReceived = false

  init(defaults: UserDefaults, partialHandler: @escaping PartialHandler) throws {
    let origin = defaults.string(forKey: "apiBaseURL") ?? "https://voice.peacockery.studio"
    guard let baseURL = URL(string: origin),
      let credential = defaults.string(forKey: "apiCredential"),
      !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw TimberVoxNativeRealtimeError.configuration }

    self.baseURL = baseURL
    self.credential = credential
    self.partialHandler = partialHandler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 180
    session = URLSession(configuration: configuration)
  }

  func connect(mode: TimberVoxNativeModeSnapshot) async throws {
    guard !mode.realtimeModel.isEmpty else {
      throw TimberVoxNativeRealtimeError.configuration
    }
    let request = try makeRequest(mode: mode)
    let task = session.webSocketTask(with: request)
    self.task = task
    task.resume()

    let firstMessage = try await task.receive()
    guard case .string(let text) = firstMessage else {
      throw TimberVoxNativeRealtimeError.unsupportedMessage
    }
    let first = try Self.parse(text)
    guard first.type == "session.started" else {
      throw TimberVoxNativeRealtimeError.malformedEvent(
        "The first realtime event was not session.started."
      )
    }
    let sessionID = first.sessionID
    try accept(event: first, expectedSessionID: sessionID)
    self.sessionID = sessionID
    receiveTask = Task { [weak self] in
      await self?.receiveLoop(task: task)
    }
  }

  func sendPCM(_ data: Data) async {
    guard !data.isEmpty, let task, !terminalReceived else { return }
    do {
      try await task.send(.data(data))
    } catch {
      await recoverAfterDisconnect()
    }
  }

  func finish(finalPCM: Data?) async {
    if let finalPCM { await sendPCM(finalPCM) }
    guard let task, !terminalReceived else { return }
    do {
      try await task.send(.string(#"{"type":"close"}"#))
    } catch {
      await recoverAfterDisconnect()
    }
  }

  func cancel() {
    receiveTask?.cancel()
    receiveTask = nil
    task?.cancel(with: .normalClosure, reason: nil)
    task = nil
  }

  private func receiveLoop(task: URLSessionWebSocketTask) async {
    while !Task.isCancelled, !terminalReceived {
      do {
        let message = try await task.receive()
        guard case .string(let text) = message else {
          throw TimberVoxNativeRealtimeError.unsupportedMessage
        }
        let event = try Self.parse(text)
        try accept(event: event, expectedSessionID: sessionID)
      } catch {
        await recoverAfterDisconnect()
        return
      }
    }
  }

  private func accept(
    event: TimberVoxNativeRealtimeEvent,
    expectedSessionID: String?
  ) throws {
    if let expectedSessionID, event.sessionID != expectedSessionID {
      throw TimberVoxNativeRealtimeError.malformedEvent(
        "The realtime session identifier changed."
      )
    }
    guard event.sequence > lastSequence else { return }
    lastSequence = event.sequence

    switch event.type {
    case "transcript.interim":
      interimTranscript = event.text ?? ""
      publishVisibleTranscript()
    case "transcript.delta":
      deltaTranscript += event.text ?? ""
      publishVisibleTranscript()
    case "transcript.committed":
      let cleaned = (event.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      if !cleaned.isEmpty, committedSegments.last != cleaned {
        committedSegments.append(cleaned)
      }
      interimTranscript = ""
      deltaTranscript = ""
      publishVisibleTranscript()
    case "session.completed", "session.failed":
      terminalReceived = true
      if let finalText = event.finalText?.trimmingCharacters(in: .whitespacesAndNewlines),
        !finalText.isEmpty
      {
        Task { await partialHandler(finalText) }
      }
      task?.cancel(with: .normalClosure, reason: nil)
      task = nil
    default:
      break
    }
  }

  private func publishVisibleTranscript() {
    let stable = committedSegments.joined(separator: " ")
    let unstable = interimTranscript.isEmpty ? deltaTranscript : interimTranscript
    let text = [stable, unstable]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    Task { await partialHandler(text) }
  }

  private func recoverAfterDisconnect() async {
    guard !terminalReceived, let sessionID else { return }
    for attempt in 0..<8 {
      do {
        let event = try await recover(sessionID: sessionID)
        try accept(event: event, expectedSessionID: sessionID)
        return
      } catch {
        if attempt < 7 { try? await Task.sleep(for: .milliseconds(500)) }
      }
    }
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
  }

  private func recover(sessionID: String) async throws -> TimberVoxNativeRealtimeEvent {
    let escaped = sessionID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionID
    let url = baseURL.appending(path: "v1/realtime/sessions/\(escaped)")
    var request = URLRequest(url: url)
    request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
      let text = String(data: data, encoding: .utf8)
    else { throw TimberVoxNativeRealtimeError.recovery }
    let event = try Self.parse(text)
    guard event.type == "session.completed" || event.type == "session.failed" else {
      throw TimberVoxNativeRealtimeError.recovery
    }
    return event
  }

  private func makeRequest(mode: TimberVoxNativeModeSnapshot) throws -> URLRequest {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw TimberVoxNativeRealtimeError.configuration
    }
    components.scheme = components.scheme == "https" ? "wss" : "ws"
    components.path = "/v1/realtime"
    components.queryItems = [
      URLQueryItem(name: "channels", value: "1"),
      URLQueryItem(name: "diarize", value: mode.identifySpeakers ? "true" : "false"),
      URLQueryItem(name: "dictation", value: "true"),
      URLQueryItem(name: "encoding", value: "linear16"),
      URLQueryItem(name: "interim_results", value: "true"),
      URLQueryItem(name: "model", value: mode.realtimeModel),
      URLQueryItem(name: "punctuate", value: "true"),
      URLQueryItem(name: "sample_rate", value: "16000"),
      URLQueryItem(name: "target_streaming_delay_ms", value: "200"),
    ]
    if let language = mode.language {
      components.queryItems?.append(URLQueryItem(name: "language", value: language))
    }
    guard let url = components.url else {
      throw TimberVoxNativeRealtimeError.configuration
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
    return request
  }

  private static func parse(_ text: String) throws -> TimberVoxNativeRealtimeEvent {
    guard let data = text.data(using: .utf8),
      let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let type = value["type"] as? String,
      let sequence = value["sequence"] as? Int,
      let sessionID = value["session_id"] as? String,
      !sessionID.isEmpty
    else {
      throw TimberVoxNativeRealtimeError.malformedEvent(
        "The realtime event is incomplete."
      )
    }
    guard value["protocol_version"] as? Int == 1 else {
      throw TimberVoxNativeRealtimeError.malformedEvent(
        "The realtime protocol version is unsupported."
      )
    }
    let transcriptTypes = ["transcript.interim", "transcript.delta", "transcript.committed"]
    if transcriptTypes.contains(type), !(value["text"] is String) {
      throw TimberVoxNativeRealtimeError.malformedEvent(
        "The realtime transcript event has no text."
      )
    }
    let result = value["result"] as? [String: Any]
    return TimberVoxNativeRealtimeEvent(
      finalText: result?["text"] as? String,
      sequence: sequence,
      sessionID: sessionID,
      text: value["text"] as? String,
      type: type
    )
  }
}

private struct TimberVoxNativeRealtimeEvent: Sendable {
  let finalText: String?
  let sequence: Int
  let sessionID: String
  let text: String?
  let type: String
}

private enum TimberVoxNativeRealtimeError: LocalizedError {
  case configuration
  case malformedEvent(String)
  case recovery
  case unsupportedMessage

  var errorDescription: String? {
    switch self {
    case .configuration: "Realtime transcription is not configured."
    case .malformedEvent(let message): message
    case .recovery: "The realtime session could not be recovered."
    case .unsupportedMessage: "The realtime service sent an unsupported message."
    }
  }
}
