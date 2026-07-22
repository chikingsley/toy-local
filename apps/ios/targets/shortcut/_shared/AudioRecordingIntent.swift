import AVFoundation
import ActivityKit
import AppIntents
import Foundation
import UIKit

struct AudioRecordingIntent: AppIntents.AudioRecordingIntent, LiveActivityIntent {
  static let title: LocalizedStringResource = "Toggle TimberVox Dictation"
  static let description = IntentDescription(
    "Start or stop a persistent TimberVox session. Finished text is delivered to the TimberVox keyboard and clipboard."
  )
  static let openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    let defaults = TimberVoxNativeBridge.defaults
    defaults.set(TimberVoxNativeBridge.schemaVersion, forKey: "bridgeSchemaVersion")
    defaults.set(true, forKey: "shortcutAvailable")

    if isLiveSession(defaults: defaults) {
      let requestId = defaults.string(forKey: "activeRequestId") ?? ""
      TimberVoxNativeBridge.publishSessionStopRequest()
      await TimberVoxBackgroundSession.shared.applyBridgeCommands()
      let text = try await waitForSessionStop(requestId: requestId, defaults: defaults)
      if !text.isEmpty { await copyToClipboard(text) }
      return .result()
    }

    clearStaleSession(defaults: defaults)

    let granted = await requestMicrophonePermission()
    guard granted else { throw TimberVoxShortcutError.microphonePermission }

    let requestId = "shortcut_\(UUID().uuidString.lowercased())"
    let resultId = "result_\(UUID().uuidString.lowercased())"
    let startedAt = Date()
    let mode = TimberVoxNativeModeSnapshot.active(from: defaults)
    let recordingURL = try recordingURL(requestId: requestId)
    // AudioRecordingIntent requires a Live Activity for the complete recording lifetime. iOS stops
    // capture if the activity cannot start, so this failure must remain explicit rather than being
    // swallowed and followed by a misleading "started" state.
    let activity = try startActivity(requestId: requestId, startedAt: startedAt, mode: mode)

