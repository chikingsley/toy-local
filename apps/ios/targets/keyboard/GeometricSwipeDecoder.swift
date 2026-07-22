import CoreGraphics
import Foundation

struct GeometricSwipeDecoder: SwipeDecoding {
  private let sampleCount = 32

  func predictions(
    for samples: [SwipePoint],
    layout: KeyLayout,
    vocabulary: [SwipeVocabularyEntry],
    contextWords: [String]
  ) -> [String] {
    let points = samples.map(\.location)
    let observed = resample(points, count: sampleCount)
    guard let firstPoint = observed.first, let lastPoint = observed.last else { return [] }

    return vocabulary.enumerated().compactMap { index, entry -> (String, CGFloat)? in
      let word = entry.word
      guard let first = word.first,
        let last = word.last,
        let firstFrame = layout.frames[first],
        let lastFrame = layout.frames[last]
      else { return nil }

      let startDistance = hypot(firstPoint.x - firstFrame.midX, firstPoint.y - firstFrame.midY)
      let endDistance = hypot(lastPoint.x - lastFrame.midX, lastPoint.y - lastFrame.midY)
      guard startDistance < 58, endDistance < 58 else { return nil }

      let template = word.compactMap { character -> CGPoint? in
        layout.frames[character].map { CGPoint(x: $0.midX, y: $0.midY) }
      }
      guard template.count == word.count else { return nil }
      let normalizedTemplate = resample(template, count: sampleCount)
      let shapeError =
        zip(observed, normalizedTemplate).reduce(CGFloat.zero) { total, pair in
          total + hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
        } / CGFloat(sampleCount)
      let frequencyBonus = CGFloat(log10(Double(max(1, entry.frequency)))) * 1.8
      let contextRankPenalty = CGFloat(index) * 0.002
      return (
        word,
        shapeError + (startDistance + endDistance) * 0.55
          + contextRankPenalty - frequencyBonus
      )
    }
    .sorted { $0.1 < $1.1 }
    .prefix(3)
    .map(\.0)
  }

  private func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
    guard points.count > 1, count > 1 else { return points }
    let distances = zip(points, points.dropFirst()).map { pair in
      hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
    let total = distances.reduce(0, +)
    guard total > 0 else { return Array(repeating: points[0], count: count) }

    var result: [CGPoint] = []
    var segmentIndex = 0
    var segmentStartDistance: CGFloat = 0
    for sampleIndex in 0..<count {
      let target = total * CGFloat(sampleIndex) / CGFloat(count - 1)
      while segmentIndex < distances.count - 1,
        segmentStartDistance + distances[segmentIndex] < target
      {
        segmentStartDistance += distances[segmentIndex]
        segmentIndex += 1
      }
      let segmentLength = max(distances[segmentIndex], 0.001)
      let fraction = (target - segmentStartDistance) / segmentLength
      let start = points[segmentIndex]
      let end = points[segmentIndex + 1]
      result.append(
        CGPoint(
          x: start.x + (end.x - start.x) * fraction,
          y: start.y + (end.y - start.y) * fraction
        ))
    }
    return result
  }
}
