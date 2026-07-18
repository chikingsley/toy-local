import AVFoundation
import ActivityKit
import AppIntents
import Foundation
import UIKit

struct AudioRecordingIntent: AppIntents.AudioRecordingIntent, LiveActivityIntent {
  static let title: LocalizedStringResource = "Record Dictation"
  static let description = IntentDescription(
    "Record in the background, transcribe with the active TimberVox mode, and return the finished text."
  )
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let defaults = TimberVoxNativeBridge.defaults
    defaults.set(TimberVoxNativeBridge.schemaVersion, forKey: "bridgeSchemaVersion")
    defaults.set(true, forKey: "shortcutAvailable")

    if defaults.bool(forKey: "sessionActive"),
      defaults.string(forKey: "requestedEntryPoint") == "shortcut",
      let requestId = defaults.string(forKey: "activeRequestId"),
      !requestId.isEmpty
    {
      TimberVoxNativeBridge.publishStopRequest()
      let text = try await waitForPublishedResult(requestId: requestId, defaults: defaults)
      await copyToClipboard(text)
      return .result(value: text, dialog: "Dictation ready")
    }

    let granted = await requestMicrophonePermission()
    guard granted else { throw TimberVoxShortcutError.microphonePermission }

    let requestId = "shortcut_\(UUID().uuidString.lowercased())"
    let resultId = "result_\(UUID().uuidString.lowercased())"
    let startedAt = Date()
    let mode = TimberVoxNativeModeSnapshot.active(from: defaults)
    let recordingURL = try recordingURL(requestId: requestId)
    let activity = try startActivity(requestId: requestId, startedAt: startedAt, mode: mode)

    publishRecordingState(
      defaults: defaults,
      recording: true,
      requestId: requestId
    )

    do {
      let recorder = try await MainActor.run {
        try TimberVoxAudioRecorder(url: recordingURL)
      }
      while defaults.bool(forKey: "recordingRequested"),
        Date().timeIntervalSince(startedAt) < 600
      {
        try await Task.sleep(nanoseconds: 150_000_000)
      }
      let duration = await MainActor.run { recorder.stop() }
      await updateActivity(activity, phase: "finishing")

      let client = try TimberVoxNativeAPIClient(defaults: defaults)
      let transcription = try await client.transcribe(
        recordingURL: recordingURL,
        mode: mode,
        requestId: requestId
      )
      let finalText = try await client.process(
        transcript: transcription.text,
        mode: mode
      )
      let endedAt = Date()
      let envelope = TimberVoxNativeResultEnvelope(
        artifactJSON: transcription.artifactJSON,
        createdAt: startedAt,
        durationMs: max(0, Int(duration * 1_000)),
        endedAt: endedAt,
        errorCode: nil,
        errorMessage: nil,
        finalText: finalText,
        mode: mode,
        rawText: transcription.text,
        recordingURI: recordingURL.absoluteString,
        requestId: requestId,
        resultId: resultId,
        schemaVersion: 1,
        startedAt: startedAt,
        status: finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? "no_speech" : "succeeded"
      )
      try publish(envelope: envelope, defaults: defaults)
      publishRecordingState(defaults: defaults, recording: false, requestId: requestId)
      await finishActivity(activity, phase: "complete")
      await copyToClipboard(finalText)
      return .result(value: finalText, dialog: "Dictation ready")
    } catch {
      let endedAt = Date()
      let envelope = TimberVoxNativeResultEnvelope(
        artifactJSON: nil,
        createdAt: startedAt,
        durationMs: max(0, Int(endedAt.timeIntervalSince(startedAt) * 1_000)),
        endedAt: endedAt,
        errorCode: "shortcut_recording_failed",
        errorMessage: error.localizedDescription,
        finalText: "",
        mode: mode,
        rawText: "",
        recordingURI: FileManager.default.fileExists(atPath: recordingURL.path)
          ? recordingURL.absoluteString : nil,
        requestId: requestId,
        resultId: resultId,
        schemaVersion: 1,
        startedAt: startedAt,
        status: "failed"
      )
      try? publish(envelope: envelope, defaults: defaults)
      publishRecordingState(defaults: defaults, recording: false, requestId: requestId)
      await finishActivity(activity, phase: "failed")
      throw error
    }
  }

  private func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  private func recordingURL(requestId: String) throws -> URL {
    guard
      let directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: TimberVoxNativeBridge.appGroup
      )
    else { throw TimberVoxShortcutError.appGroup }
    let recordings = directory.appendingPathComponent("ShortcutRecordings", isDirectory: true)
    try FileManager.default.createDirectory(
      at: recordings,
      withIntermediateDirectories: true
    )
    return recordings.appendingPathComponent("\(requestId).wav")
  }

  private func startActivity(
    requestId: String,
    startedAt: Date,
    mode: TimberVoxNativeModeSnapshot
  ) throws -> Activity<TimberVoxRecordingAttributes> {
    let attributes = TimberVoxRecordingAttributes(
      modeName: mode.name,
      requestId: requestId,
      startedAt: startedAt
    )
    return try Activity.request(
      attributes: attributes,
      content: ActivityContent(
        state: .init(phase: "recording"),
        staleDate: startedAt.addingTimeInterval(600)
      )
    )
  }

  private func updateActivity(
    _ activity: Activity<TimberVoxRecordingAttributes>,
    phase: String
  ) async {
    await activity.update(
      ActivityContent(state: .init(phase: phase), staleDate: nil)
    )
  }

  private func finishActivity(
    _ activity: Activity<TimberVoxRecordingAttributes>,
    phase: String
  ) async {
    await activity.end(
      ActivityContent(state: .init(phase: phase), staleDate: nil),
      dismissalPolicy: .after(Date().addingTimeInterval(8))
    )
  }

  private func publishRecordingState(
    defaults: UserDefaults,
    recording: Bool,
    requestId: String
  ) {
    defaults.set("shortcut", forKey: "requestedEntryPoint")
    defaults.set(requestId, forKey: "activeRequestId")
    defaults.set(requestId, forKey: "keyboardRequestId")
    defaults.set(recording, forKey: "sessionActive")
    defaults.set(recording, forKey: "recordingRequested")
    defaults.set(defaults.integer(forKey: "requestRevision") + 1, forKey: "requestRevision")
  }

  private func publish(
    envelope: TimberVoxNativeResultEnvelope,
    defaults: UserDefaults
  ) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(envelope)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TimberVoxShortcutError.resultEncoding
    }
    defaults.set(json, forKey: "nativeResultEnvelope")
    defaults.set(defaults.integer(forKey: "nativeResultRevision") + 1, forKey: "nativeResultRevision")
    defaults.set(envelope.resultId, forKey: "finalResultId")
    defaults.set(envelope.requestId, forKey: "finalRequestId")
    defaults.set(envelope.finalText, forKey: "finalTranscript")
    defaults.set(defaults.integer(forKey: "transcriptRevision") + 1, forKey: "transcriptRevision")
  }

  private func waitForPublishedResult(
    requestId: String,
    defaults: UserDefaults
  ) async throws -> String {
    let deadline = Date().addingTimeInterval(120)
    while Date() < deadline {
      if defaults.string(forKey: "finalRequestId") == requestId,
        let text = defaults.string(forKey: "finalTranscript")
      {
        return text
      }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    throw TimberVoxShortcutError.resultTimeout
  }

  private func copyToClipboard(_ text: String) async {
    await MainActor.run {
      UIPasteboard.general.string = text
    }
  }
}