    do {
      try await TimberVoxBackgroundSession.shared.start(
        activity: activity,
        initialCapture: .init(
          mode: mode,
          recordingURL: recordingURL,
          requestId: requestId,
          resultId: resultId,
          startedAt: startedAt
        )
      )
      return .result()
    } catch {
      await finishActivity(activity, phase: "failed")
      clearStaleSession(defaults: defaults)
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
        state: .init(
          audioLevels: Array(repeating: 0.08, count: 18),
          displayMode: liveActivityDisplayMode(defaults: TimberVoxNativeBridge.defaults),
          phase: "recording",
          partialTranscript: ""
        ),
        staleDate: nil
      )
    )
  }

  private func finishActivity(
    _ activity: Activity<TimberVoxRecordingAttributes>,
    phase: String
  ) async {
    await activity.end(
      ActivityContent(
        state: .init(
          audioLevels: [],
          displayMode: liveActivityDisplayMode(defaults: TimberVoxNativeBridge.defaults),
          phase: phase,
          partialTranscript: ""
        ),
        staleDate: nil
      ),
      dismissalPolicy: .immediate
    )
  }

  private func isLiveSession(defaults: UserDefaults) -> Bool {
    guard defaults.bool(forKey: "sessionActive") else { return false }
    let owner = defaults.string(forKey: "sessionOwner")
    guard owner == "native" || owner == "expo" else { return false }
    let heartbeat = defaults.double(forKey: "sessionHeartbeat")
    return heartbeat > 0 && Date().timeIntervalSince1970 - heartbeat < 5
  }

  private func clearStaleSession(defaults: UserDefaults) {
    defaults.set(false, forKey: "sessionActive")
    defaults.set(false, forKey: "sessionStopRequested")
    defaults.set(false, forKey: "recordingRequested")
    defaults.set("", forKey: "sessionOwner")
    defaults.set("off", forKey: "sessionPhase")
    defaults.set("", forKey: "activeRequestId")
    defaults.set("", forKey: "partialTranscript")
    defaults.set("", forKey: "partialTranscriptRequestId")
  }

  private func liveActivityDisplayMode(defaults: UserDefaults) -> String {
    defaults.string(forKey: "liveActivityDisplayMode") == "words" ? "words" : "waveform"
  }

  private func waitForSessionStop(
    requestId: String,
    defaults: UserDefaults
  ) async throws -> String {
    let deadline = Date().addingTimeInterval(120)
    while Date() < deadline {
      if !defaults.bool(forKey: "sessionActive") {
        if !requestId.isEmpty,
          defaults.string(forKey: "finalRequestId") == requestId
        {
          return defaults.string(forKey: "finalTranscript") ?? ""
        }
        if defaults.string(forKey: "sessionPhase") == "finalizing" {
          try await Task.sleep(nanoseconds: 200_000_000)
          continue
        }
        return ""
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

@MainActor
private final class TimberVoxBackgroundSession {
  struct InitialCapture {
    let mode: TimberVoxNativeModeSnapshot
    let recordingURL: URL
    let requestId: String
    let resultId: String
    let startedAt: Date
  }

  static let shared = TimberVoxBackgroundSession()

  private struct Capture {
    let entryPoint: String
    let mode: TimberVoxNativeModeSnapshot
    let recorder: TimberVoxAudioRecorder
    let realtimeClient: TimberVoxNativeRealtimeClient?
    let recordingURL: URL
    let requestId: String
    let resultId: String
    let startedAt: Date
  }

  private struct FinishedCapture: Sendable {
    let duration: TimeInterval
    let entryPoint: String
    let mode: TimberVoxNativeModeSnapshot
    let recordingURL: URL
    let requestId: String
    let resultId: String
    let startedAt: Date
  }

  private var activity: Activity<TimberVoxRecordingAttributes>?
  private var activityLevels = Array(repeating: 0.08, count: 18)
  private var capture: Capture?
  private var commandTask: Task<Void, Never>?
  private var lastActivityUpdate = Date.distantPast
  private var lastRequestRevision = 0
  private var processingCount = 0

  private init() {}

  func start(
    activity: Activity<TimberVoxRecordingAttributes>,
    initialCapture: InitialCapture
  ) async throws {
    guard commandTask == nil else { return }
    let defaults = TimberVoxNativeBridge.defaults
    let recorder = try TimberVoxAudioRecorder(url: initialCapture.recordingURL)
    let realtimeClient = await makeRealtimeClient(
      defaults: defaults,
      mode: initialCapture.mode,
      requestId: initialCapture.requestId
    )
    capture = Capture(
      entryPoint: "shortcut",
      mode: initialCapture.mode,
      recorder: recorder,
      realtimeClient: realtimeClient,
      recordingURL: initialCapture.recordingURL,
      requestId: initialCapture.requestId,
      resultId: initialCapture.resultId,
      startedAt: initialCapture.startedAt
    )
    self.activity = activity
    activityLevels = Array(repeating: 0.08, count: 18)
    lastRequestRevision = defaults.integer(forKey: "requestRevision") + 1
    defaults.set(TimberVoxNativeBridge.schemaVersion, forKey: "bridgeSchemaVersion")
    defaults.set(true, forKey: "sessionActive")
    defaults.set("native", forKey: "sessionOwner")
    defaults.set(false, forKey: "sessionStopRequested")
    defaults.set("recording", forKey: "sessionPhase")
    defaults.set("", forKey: "sessionErrorMessage")
    defaults.set(Date().timeIntervalSince1970, forKey: "sessionHeartbeat")
    defaults.set("shortcut", forKey: "requestedEntryPoint")
    defaults.set(initialCapture.requestId, forKey: "activeRequestId")
    defaults.set(initialCapture.requestId, forKey: "keyboardRequestId")
    defaults.set("", forKey: "partialTranscript")
    defaults.set(initialCapture.requestId, forKey: "partialTranscriptRequestId")
    defaults.set(true, forKey: "recordingRequested")
    defaults.set(lastRequestRevision, forKey: "requestRevision")
    defaults.synchronize()
    await updateActivity(phase: "recording", force: true)
    commandTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { break }
        await self?.applyBridgeCommands()
      }
    }
  }

  func applyBridgeCommands() async {
    guard commandTask != nil else { return }
    let defaults = TimberVoxNativeBridge.defaults
    defaults.synchronize()
    defaults.set(Date().timeIntervalSince1970, forKey: "sessionHeartbeat")

    await streamCaptureSnapshot()

    if defaults.bool(forKey: "sessionStopRequested") {
      await stopSession()
      return
    }

    let revision = defaults.integer(forKey: "requestRevision")
    guard revision != lastRequestRevision else { return }
    lastRequestRevision = revision
    if defaults.bool(forKey: "recordingRequested") {
      if capture == nil { await startBridgeCapture(defaults: defaults) }
    } else if capture != nil {
      await finishCapture(keepSessionWarm: true)
    }
  }

  private func startBridgeCapture(defaults: UserDefaults) async {
    let requestId =
      defaults.string(forKey: "activeRequestId")?.nonempty
      ?? defaults.string(forKey: "keyboardRequestId")?.nonempty
      ?? "native_\(UUID().uuidString.lowercased())"
    let resultId = "result_\(UUID().uuidString.lowercased())"
    let startedAt = Date()
    do {
      let url = try Self.recordingURL(requestId: requestId)
      let recorder = try TimberVoxAudioRecorder(url: url)
      let mode = TimberVoxNativeModeSnapshot.active(from: defaults)
      let realtimeClient = await makeRealtimeClient(
        defaults: defaults,
        mode: mode,
        requestId: requestId
      )
      capture = Capture(
        entryPoint: defaults.string(forKey: "requestedEntryPoint")?.nonempty ?? "keyboard",
        mode: mode,
        recorder: recorder,
        realtimeClient: realtimeClient,
        recordingURL: url,
        requestId: requestId,
        resultId: resultId,
        startedAt: startedAt
      )
      defaults.set(requestId, forKey: "activeRequestId")
      defaults.set("", forKey: "partialTranscript")
      defaults.set(requestId, forKey: "partialTranscriptRequestId")
      defaults.set("recording", forKey: "sessionPhase")
      defaults.set("", forKey: "sessionErrorMessage")
      activityLevels = Array(repeating: 0.08, count: 18)
      await updateActivity(phase: "recording", force: true)
    } catch {
      defaults.set(false, forKey: "recordingRequested")
      defaults.set("ready", forKey: "sessionPhase")
      defaults.set(error.localizedDescription, forKey: "sessionErrorMessage")
      TimberVoxAudioRecorder.deactivateAudioSession()
      await updateActivity(phase: "ready", force: true)
    }
  }

  private func finishCapture(keepSessionWarm: Bool) async {
    guard let activeCapture = capture else { return }
    capture = nil
    let duration = activeCapture.recorder.stop(deactivateAudioSession: true)
    let finalPCM = activeCapture.recorder.nextPCMChunk()
    activeCapture.recorder.finishPCMStream()
    if let realtimeClient = activeCapture.realtimeClient {
      Task { await realtimeClient.finish(finalPCM: finalPCM) }
    }
    let finished = FinishedCapture(
      duration: duration,
      entryPoint: activeCapture.entryPoint,
      mode: activeCapture.mode,
      recordingURL: activeCapture.recordingURL,
      requestId: activeCapture.requestId,
      resultId: activeCapture.resultId,
      startedAt: activeCapture.startedAt
    )
    let defaults = TimberVoxNativeBridge.defaults
    processingCount += 1
    if keepSessionWarm {
      defaults.set("processing", forKey: "sessionPhase")
      await updateActivity(phase: "processing", force: true)
    } else {
      defaults.set("finalizing", forKey: "sessionPhase")
      await updateActivity(phase: "finalizing", force: true)
    }
    Task { [weak self] in
      let outcome = await Self.process(finished)
      await self?.processingFinished(outcome: outcome, requestId: finished.requestId)
    }
  }

  private func stopSession() async {
    let defaults = TimberVoxNativeBridge.defaults
    let hasCapture = capture != nil
    if hasCapture { await finishCapture(keepSessionWarm: false) }
    TimberVoxAudioRecorder.deactivateAudioSession()
    commandTask?.cancel()
    commandTask = nil
    defaults.set(false, forKey: "sessionActive")
    defaults.set(false, forKey: "sessionStopRequested")
    defaults.set(false, forKey: "recordingRequested")
    defaults.set("", forKey: "sessionOwner")
    defaults.set(0, forKey: "sessionHeartbeat")
    if !hasCapture, processingCount == 0 { defaults.set("off", forKey: "sessionPhase") }
    if !hasCapture, processingCount > 0 { defaults.set("finalizing", forKey: "sessionPhase") }
    defaults.synchronize()
    if processingCount == 0 {
      await endActivity(phase: "complete")
    } else {
      await updateActivity(phase: "finalizing", force: true)
    }
  }

  private func updateActivity(phase: String, force: Bool = false) async {
    guard let activity else { return }
    let now = Date()
    guard force || now.timeIntervalSince(lastActivityUpdate) >= 0.36 else { return }
    lastActivityUpdate = now
    let defaults = TimberVoxNativeBridge.defaults
    await activity.update(
      ActivityContent(
        state: .init(
          audioLevels: activityLevels,
          displayMode: defaults.string(forKey: "liveActivityDisplayMode") == "words"
            ? "words" : "waveform",
          phase: phase,
          partialTranscript: defaults.string(forKey: "partialTranscript") ?? ""
        ),
        staleDate: nil
      )
    )
  }

  private func endActivity(phase: String) async {
    guard let activity else { return }
    let defaults = TimberVoxNativeBridge.defaults
    await activity.end(
      ActivityContent(
        state: .init(
          audioLevels: activityLevels,
          displayMode: defaults.string(forKey: "liveActivityDisplayMode") == "words"
            ? "words" : "waveform",
          phase: phase,
          partialTranscript: defaults.string(forKey: "partialTranscript") ?? ""
        ),
        staleDate: nil
      ),
      dismissalPolicy: .immediate
    )
    self.activity = nil
  }

  private enum ProcessingOutcome: Equatable {
    case failed
    case noSpeech
    case succeeded
  }

  private func processingFinished(outcome: ProcessingOutcome, requestId: String) async {
    processingCount = max(0, processingCount - 1)
    let defaults = TimberVoxNativeBridge.defaults
    if defaults.string(forKey: "partialTranscriptRequestId") == requestId {
      defaults.set("", forKey: "partialTranscript")
      defaults.set("", forKey: "partialTranscriptRequestId")
      defaults.set(
        defaults.integer(forKey: "partialTranscriptRevision") + 1,
        forKey: "partialTranscriptRevision"
      )
    }

    guard capture == nil else { return }
    if defaults.bool(forKey: "sessionActive") {
      if processingCount == 0 {
        defaults.set("ready", forKey: "sessionPhase")
        await updateActivity(phase: outcome == .failed ? "failed" : "ready", force: true)
      }
      return
    }
    guard processingCount == 0 else { return }
    defaults.set("off", forKey: "sessionPhase")
    defaults.synchronize()
    await endActivity(phase: outcome == .failed ? "failed" : "complete")
  }

  private func streamCaptureSnapshot() async {
    guard let capture else { return }
    activityLevels.append(capture.recorder.meterLevel())
    activityLevels = Array(activityLevels.suffix(18))
    if let realtimeClient = capture.realtimeClient,
      let audio = capture.recorder.nextPCMChunk()
    {
      await realtimeClient.sendPCM(audio)
    }
    await updateActivity(phase: "recording")
  }

  private func makeRealtimeClient(
    defaults: UserDefaults,
    mode: TimberVoxNativeModeSnapshot,
    requestId: String
  ) async -> TimberVoxNativeRealtimeClient? {
    do {
      let client = try TimberVoxNativeRealtimeClient(defaults: defaults) { [weak self] text in
        await self?.publishPartialTranscript(text, requestId: requestId)
      }
      try await client.connect(mode: mode)
      return client
    } catch {
      return nil
    }
  }

  private func publishPartialTranscript(_ text: String, requestId: String) async {
    guard capture?.requestId == requestId else { return }
    let defaults = TimberVoxNativeBridge.defaults
    guard defaults.string(forKey: "partialTranscript") != text else { return }
    defaults.set(text, forKey: "partialTranscript")
    defaults.set(requestId, forKey: "partialTranscriptRequestId")
    defaults.set(
      defaults.integer(forKey: "partialTranscriptRevision") + 1,
      forKey: "partialTranscriptRevision"
    )
    defaults.synchronize()
    await updateActivity(phase: "recording")
  }

  private static func process(_ capture: FinishedCapture) async -> ProcessingOutcome {
    let defaults = TimberVoxNativeBridge.defaults
    let endedAt = Date()
    do {
      let client = try TimberVoxNativeAPIClient(defaults: defaults)
      let transcription = try await client.transcribe(
        recordingURL: capture.recordingURL,
        mode: capture.mode,
        requestId: capture.requestId
      )
      let finalText = try await client.process(
        transcript: transcription.text,
        mode: capture.mode
      )
      let envelope = TimberVoxNativeResultEnvelope(
        artifactJSON: transcription.artifactJSON,
        createdAt: capture.startedAt,
        durationMs: max(0, Int(capture.duration * 1_000)),
        endedAt: Date(),
        entryPoint: capture.entryPoint,
        errorCode: nil,
        errorMessage: nil,
        finalText: finalText,
        mode: capture.mode,
        rawText: transcription.text,
        recordingURI: capture.recordingURL.absoluteString,
        requestId: capture.requestId,
        resultId: capture.resultId,
        schemaVersion: 1,
        startedAt: capture.startedAt,
        status: finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? "no_speech" : "succeeded"
      )
      try publish(envelope: envelope, defaults: defaults)
      if capture.entryPoint != "keyboard", !finalText.isEmpty {
        await MainActor.run { UIPasteboard.general.string = finalText }
      }
      defaults.set("", forKey: "sessionErrorMessage")
      defaults.synchronize()
      return finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? .noSpeech : .succeeded
    } catch {
      let envelope = TimberVoxNativeResultEnvelope(
        artifactJSON: nil,
        createdAt: capture.startedAt,
        durationMs: max(0, Int(capture.duration * 1_000)),
        endedAt: endedAt,
        entryPoint: capture.entryPoint,
        errorCode: "shortcut_recording_failed",
        errorMessage: error.localizedDescription,
        finalText: "",
        mode: capture.mode,
        rawText: "",
        recordingURI: FileManager.default.fileExists(atPath: capture.recordingURL.path)
          ? capture.recordingURL.absoluteString : nil,
        requestId: capture.requestId,
        resultId: capture.resultId,
        schemaVersion: 1,
        startedAt: capture.startedAt,
        status: "failed"
      )
      try? publish(envelope: envelope, defaults: defaults)
      defaults.set(error.localizedDescription, forKey: "sessionErrorMessage")
      defaults.synchronize()
      return .failed
    }
  }

  private static func publish(
    envelope: TimberVoxNativeResultEnvelope,
    defaults: UserDefaults
  ) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(envelope)
    guard let json = String(data: data, encoding: .utf8) else {
      throw TimberVoxShortcutError.resultEncoding
    }
    let outbox = try outboxDirectory()
    let filename = "\(Int(Date().timeIntervalSince1970 * 1_000))-\(envelope.resultId).json"
    try data.write(to: outbox.appendingPathComponent(filename), options: .atomic)
    // Keep the legacy single-value envelope for one release so older app code can still import the
    // newest result. The file outbox is authoritative and prevents later results overwriting it.
    defaults.set(json, forKey: "nativeResultEnvelope")
    defaults.set(defaults.integer(forKey: "nativeResultRevision") + 1, forKey: "nativeResultRevision")
    defaults.set(envelope.resultId, forKey: "finalResultId")
    defaults.set(envelope.requestId, forKey: "finalRequestId")
    defaults.set(envelope.finalText, forKey: "finalTranscript")
    defaults.set(envelope.status, forKey: "finalResultStatus")
    defaults.set(defaults.integer(forKey: "transcriptRevision") + 1, forKey: "transcriptRevision")
    defaults.synchronize()
  }

  private static func recordingURL(requestId: String) throws -> URL {
    let recordings = try sharedDirectory().appendingPathComponent(
      "ShortcutRecordings",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
    return recordings.appendingPathComponent("\(requestId).wav")
  }

  private static func outboxDirectory() throws -> URL {
    let outbox = try sharedDirectory().appendingPathComponent("NativeResultOutbox", isDirectory: true)
    try FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
    return outbox
  }

  private static func sharedDirectory() throws -> URL {
    guard
      let directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: TimberVoxNativeBridge.appGroup
      )
    else { throw TimberVoxShortcutError.appGroup }
    return directory
  }
}

