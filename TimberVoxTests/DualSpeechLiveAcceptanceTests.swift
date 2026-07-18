@preconcurrency import AVFoundation
import XCTest

@testable import TimberVox

/// Human-in-the-loop dual-speech acceptance. Run with `just test-dual-speech`:
/// after the spoken "start speaking now" cue, say "purple elephant marmalade
/// sandwich" repeatedly until the "stop" cue. The system plays its own phrase
/// at near-zero speaker volume, so the process tap receives it digitally while
/// the microphone hears only you. Each stem is then batch-transcribed
/// separately: your phrase must exist only in the microphone stem, the played
/// phrase only in the system stem, and both in the mixed master.
@MainActor
final class DualSpeechLiveAcceptanceTests: XCTestCase {
  private static let systemPhrase =
    "The quick brown fox jumps over the lazy dog while the quick brown fox rests by the river."
  private static let systemKeywords = ["quick", "brown", "fox", "lazy", "dog", "river"]
  private static let humanKeywords = ["purple", "elephant", "marmalade", "sandwich"]
  private static let model = "deepgram-nova-3"

  func testHumanAndSystemSpeechLandInTheirOwnStems() async throws {
    try LiveAudioTest.requireDualSpeech()
    let artifacts = try LiveAudioTest.makeArtifactsDirectory(named: "dualspeech")
    let speechURL = artifacts.appendingPathComponent("system-speech.aiff")
    let speechDuration = try LiveAudioTest.writeSpokenPhrase(Self.systemPhrase, to: speechURL)

    let session = CloudRealtimeTranscriptionSession {
      CloudRealtimeTranscriptionClient(baseURL: APIConnector.defaultBaseURL)
    }
    try await session.start(
      model: Self.model,
      language: "en",
      onTranscript: { _ in },
      onError: { _ in }
    )

    let urls = try await recordDualSpeech(
      playing: speechURL,
      speechDuration: speechDuration,
      into: artifacts,
      streamingTo: session
    )
    let realtimeTranscript = try await session.finish().displayText
    try save(realtimeTranscript, as: "realtime-transcript.txt", in: artifacts)

    let microphoneText = try await batchTranscript(of: urls.microphone, as: "microphone-stem", in: artifacts)
    let systemText = try await batchTranscript(of: urls.system, as: "system-stem", in: artifacts)
    let mixedText = try await batchTranscript(of: urls.mixed, as: "mixed", in: artifacts)

    assertOnlyHumanSpeech(in: microphoneText, label: "microphone stem")
    assertOnlySystemSpeech(in: systemText, label: "system stem")
    for (label, text) in [("mixed batch", mixedText), ("realtime", realtimeTranscript)] {
      XCTAssertGreaterThanOrEqual(
        LiveAudioTest.matchedKeywords(Self.humanKeywords, in: text).count,
        2,
        "The \(label) transcript is missing your spoken phrase: \(text)"
      )
      XCTAssertGreaterThanOrEqual(
        LiveAudioTest.matchedKeywords(Self.systemKeywords, in: text).count,
        2,
        "The \(label) transcript is missing the system phrase: \(text)"
      )
    }
  }

  private func recordDualSpeech(
    playing speechURL: URL,
    speechDuration: TimeInterval,
    into artifacts: URL,
    streamingTo session: CloudRealtimeTranscriptionSession
  ) async throws -> (mixed: URL, microphone: URL, system: URL) {
    let mixedURL = artifacts.appendingPathComponent("mixed.wav")
    let microphoneURL = artifacts.appendingPathComponent("microphone-stem.wav")
    let systemURL = artifacts.appendingPathComponent("system-stem.wav")
    let recorder = AggregateAudioRecorder()

    let originalVolume = try LiveAudioTest.systemOutputVolume()
    defer { try? LiveAudioTest.setSystemOutputVolume(originalVolume) }
    try LiveAudioTest.speakCue("Start speaking now.", atVolume: max(originalVolume, 50))
    try LiveAudioTest.setSystemOutputVolume(3)

    try recorder.start(
      writingTo: mixedURL,
      microphoneURL: microphoneURL,
      systemURL: systemURL,
      onLevel: nil
    ) { samples in
      Task { @MainActor in
        await session.sendPCM(samples)
      }
    }
    let player = try AVAudioPlayer(contentsOf: speechURL)
    player.play()
    try await Task.sleep(for: .seconds(max(speechDuration + 3, 12)))
    _ = try XCTUnwrap(recorder.finish())

    try LiveAudioTest.speakCue("Stop. Thank you.", atVolume: max(originalVolume, 50))
    return (mixedURL, microphoneURL, systemURL)
  }

  private func batchTranscript(
    of url: URL,
    as name: String,
    in artifacts: URL
  ) async throws -> String {
    let outcome = try await CloudBatchTranscriber.current.transcribe(
      wavAt: url,
      model: Self.model,
      language: "en"
    )
    try save(outcome.displayText, as: "\(name)-transcript.txt", in: artifacts)
    return outcome.displayText
  }

  private func assertOnlyHumanSpeech(in text: String, label: String) {
    XCTAssertGreaterThanOrEqual(
      LiveAudioTest.matchedKeywords(Self.humanKeywords, in: text).count,
      2,
      "The \(label) should contain your spoken phrase: \(text)"
    )
    XCTAssertTrue(
      LiveAudioTest.matchedKeywords(Self.systemKeywords, in: text).isEmpty,
      "The \(label) must not contain the system phrase — acoustic echo detected: \(text)"
    )
  }

  private func assertOnlySystemSpeech(in text: String, label: String) {
    XCTAssertGreaterThanOrEqual(
      LiveAudioTest.matchedKeywords(Self.systemKeywords, in: text).count,
      2,
      "The \(label) should contain the played phrase: \(text)"
    )
    XCTAssertTrue(
      LiveAudioTest.matchedKeywords(Self.humanKeywords, in: text).isEmpty,
      "The \(label) must not contain your voice — the tap leaked microphone audio: \(text)"
    )
  }

  private func save(_ text: String, as name: String, in directory: URL) throws {
    try text.write(
      to: directory.appendingPathComponent(name),
      atomically: true,
      encoding: .utf8
    )
  }
}
