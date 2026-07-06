import XCTest

@testable import TimberVox

final class SmokeTests: XCTestCase {
  func testLanguageCatalogShipsInBundleAndDecodes() throws {
    let url = try XCTUnwrap(
      Bundle.main.url(forResource: "languages", withExtension: "json"),
      "languages.json missing from the app bundle"
    )
    let languages = try JSONDecoder().decode([Language].self, from: Data(contentsOf: url))
    XCTAssertGreaterThan(languages.count, 20)
    XCTAssertTrue(languages.contains { $0.code == nil }, "The Auto entry (nil code) must exist")
    XCTAssertTrue(languages.contains { $0.code == "en" })
  }

  func testSoundEffectAssetsShipInBundle() {
    let requiredSoundFiles = ["Start", "Stop", "StartClassic", "StopClassic", "Notification", "NotificationError"]
    for fileName in requiredSoundFiles {
      let url =
        Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "Audio/SoundEffects/Default")
        ?? Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "Audio/SoundEffects/Classic")
        ?? Bundle.main.url(forResource: fileName, withExtension: "m4a")
      XCTAssertNotNil(url, "Sound effect asset \(fileName).m4a missing from the app bundle")
    }
  }
}
