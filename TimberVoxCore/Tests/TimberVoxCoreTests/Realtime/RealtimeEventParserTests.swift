import Foundation
import Testing

@testable import TimberVoxCore

@Suite struct RealtimeEventParserTests {
  @Test func parsesSessionStarted() {
    let event = RealtimeEventParser.parse(#"{"type":"session.started","session_id":"rt_123","config":{}}"#)
    #expect(event == .sessionStarted(sessionID: "rt_123"))
  }

  @Test func parsesAudioReceivedAck() {
    let event = RealtimeEventParser.parse(#"{"type":"audio.received","audio_bytes":6400,"chunk_bytes":3200}"#)
    #expect(event == .audioReceived(totalBytes: 6400))
  }

  @Test func parsesDeepgramInterimResults() {
    let json = #"{"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hello wor","confidence":0.8}]}}"#
    #expect(RealtimeEventParser.parse(json) == .partialTranscript("hello wor"))
  }

  @Test func parsesDeepgramFinalResults() {
    let json = #"{"type":"Results","is_final":true,"speech_final":true,"channel":{"alternatives":[{"transcript":"hello world."}]}}"#
    #expect(RealtimeEventParser.parse(json) == .finalTranscript("hello world."))
  }

  @Test func parsesMistralDeltaSegmentAndDone() {
    #expect(RealtimeEventParser.parse(#"{"type":"transcription.text.delta","text":"hel"}"#) == .partialTranscript("hel"))
    #expect(
      RealtimeEventParser.parse(#"{"type":"transcription.segment","text":"hello","start":0,"end":0.5}"#)
        == .finalTranscript("hello"))
    #expect(
      RealtimeEventParser.parse(#"{"type":"transcription.done","text":"hello world","language":"en","model":"m"}"#)
        == .transcriptionDone("hello world"))
  }

  @Test func parsesControlAndErrorEvents() {
    #expect(RealtimeEventParser.parse(#"{"type":"session.ended","audio_bytes":1}"#) == .sessionEnded)
    #expect(RealtimeEventParser.parse(#"{"type":"pong"}"#) == .pong)
    #expect(
      RealtimeEventParser.parse(#"{"type":"error","error":{"code":400,"message":"bad audio"}}"#)
        == .providerError("bad audio"))
  }

  @Test func toleratesUnknownAndMalformedPayloads() {
    #expect(RealtimeEventParser.parse(#"{"type":"Metadata","duration":1.5}"#) == .unrecognized(type: "Metadata"))
    #expect(RealtimeEventParser.parse("not json") == nil)
    #expect(RealtimeEventParser.parse(#"{"no_type":true}"#) == nil)
  }

  @Test func encodesFloatSamplesAsLinear16LittleEndian() {
    let data = RealtimeAudioEncoder.linear16Data(from: [0, 1.0, -1.0, 0.5, 2.0])
    #expect(data.count == 10)
    let values = data.withUnsafeBytes { raw in
      raw.bindMemory(to: Int16.self).map { Int16(littleEndian: $0) }
    }
    #expect(values[0] == 0)
    #expect(values[1] == Int16.max)
    #expect(values[2] == -Int16.max)
    #expect(values[3] == Int16(Float(Int16.max) * 0.5))
    #expect(values[4] == Int16.max)
  }
}