extension String {
  fileprivate var nonempty: String? {
    isEmpty ? nil : self
  }
}

@MainActor
private final class TimberVoxAudioRecorder {
  private var pcmFileHandle: FileHandle?
  private var pcmReadOffset: UInt64?
  private let recordingURL: URL
  private let recorder: AVAudioRecorder

  init(url: URL) throws {
    recordingURL = url
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
    recorder.isMeteringEnabled = true
    guard recorder.record() else { throw TimberVoxShortcutError.recorderStart }
  }

  func meterLevel() -> Double {
    recorder.updateMeters()
    let decibels = Double(recorder.averagePower(forChannel: 0))
    let normalized = min(1, max(0, (decibels + 52) / 52))
    return pow(normalized, 0.72)
  }

  func nextPCMChunk() -> Data? {
    guard let handle = pcmHandle() else { return nil }
    guard let offset = pcmReadOffset else {
      guard (try? handle.seek(toOffset: 0)) != nil,
        let data = try? handle.readToEnd(), !data.isEmpty,
        let dataOffset = Self.waveDataOffset(in: data)
      else { return nil }
      pcmReadOffset = UInt64(dataOffset)
      let available = data.count - dataOffset
      let evenByteCount = available - available % MemoryLayout<Int16>.size
      guard evenByteCount > 0 else { return nil }
      let end = dataOffset + evenByteCount
      pcmReadOffset = UInt64(end)
      return data.subdata(in: dataOffset..<end)
    }
    guard (try? handle.seek(toOffset: offset)) != nil,
      let data = try? handle.readToEnd(), !data.isEmpty
    else { return nil }
    let evenByteCount = data.count - data.count % MemoryLayout<Int16>.size
    guard evenByteCount > 0 else { return nil }
    pcmReadOffset = offset + UInt64(evenByteCount)
    return data.subdata(in: 0..<evenByteCount)
  }