struct TimberVoxAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AudioRecordingIntent(),
      phrases: [
        "Record with \(.applicationName)",
        "Start dictation with \(.applicationName)",
        "Stop dictation with \(.applicationName)",
      ],
      shortTitle: "Record Dictation",
      systemImageName: "waveform"
    )
  }
}

@MainActor
private final class TimberVoxAudioRecorder {
  private let recorder: AVAudioRecorder

  init(url: URL) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .record,
      mode: .measurement,
      options: [.allowBluetoothHFP, .overrideMutedMicrophoneInterruption]
    )
    try session.setActive(true)
    recorder = try AVAudioRecorder(
      url: url,
      settings: [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
      ]
    )
    recorder.prepareToRecord()
    guard recorder.record() else { throw TimberVoxShortcutError.recorderStart }
  }

  func stop() -> TimeInterval {
    let duration = recorder.currentTime
    recorder.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    return duration
  }
}

private struct TimberVoxNativeResultEnvelope: Codable {
  let artifactJSON: String?
  let createdAt: Date
  let durationMs: Int
  let endedAt: Date
  let errorCode: String?
  let errorMessage: String?
  let finalText: String
  let mode: TimberVoxNativeModeSnapshot
  let rawText: String
  let recordingURI: String?
  let requestId: String
  let resultId: String
  let schemaVersion: Int
  let startedAt: Date
  let status: String
}

private struct NativeTranscriptionResult {
  let artifactJSON: String
  let text: String
}

private struct TimberVoxNativeAPIClient {
  private let baseURL: URL
  private let credential: String
  private let session: URLSession

