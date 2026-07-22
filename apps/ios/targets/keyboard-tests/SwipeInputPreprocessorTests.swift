import CoreGraphics
import Testing

@testable import TimberVoxSwipeDecoder

@Suite("Swipe input preprocessing")
struct SwipeInputPreprocessorTests {
  @Test("Normalizes screen-space traces to the FUTO model coordinate system")
  func normalizesTraceCoordinates() throws {
    let samples = [
      SwipePoint(location: CGPoint(x: 20, y: 25), timestamp: 1),
      SwipePoint(location: CGPoint(x: 180, y: 75), timestamp: 2),
    ]

    let trace = try SwipeInputPreprocessor.normalizedTrace(
      samples: samples,
      layoutSize: CGSize(width: 200, height: 100)
    )

    #expect(trace.x.count == 64)
    #expect(trace.y.count == 64)
    #expect(abs(trace.x.first! - 0.1) < 0.000_1)
    #expect(abs(trace.y.first! - 0.25) < 0.000_1)
    #expect(abs(trace.x.last! - 0.9) < 0.000_1)
    #expect(abs(trace.y.last! - 0.75) < 0.000_1)
  }
}
