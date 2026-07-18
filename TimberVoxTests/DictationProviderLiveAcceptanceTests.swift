@preconcurrency import AVFoundation
import XCTest

@testable import TimberVox

/// End-to-end provider acceptance: real synthesized speech is played as system
/// audio, captured through the production aggregate recorder, streamed live to
/// the deployed realtime route, and the same mixed recording is then sent
/// through the batch route. Both transcripts must contain the spoken phrase.
@MainActor
final class DictationProviderLiveAcceptanceTests: XCTestCase {
  private static let phrase =
    "The quick brown fox jumps over the lazy dog while Peter Piper picks a peck of pickled peppers."
  private static let keywords = ["quick", "brown", "fox", "lazy", "dog", "peter", "piper", "pepper"]
  private static let model = "deepgram-nova-3"

  func testRealSpeechReachesRealtimeAndBatchProviders() async throws {
    try LiveAudioTest.requireProviderAcceptance()
    let artifacts = try LiveAudioTest.makeArtifactsDirectory(named: "provider")
    let speechURL = artifacts.appendingPathComponent("system-speech.aiff")
    let speechDuration = try LiveAudioTest.writeSpokenPhrase(Self.phrase, to: speechURL)

    let session = CloudRealtimeTranscriptionSession {
      CloudRealtimeTranscriptionClient(baseURL: APIConnector.defaultBaseURL)
    }
    try await session.start(
      model: Self.model,
      language: "en",
      onTranscript: { _ in },
      onError: { _ in }
    )

    let recording = try await recordSystemSpeech(
      playing: speechURL,
      speechDuration: speechDuration,
      into: artifacts,
      streamingTo: session
    )
    let mixed = try LiveAudioTest.samples(at: recording.url)
    XCTAssertGreaterThan(
      LiveAudioTest.rootMeanSquare(mixed),
      0.001,
      "The mixed recording must contain the played speech, not silence."
    )

    let realtimeTranscript = try await session.finish().displayText
    try save(realtimeTranscript, as: "realtime-transcript.txt", in: artifacts)

    let batch = try await CloudBatchTranscriber.current.transcribe(
      wavAt: recording.url,
      model: Self.model,
      language: "en"
    )
    try save(batch.displayText, as: "batch-transcript.txt", in: artifacts)

    let realtimeHits = LiveAudioTest.matchedKeywords(Self.keywords, in: realtimeTranscript)
    let batchHits = LiveAudioTest.matchedKeywords(Self.keywords, in: batch.displayText)
    XCTAssertGreaterThanOrEqual(
      realtimeHits.count,
      3,
      "Realtime transcript missed the spoken phrase. Transcript: \(realtimeTranscript)"
    )
    XCTAssertGreaterThanOrEqual(
      batchHits.count,
      3,
      "Batch transcript missed the spoken phrase. Transcript: \(batch.displayText)"
    )
  }

  /// Soak: a minute of continuous speech must stream live without stalling.
  /// The closing sentence appearing in the transcript proves the stream
  /// survived to the end; batch on the same long recording must agree.
  func testMinuteLongRealtimeStreamSurvivesToTheFinalSentence() async throws {
    try LiveAudioTest.requireProviderAcceptance()
    let artifacts = try LiveAudioTest.makeArtifactsDirectory(named: "soak")
    let opening = "The quick brown fox jumps over the lazy dog near the riverbank. "
    let closing = "The final sentence mentions a golden pineapple on the kitchen table."
    let longPhrase = String(repeating: opening, count: 14) + closing
    let speechURL = artifacts.appendingPathComponent("system-speech.aiff")
    let speechDuration = try LiveAudioTest.writeSpokenPhrase(longPhrase, to: speechURL)
    XCTAssertGreaterThan(speechDuration, 40, "The soak fixture must be a genuinely long stream.")

    let session = CloudRealtimeTranscriptionSession {
      CloudRealtimeTranscriptionClient(baseURL: APIConnector.defaultBaseURL)
    }
    try await session.start(
      model: Self.model,
      language: "en",
      onTranscript: { _ in },
      onError: { _ in }
    )
    let recording = try await recordSystemSpeech(
      playing: speechURL,
      speechDuration: speechDuration,
      into: artifacts,
      streamingTo: session
    )
    let realtimeTranscript = try await session.finish().displayText
    try save(realtimeTranscript, as: "realtime-transcript.txt", in: artifacts)

    let batch = try await CloudBatchTranscriber.current.transcribe(
      wavAt: recording.url,
      model: Self.model,
      language: "en"
    )
    try save(batch.displayText, as: "batch-transcript.txt", in: artifacts)

    for transcript in [realtimeTranscript, batch.displayText] {
      let lowered = transcript.lowercased()
      XCTAssertTrue(lowered.contains("fox"), "The opening speech is missing: \(transcript.prefix(200))")
      XCTAssertTrue(
        lowered.contains("pineapple"),
        "The closing sentence is missing — the stream stalled before the end. Tail: \(transcript.suffix(200))"
      )
    }
  }

  private func recordSystemSpeech(
    playing speechURL: URL,
    speechDuration: TimeInterval,
    into artifacts: URL,
    streamingTo session: CloudRealtimeTranscriptionSession
  ) async throws -> (url: URL, duration: TimeInterval) {
    let recorder = DictationAudioRecorder()
    let recordingURL = artifacts.appendingPathComponent("mixed.wav")
    try await recorder.start(
      writingTo: recordingURL,
      includesSystemAudio: true,
      onLevel: nil
    ) { samples in
      Task { @MainActor in
        await session.sendPCM(samples)
      }
    }
    let player = try AVAudioPlayer(contentsOf: speechURL)
    player.play()
    try await Task.sleep(for: .seconds(speechDuration + 1.5))
    let recording = try await recorder.finish()
    return try XCTUnwrap(recording)
  }

  private func save(_ text: String, as name: String, in directory: URL) throws {
    try text.write(
      to: directory.appendingPathComponent(name),
      atomically: true,
      encoding: .utf8
    )
  }
}
