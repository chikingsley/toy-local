import CoreGraphics
import XCTest

@testable import TimberVoxSwipeDecoder

final class GeometricSwipeDecoderTests: XCTestCase {
  private let decoder = GeometricSwipeDecoder()
  private let layout = makeQwertyLayout(size: CGSize(width: 390, height: 132))

  func testWhenBeatsLongWordThatSharesEndpoints() throws {
    let points = try densePath(for: "when")
    let candidates = [
      SwipeVocabularyEntry(frequency: 1_531_731, word: "when"),
      SwipeVocabularyEntry(frequency: 1_786, word: "watermelon"),
      SwipeVocabularyEntry(frequency: 40_246, word: "written"),
    ]

    XCTAssertEqual(
      decoder.predictions(for: points, layout: layout, vocabulary: candidates).first,
      "when"
    )
  }

  func testCommonWordCorpusRanksIntendedShapeFirst() throws {
    let corpus: [(word: String, alternatives: [String])] = [
      ("there", ["three", "theatre", "therefore"]),
      ("this", ["things", "thoughts", "thomas"]),
      ("because", ["breathe", "bounce", "blouse"]),
      ("something", ["setting", "shopping", "suffering"]),
    ]

    for item in corpus {
      let candidates =
        [SwipeVocabularyEntry(frequency: 100_000, word: item.word)]
        + item.alternatives.map { SwipeVocabularyEntry(frequency: 100_000, word: $0) }
      XCTAssertEqual(
        decoder.predictions(
          for: try path(for: item.word),
          layout: layout,
          vocabulary: candidates
        ).first,
        item.word
      )
    }
  }

  func testReportedHapticAndIndustrialShapesRankFirst() throws {
    let corpus: [(word: String, alternatives: [String])] = [
      ("haptic", ["habit", "hectic", "historic"]),
      ("industrial", ["individual", "instructural", "institutional"]),
    ]

    for item in corpus {
      let candidates =
        [SwipeVocabularyEntry(frequency: 5_374, word: item.word)]
        + item.alternatives.map { SwipeVocabularyEntry(frequency: 100_000, word: $0) }
      XCTAssertEqual(
        decoder.predictions(
          for: try densePath(for: item.word),
          layout: layout,
          vocabulary: candidates
        ).first,
        item.word
      )
    }
  }

  private func path(for word: String) throws -> [SwipePoint] {
    try word.enumerated().map { index, character in
      SwipePoint(
        location: try XCTUnwrap(layout.frames[character]).center,
        timestamp: Double(index) / 60
      )
    }
  }

  private func densePath(for word: String) throws -> [SwipePoint] {
    let anchors = try path(for: word).map(\.location)
    let locations =
      zip(anchors, anchors.dropFirst()).flatMap { start, end in
        (0..<8).map { step in
          let progress = CGFloat(step) / 8
          return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
          )
        }
      } + [try XCTUnwrap(anchors.last)]
    return locations.enumerated().map { index, location in
      SwipePoint(location: location, timestamp: Double(index) / 60)
    }
  }
}

private func makeQwertyLayout(size: CGSize) -> KeyLayout {
  let rows = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]
  let rowHeight = size.height / 3
  var frames: [Character: CGRect] = [:]

  for (rowIndex, row) in rows.prefix(2).enumerated() {
    let sideInset: CGFloat = rowIndex == 0 ? 0 : size.width * 0.045
    let available = size.width - sideInset * 2
    let keyWidth = available / CGFloat(row.count)
    for (column, key) in row.enumerated() {
      frames[key] = CGRect(
        x: sideInset + CGFloat(column) * keyWidth + 2.5,
        y: CGFloat(rowIndex) * rowHeight + 2.5,
        width: keyWidth - 5,
        height: rowHeight - 5
      )
    }
  }

  let controlWidth = min(46, max(40, size.width * 0.13))
  let lettersStart = controlWidth + 7
  let lettersWidth = size.width - (lettersStart * 2)
  let letterWidth = lettersWidth / CGFloat(rows[2].count)
  for (column, key) in rows[2].enumerated() {
    frames[key] = CGRect(
      x: lettersStart + CGFloat(column) * letterWidth + 2.5,
      y: rowHeight * 2 + 2.5,
      width: letterWidth - 5,
      height: rowHeight - 5
    )
  }

  return KeyLayout(
    frames: frames,
    size: size,
    shiftFrame: .zero,
    deleteFrame: .zero
  )
}

extension CGRect {
  fileprivate var center: CGPoint {
    CGPoint(x: midX, y: midY)
  }
}
