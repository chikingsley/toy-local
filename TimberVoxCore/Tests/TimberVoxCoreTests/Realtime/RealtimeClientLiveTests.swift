import Foundation
import Testing

@testable import TimberVoxCore

/// Live integration against a running worker (`wrangler dev` with provider keys). Opt-in:
/// TIMBERVOX_REALTIME_LIVE=1 [TIMBERVOX_CLOUD_API_URL=http://127.0.0.1:8787]
/// TIMBERVOX_REALTIME_FIXTURE=/path/to/16k-mono.wav swift test --filter RealtimeClientLiveTests
@Suite struct RealtimeClientLiveTests {
  private static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["TIMBERVOX_REALTIME_LIVE"] == "1"
  }

  @Test(.enabled(if: isEnabled)) func streamsFixtureAudioAndReceivesTranscript() async throws {
    let environment = ProcessInfo.processInfo.environment
    let baseURLString = environment["TIMBERVOX_CLOUD_API_URL"] ?? "http://127.0.0.1:8787"
    let fixturePath = try #require(environment["TIMBERVOX_REALTIME_FIXTURE"])
    let model = environment["TIMBERVOX_REALTIME_MODEL"] ?? "nova-3"
    let baseURL = try #require(URL(string: baseURLString))

    let fixtureData = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
    let pcmData = fixtureData.dropFirst(44)

    let client = RealtimeTranscriptionClient(baseURL: baseURL)
    let stream = try await client.connect(options: RealtimeSessionOptions(model: model))

    let sender = Task {
      let chunkSize = 3_200
      var offset = pcmData.startIndex
      while offset < pcmData.endIndex {
        let end = min(offset + chunkSize, pcmData.endIndex)
        try await client.sendAudio(Data(pcmData[offset..<end]))
        offset = end
        try await Task.sleep(for: .milliseconds(50))
      }
      try await Task.sleep(for: .seconds(2))
      try await client.requestClose()
    }

    var sawSessionStart = false
    var transcripts: [String] = []
    var sawSessionEnd = false

    for try await event in stream {
      switch event {
      case .sessionStarted:
        sawSessionStart = true
      case .partialTranscript(let text), .finalTranscript(let text), .transcriptionDone(let text):
        if !text.isEmpty {
          transcripts.append(text)
        }
      case .sessionEnded:
        sawSessionEnd = true
      case .providerError(let message):
        Issue.record("Provider error: \(message)")
      case .audioReceived, .pong, .unrecognized:
        break
      }
    }
    sender.cancel()

    #expect(sawSessionStart)
    #expect(sawSessionEnd)
    #expect(!transcripts.isEmpty, "Expected at least one transcript event from the live session")
    print("Live realtime transcripts: \(transcripts)")
  }
}
