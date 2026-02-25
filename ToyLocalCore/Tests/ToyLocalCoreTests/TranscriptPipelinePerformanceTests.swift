import XCTest
@testable import ToyLocalCore

final class TranscriptPipelinePerformanceTests: XCTestCase {
	func testTranscriptCleanupPipelinePerformance() {
		let removals = [
			WordRemoval(pattern: "uh+"),
			WordRemoval(pattern: "um+"),
			WordRemoval(pattern: "er+"),
			WordRemoval(pattern: "hm+")
		]

		let remappings = [
			WordRemapping(match: "comma", replacement: ","),
			WordRemapping(match: "period", replacement: "."),
			WordRemapping(match: "new line", replacement: "\\n"),
			WordRemapping(match: "new paragraph", replacement: "\\n\\n")
		]

		let sampleChunk = "um hello comma this is a test period new line uh this should be cleaner"
		let input = Array(repeating: sampleChunk, count: 250).joined(separator: " ")

		measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
			var output = WordRemovalApplier.apply(input, removals: removals)
			output = WordRemappingApplier.apply(output, remappings: remappings)
			XCTAssertFalse(output.isEmpty)
		}
	}
}
