import XCTest

@testable import TimberVoxSwipeDecoder

final class FutoContextVocabularyTests: XCTestCase {
  func testUsesZeroBasedExactIDsAndSentinelForUnknownWords() throws {
    let vocabulary = try FutoContextVocabulary(
      text: "the\nto\nof\n",
      exactWordCount: 3,
      hashBucketCount: 32_768
    )

    XCTAssertEqual(vocabulary.lookup("THE").id, 0)
    XCTAssertEqual(vocabulary.lookup("to").id, 1)
    XCTAssertEqual(vocabulary.lookup("of").id, 2)
    XCTAssertEqual(vocabulary.lookup("haptic").id, 3)
    XCTAssertEqual(
      vocabulary.lookup("haptic").hashes,
      FutoWordHash.bucketIndices(for: "haptic", bucketCount: 32_768)
    )
  }

  func testDuplicateWordsKeepTheFirstID() throws {
    let vocabulary = try FutoContextVocabulary(
      text: "the\nto\nthe\n",
      exactWordCount: 3,
      hashBucketCount: 32_768
    )

    XCTAssertEqual(vocabulary.lookup("the").id, 0)
    XCTAssertEqual(vocabulary.lookup("to").id, 1)
  }

  func testRejectsAWordListThatDoesNotMatchTheModelEmbeddingCount() {
    XCTAssertThrowsError(
      try FutoContextVocabulary(
        text: "the\nto\nof\n",
        exactWordCount: 4,
        hashBucketCount: 32_768
      )
    )
  }
}
