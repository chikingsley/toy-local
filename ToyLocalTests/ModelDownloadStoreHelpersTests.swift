import Foundation
import XCTest
@testable import toy_local

@MainActor
final class ModelDownloadStoreHelpersTests: XCTestCase {
	func testResolveModelPatternPrefersDownloadedNonTurbo() {
		let available = [
			ModelInfo(name: "whisper-large-v3-turbo", isDownloaded: true),
			ModelInfo(name: "whisper-large-v3", isDownloaded: true),
			ModelInfo(name: "whisper-medium", isDownloaded: false),
		]

		let resolved = ModelDownloadStore.resolveModelPattern("whisper-large-v3*", from: available)
		XCTAssertEqual(resolved, "whisper-large-v3")
	}

	func testModelDisplayNameUsesCuratedLabelWhenAvailable() {
		let curated = [
			CuratedModelInfo(
				displayName: "Whisper Large v3",
				internalName: "whisper-large-v3",
				size: "Large",
				accuracyStars: 5,
				speedStars: 2,
				storageSize: "3.1 GB",
				isDownloaded: false
			),
		]

		let display = ModelDownloadStore.modelDisplayName(for: "whisper-large-v3", curated: curated)
		XCTAssertEqual(display, "Whisper Large v3")
	}

	func testModelDisplayNameFallsBackToHumanizedIdentifier() {
		let display = ModelDownloadStore.modelDisplayName(for: "whisper-large-v3", curated: [])
		XCTAssertEqual(display, "Whisper Large V3")
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
