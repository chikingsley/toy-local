import XCTest

@testable import TimberVox

final class ForceQuitCommandDetectorTests: XCTestCase {
  func testMatchesSupportsNormalizedAppNamePhrases() {
    XCTAssertTrue(ForceQuitCommandDetector.matches("force quit ark voice"))
    XCTAssertTrue(ForceQuitCommandDetector.matches("force quit ark-voice now"))
    XCTAssertTrue(ForceQuitCommandDetector.matches("force quit ark voice"))
    XCTAssertTrue(ForceQuitCommandDetector.matches("force quit timbervox now"))
  }

  func testMatchesIgnoresCasingAndPunctuation() {
    XCTAssertTrue(ForceQuitCommandDetector.matches("FORCE, QUIT!!! ark-voice..."))
    XCTAssertTrue(ForceQuitCommandDetector.matches("Force Quit ARK VOICE now"))
  }

  func testMatchesRejectsNearMisses() {
    XCTAssertFalse(ForceQuitCommandDetector.matches("force quit now"))
    XCTAssertFalse(ForceQuitCommandDetector.matches("quit ark voice"))
    XCTAssertFalse(ForceQuitCommandDetector.matches("force quit ark voice please"))
  }
}
