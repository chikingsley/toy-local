import TimberVoxCore
import Foundation

private let realtimeLogger = TimberVoxLog.transcription

/// Orchestrates one realtime dictation: feeds the capture engine's converted samples into the
/// cloud realtime session and assembles partial and final transcripts as they arrive.
@MainActor
final class RealtimeDictationSession {
  var onPartial: ((String) -> Void)?

  private let client: RealtimeTranscriptionClient
  private let recording: RecordingClientLive
  private var assembler = RealtimeTranscriptAssembler()
  private var eventTask: Task<Void, Never>?
  private var audioPumpTask: Task<Void, Never>?
  private let audioStream: AsyncStream<[Float]>
  private let audioContinuation: AsyncStream<[Float]>.Continuation
  private var streamEnded = false

  private enum Metrics {
    static let finishPollInterval: Duration = .milliseconds(50)
  }

  init(baseURL: URL, recording: RecordingClientLive) {
    self.client = RealtimeTranscriptionClient(baseURL: baseURL)
    self.recording = recording
    (audioStream, audioContinuation) = AsyncStream<[Float]>.makeStream()
  }

  func start(routeID: String, language: String?) async throws {
    let events = try await client.connect(options: RealtimeSessionOptions(model: routeID, language: language))

    eventTask = Task { [weak self] in
      do {
        for try await event in events {
          await MainActor.run {
            self?.consume(event)
          }
        }
      } catch {
        realtimeLogger.notice("Realtime event stream ended with error: \(error.localizedDescription)")
      }
      await MainActor.run {
        self?.streamEnded = true
      }
    }

    let client = self.client
    let stream = audioStream
    audioPumpTask = Task {
      for await samples in stream {
        do {
          try await client.sendPCM(samples)
        } catch {
          realtimeLogger.notice("Realtime audio send failed: \(error.localizedDescription)")
          return
        }
      }
    }

    let continuation = audioContinuation
    await recording.setLiveSampleConsumer { samples in
      continuation.yield(samples)
    }
    realtimeLogger.notice("Realtime dictation session started route=\(routeID)")
  }

  func finish(timeout: Duration = .seconds(5)) async -> String? {
    await recording.setLiveSampleConsumer(nil)
    audioContinuation.finish()
    try? await client.requestClose()

    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !streamEnded, ContinuousClock.now < deadline {
      try? await Task.sleep(for: Metrics.finishPollInterval)
    }
    await client.disconnect()
    eventTask?.cancel()
    audioPumpTask?.cancel()

    let text = assembler.finalText
    realtimeLogger.notice(
      "Realtime dictation session finished ended=\(self.streamEnded) transcriptChars=\(text?.count ?? 0)"
    )
    return text
  }

  func cancel() {
    let recording = self.recording
    let client = self.client
    Task {
      await recording.setLiveSampleConsumer(nil)
      await client.disconnect()
    }
    audioContinuation.finish()
    eventTask?.cancel()
    audioPumpTask?.cancel()
  }

  private func consume(_ event: RealtimeTranscriptionEvent) {
    assembler.consume(event)
    switch event {
    case .partialTranscript, .finalTranscript, .transcriptionDone:
      onPartial?(assembler.previewText)
    case .sessionEnded:
      streamEnded = true
    case .providerError(let message):
      realtimeLogger.error("Realtime provider error: \(message)")
    default:
      break
    }
  }
}
