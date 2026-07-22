import CoreGraphics
import Foundation

enum KeyboardControlKey {
  case delete
  case shift
}

struct KeyLayout {
  let frames: [Character: CGRect]
  let size: CGSize
  let shiftFrame: CGRect
  let deleteFrame: CGRect

  func key(at point: CGPoint) -> Character? {
    frames.first(where: { $0.value.insetBy(dx: -4, dy: -4).contains(point) })?.key
  }

  func control(at point: CGPoint) -> KeyboardControlKey? {
    if shiftFrame.insetBy(dx: -3, dy: -3).contains(point) { return .shift }
    if deleteFrame.insetBy(dx: -3, dy: -3).contains(point) { return .delete }
    return nil
  }
}

struct SwipePoint {
  let location: CGPoint
  let timestamp: TimeInterval
}

struct SwipeVocabularyEntry {
  let frequency: Float
  let word: String
}

protocol SwipeDecoding {
  func predictions(
    for samples: [SwipePoint],
    layout: KeyLayout,
    vocabulary: [SwipeVocabularyEntry],
    contextWords: [String]
  ) -> [String]
}

extension SwipeDecoding {
  func predictions(
    for samples: [SwipePoint],
    layout: KeyLayout,
    vocabulary: [SwipeVocabularyEntry]
  ) -> [String] {
    predictions(
      for: samples,
      layout: layout,
      vocabulary: vocabulary,
      contextWords: []
    )
  }
}