  init(defaults: UserDefaults) throws {
    let origin =
      defaults.string(forKey: "apiBaseURL")
      ?? "https://timbervox.peacockery.studio"
    guard let baseURL = URL(string: origin),
      let credential = defaults.string(forKey: "apiCredential"),
      !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw TimberVoxShortcutError.credential }
    self.baseURL = baseURL
    self.credential = credential
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 180
    session = URLSession(configuration: configuration)
  }

  func transcribe(
    recordingURL: URL,
    mode: TimberVoxNativeModeSnapshot,
    requestId: String
  ) async throws -> NativeTranscriptionResult {
    let audio = try Data(contentsOf: recordingURL)
    let reservation = try await jsonRequest(
      path: "/v1/uploads",
      method: "POST",
      body: [
        "content_type": "audio/wav",
        "filename": recordingURL.lastPathComponent,
        "size_bytes": audio.count,
      ]
    )
    guard let uploadId = reservation["upload_id"] as? String,
      let inputKey = reservation["input_key"] as? String,
      let transfer = reservation["transfer"] as? [String: Any],
      transfer["kind"] as? String == "single",
      let uploadURLString = transfer["url"] as? String,
      let uploadURL = URL(string: uploadURLString)
    else { throw TimberVoxShortcutError.uploadContract }

    var uploadRequest = URLRequest(url: uploadURL)
    uploadRequest.httpMethod = "PUT"
    uploadRequest.httpBody = audio
    if let headers = transfer["headers"] as? [String: String] {
      for (name, value) in headers { uploadRequest.setValue(value, forHTTPHeaderField: name) }
    }
    let (_, uploadResponse) = try await session.data(for: uploadRequest)
    try validate(uploadResponse, data: Data())

    _ = try await jsonRequest(
      path: "/v1/uploads/\(uploadId)/complete",
      method: "POST",
      body: ["parts": []]
    )

    var requestBody: [String: Any] = [
      "asr_model": mode.batchModelId,
      "diarize": mode.identifySpeakers,
      "input_key": inputKey,
      "sync": true,
    ]
    if let language = mode.language { requestBody["language"] = language }
    var job = try await jsonRequest(
      path: "/v1/transcriptions",
      method: "POST",
      body: requestBody,
      headers: ["Idempotency-Key": requestId]
    )
    if let jobId = job["job_id"] as? String {
      let deadline = Date().addingTimeInterval(120)
      while job["status"] as? String == "queued" || job["status"] as? String == "running" {
        guard Date() < deadline else { throw TimberVoxShortcutError.transcriptionTimeout }
        try await Task.sleep(nanoseconds: 300_000_000)
        job = try await jsonRequest(path: "/v1/jobs/\(jobId)", method: "GET")
      }
    }
    guard job["status"] as? String == "succeeded",
      let artifact = job["result"] as? [String: Any],
      let text = artifact["text"] as? String
    else {
      let message = job["error"] as? String ?? "The transcription job failed."
      throw TimberVoxShortcutError.provider(message)
    }
    let artifactData = try JSONSerialization.data(withJSONObject: artifact, options: [.sortedKeys])
    guard let artifactJSON = String(data: artifactData, encoding: .utf8) else {
      throw TimberVoxShortcutError.resultEncoding
    }
    return NativeTranscriptionResult(artifactJSON: artifactJSON, text: text)
  }

  func process(
    transcript: String,
    mode: TimberVoxNativeModeSnapshot
  ) async throws -> String {
    guard mode.presetKind != "voice",
      let processingModelId = mode.processingModelId,
      let instructions = mode.processingInstructions?.trimmingCharacters(
        in: .whitespacesAndNewlines
      ),
      !instructions.isEmpty
    else { return transcript }
    let response = try await jsonRequest(
      path: "/v1/text",
      method: "POST",
      body: [
        "messages": [
          ["content": instructions, "role": "system"],
          ["content": transcript, "role": "user"],
        ],
        "model": processingModelId,
        "temperature": 0,
      ]
    )
    guard response["outputType"] as? String == "text",
      let text = response["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw TimberVoxShortcutError.processingContract }
    return text
  }

  private func jsonRequest(
    path: String,
    method: String,
    body: [String: Any]? = nil,
    headers: [String: String] = [:]
  ) async throws -> [String: Any] {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw TimberVoxShortcutError.apiURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await session.data(for: request)
    try validate(response, data: data)
    guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw TimberVoxShortcutError.responseContract
    }
    return value
  }

  private func validate(_ response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      let detail = String(data: data, encoding: .utf8) ?? ""
      throw TimberVoxShortcutError.http(status, detail)
    }
  }
}

private enum TimberVoxShortcutError: LocalizedError {
  case apiURL
  case appGroup
  case credential
  case http(Int, String)
  case microphonePermission
  case processingContract
  case provider(String)
  case recorderStart
  case responseContract
  case resultEncoding
  case resultTimeout
  case transcriptionTimeout
  case uploadContract

  var errorDescription: String? {
    switch self {
    case .apiURL: "The TimberVox API address is invalid."
    case .appGroup: "The TimberVox shared container is unavailable."
    case .credential: "Open TimberVox once to activate this development build."
    case .http(let status, let detail): "TimberVox API error \(status): \(detail)"
    case .microphonePermission: "Allow microphone access for TimberVox in Settings."
    case .processingContract: "Text processing returned an invalid result."
    case .provider(let message): message
    case .recorderStart: "The microphone recorder could not start."
    case .responseContract: "The TimberVox API returned an invalid response."
    case .resultEncoding: "The dictation result could not be saved."
    case .resultTimeout: "The active dictation is still finishing."
    case .transcriptionTimeout: "The transcription took longer than two minutes."
    case .uploadContract: "The TimberVox upload route returned an invalid response."
    }
  }
}
