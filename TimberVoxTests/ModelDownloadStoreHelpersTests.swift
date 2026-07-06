import Foundation
import XCTest

@testable import TimberVox

@MainActor
final class ModelDownloadStoreHelpersTests: XCTestCase {
  func testResolveModelPatternPrefersDownloadedNonTurbo() {
    let available = [
      ModelInfo(name: "parakeet-tdt-0.6b-v3-coreml-turbo", isDownloaded: true),
      ModelInfo(name: "parakeet-tdt-0.6b-v3-coreml", isDownloaded: true),
      ModelInfo(name: "parakeet-tdt-ctc-110m-coreml", isDownloaded: false),
    ]

    let resolved = ModelDownloadStore.resolveModelPattern("parakeet-tdt-0.6b-v3-coreml*", from: available)
    XCTAssertEqual(resolved, "parakeet-tdt-0.6b-v3-coreml")
  }

  func testModelDisplayNameUsesCuratedLabelWhenAvailable() {
    let curated = [
      CuratedModelInfo(
        displayName: "Parakeet TDT v3",
        internalName: "parakeet-tdt-0.6b-v3-coreml",
        size: "Large",
        accuracyStars: 5,
        speedStars: 2,
        storageSize: "3.1 GB",
        isDownloaded: false
      )
    ]

    let display = ModelDownloadStore.modelDisplayName(for: "parakeet-tdt-0.6b-v3-coreml", curated: curated)
    XCTAssertEqual(display, "Parakeet TDT v3")
  }

  func testModelDisplayNameFallsBackToHumanizedIdentifier() {
    let display = ModelDownloadStore.modelDisplayName(for: "parakeet-tdt-0.6b-v3-coreml", curated: [])
    XCTAssertEqual(display, "Parakeet Tdt 0.6B V3 Coreml")
  }

  func testDownloadErrorMessageIncludesHostWhenPresent() {
    let error = NSError(
      domain: NSURLErrorDomain,
      code: NSURLErrorCannotFindHost,
      userInfo: [
        NSLocalizedDescriptionKey: "Could not find host",
        NSURLErrorFailingURLErrorKey: URL(string: "https://example.com/model") as Any,
      ]
    )

    let message = ModelDownloadStore.downloadErrorMessage(from: error)
    XCTAssertEqual(message, "Could not find host (example.com)")
  }
}
