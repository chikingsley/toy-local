import XCTest

@testable import TimberVoxSwipeDecoder

final class FutoWordHashTests: XCTestCase {
  func testHashMatchesPublishedModelVocabularyFixtures() {
    XCTAssertEqual(FutoWordHash.hash(Array("hello".utf8)), 66_478_811_968_527_032)
    XCTAssertEqual(FutoWordHash.hash(Array("the".utf8)), 5_933_384_505_577_477_024)
    XCTAssertEqual(
      FutoWordHash.hash(Array("don't".utf8)),
      15_644_294_451_650_341_770
    )
  }

  func testBucketIndicesMatchPublishedModelVocabularyFixtures() {
    XCTAssertEqual(
      FutoWordHash.bucketIndices(for: "hello", bucketCount: 32_768),
      [22_259, 20_925]
    )
    XCTAssertEqual(
      FutoWordHash.bucketIndices(for: "the", bucketCount: 32_768),
      [31_603, 14_789]
    )
  }
}
