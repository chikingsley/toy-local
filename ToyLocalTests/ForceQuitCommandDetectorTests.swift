import XCTest
@testable import toy_local

final class ForceQuitCommandDetectorTests: XCTestCase {
	func testMatchesSupportsNormalizedToyLocalPhrases() {
		XCTAssertTrue(ForceQuitCommandDetector.matches("force quit toy local"))
		XCTAssertTrue(ForceQuitCommandDetector.matches("force quit toy-local now"))
	}

	func testMatchesIgnoresCasingAndPunctuation() {
		XCTAssertTrue(ForceQuitCommandDetector.matches("FORCE, QUIT!!! toy-local..."))
		XCTAssertTrue(ForceQuitCommandDetector.matches("Force Quit TOY LOCAL now"))
	}

	func testMatchesRejectsNearMisses() {
		XCTAssertFalse(ForceQuitCommandDetector.matches("force quit now"))
		XCTAssertFalse(ForceQuitCommandDetector.matches("quit toy local"))
		XCTAssertFalse(ForceQuitCommandDetector.matches("force quit toy local please"))
	}
}
