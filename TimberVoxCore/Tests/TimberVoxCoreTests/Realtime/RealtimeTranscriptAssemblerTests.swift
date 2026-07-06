import Foundation
import Testing

@testable import TimberVoxCore

@Suite struct RealtimeTranscriptAssemblerTests {
  @Test func assemblesFinalsInOrderAndDropsSupersededPartials() {
    var assembler = RealtimeTranscriptAssembler()
    assembler.consume(.partialTranscript("hel"))
    assembler.consume(.partialTranscript("hello wor"))
    assembler.consume(.finalTranscript("Hello, world."))
    assembler.consume(.partialTranscript("this is"))
    assembler.consume(.finalTranscript("This is a test."))
    #expect(assembler.finalText == "Hello, world. This is a test.")
    #expect(assembler.previewText == "Hello, world. This is a test.")
  }

  @Test func keepsTrailingPartialWhenNoFinalArrives() {
    var assembler = RealtimeTranscriptAssembler()
    assembler.consume(.finalTranscript("Hello, world."))
    assembler.consume(.partialTranscript("and then"))
    #expect(assembler.previewText == "Hello, world. and then")
    #expect(assembler.finalText == "Hello, world. and then")
  }

  @Test func doneTextWinsOverAssembledFinals() {
    var assembler = RealtimeTranscriptAssembler()
    assembler.consume(.finalTranscript("partial view"))
    assembler.consume(.transcriptionDone("The complete provider transcript."))
    #expect(assembler.finalText == "The complete provider transcript.")
  }

  @Test func emptySessionYieldsNilFinalText() {
    var assembler = RealtimeTranscriptAssembler()
    assembler.consume(.partialTranscript(""))
    assembler.consume(.sessionEnded)
    #expect(assembler.finalText == nil)
  }

  @Test func routesDeepgramDirectlyAndVoxtralToRealtimeModel() {
    #expect(RealtimeModelRouting.realtimeRouteID(forModelID: "deepgram-nova-3") == "deepgram-nova-3")
    #expect(RealtimeModelRouting.realtimeRouteID(forModelID: "deepgram-nova-2") == "deepgram-nova-2")
    #expect(
      RealtimeModelRouting.realtimeRouteID(forModelID: "mistral-voxtral-mini-latest")
        == "mistral-voxtral-mini-transcribe-realtime-2602")
    #expect(RealtimeModelRouting.realtimeRouteID(forModelID: "parakeet-tdt-0.6b-v3") == nil)
  }
}