  func finishPCMStream() {
    try? pcmFileHandle?.close()
    pcmFileHandle = nil
  }

  private func pcmHandle() -> FileHandle? {
    if let pcmFileHandle { return pcmFileHandle }
    guard let handle = try? FileHandle(forReadingFrom: recordingURL) else { return nil }
    pcmFileHandle = handle
    return handle
  }

  @discardableResult
  func stop(deactivateAudioSession: Bool = true) -> TimeInterval {
    let duration = recorder.currentTime
    recorder.stop()
    if deactivateAudioSession { Self.deactivateAudioSession() }
    return duration
  }

  static func deactivateAudioSession() {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private static func waveDataOffset(in data: Data) -> Int? {
    guard data.count >= 20,
      String(data: data[0..<4], encoding: .ascii) == "RIFF",
      String(data: data[8..<12], encoding: .ascii) == "WAVE"
    else { return nil }
    var offset = 12
    while offset + 8 <= data.count {
      let identifier = String(data: data[offset..<(offset + 4)], encoding: .ascii)
      if identifier == "data" { return offset + 8 }
      let sizeRange = (offset + 4)..<(offset + 8)
      let size = data[sizeRange].enumerated().reduce(0) { result, item in
        result | Int(item.element) << (item.offset * 8)
      }
      guard size >= 0, offset + 8 + size <= data.count else { return nil }
      offset += 8 + size + size % 2
    }
    return nil
  }
}

private struct TimberVoxNativeResultEnvelope: Codable {
  let artifactJSON: String?
  let createdAt: Date
  let durationMs: Int
  let endedAt: Date
  let entryPoint: String
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
      ?? "https://voice.peacockery.studio"
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
