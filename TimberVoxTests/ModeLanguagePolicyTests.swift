import XCTest

@testable import TimberVox

final class ModeLanguagePolicyTests: XCTestCase {
  private let languages: [Language] = [
    Language(code: nil, name: "Auto"),
    Language(code: "en", name: "English"),
    Language(code: "de", name: "German"),
    Language(code: "ja", name: "Japanese"),
  ]

  func testEmptySupportedSetAllowsEveryLanguage() {
    let names = ModeLanguagePolicy.allowedLanguageNames(languages: languages, supportedCodes: [])
    XCTAssertEqual(names, ["Automatic", "English", "German", "Japanese"])
  }

  func testLimitedSupportedSetFiltersOptions() {
    let names = ModeLanguagePolicy.allowedLanguageNames(languages: languages, supportedCodes: ["en", "de"])
    XCTAssertEqual(names, ["Automatic", "English", "German"])
  }

  func testAutomaticIsAlwaysFirstAndNeverDuplicated() {
    let names = ModeLanguagePolicy.allowedLanguageNames(languages: languages, supportedCodes: ["en"])
    XCTAssertEqual(names.first, "Automatic")
    XCTAssertEqual(names.filter { $0 == "Automatic" || $0 == "Auto" }.count, 1)
  }

  func testNilCodeIsAlwaysSupported() {
    XCTAssertTrue(ModeLanguagePolicy.isSupported(code: nil, supportedCodes: ["en"]))
  }

  func testEmptySupportedSetMeansUnrestricted() {
    XCTAssertTrue(ModeLanguagePolicy.isSupported(code: "ja", supportedCodes: []))
  }

  func testUnsupportedCodeIsRejected() {
    XCTAssertFalse(ModeLanguagePolicy.isSupported(code: "ja", supportedCodes: ["en", "de"]))
    XCTAssertTrue(ModeLanguagePolicy.isSupported(code: "de", supportedCodes: ["en", "de"]))
  }
}
