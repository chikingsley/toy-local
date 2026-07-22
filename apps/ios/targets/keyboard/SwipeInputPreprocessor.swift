import CoreGraphics
import Foundation

enum SwipeInputPreprocessorError: Error {
  case traceTooShort
}

enum SwipeInputPreprocessor {
  static let inputPointCount = 64

  static func normalizedTrace(
    samples: [SwipePoint],
    layoutSize: CGSize
  ) throws -> (x: [Float], y: [Float]) {
    guard samples.count > 1 else {
      throw SwipeInputPreprocessorError.traceTooShort
    }
    let startTime = samples[0].timestamp
    let duration = max(samples.last?.timestamp ?? startTime, startTime) - startTime
    let timeSampled: [CGPoint]
    if duration > 0.001 {
      let countAt60Hz = max(2, Int((duration * 60).rounded()) + 1)
      timeSampled = (0..<countAt60Hz).map { index in
        let progress = Double(index) / Double(countAt60Hz - 1)
        return interpolate(
          samples: samples,
          timestamp: startTime + duration * progress
        )
      }
    } else {
      timeSampled = samples.map(\.location)
    }
    let points = resample(points: timeSampled, count: inputPointCount)
    let width = max(layoutSize.width, 1)
    let height = max(layoutSize.height, 1)
    return (
      points.map { Float($0.x / width) },
      points.map { Float($0.y / height) }
    )
  }

  private static func interpolate(
    samples: [SwipePoint],
    timestamp: TimeInterval
  ) -> CGPoint {
    guard timestamp > samples[0].timestamp else { return samples[0].location }
    for index in 1..<samples.count where samples[index].timestamp >= timestamp {
      let left = samples[index - 1]
      let right = samples[index]
      let interval = max(right.timestamp - left.timestamp, 0.000_001)
      let progress = CGFloat((timestamp - left.timestamp) / interval)
      return CGPoint(
        x: left.location.x + (right.location.x - left.location.x) * progress,
        y: left.location.y + (right.location.y - left.location.y) * progress
      )
    }
    return samples.last?.location ?? .zero
  }

  private static func resample(points: [CGPoint], count: Int) -> [CGPoint] {
    guard points.count > 1, count > 1 else { return points }
    return (0..<count).map { index in
      let sourceIndex = CGFloat(index) * CGFloat(points.count - 1) / CGFloat(count - 1)
      let lowerIndex = Int(sourceIndex.rounded(.down))
      let upperIndex = min(lowerIndex + 1, points.count - 1)
      let progress = sourceIndex - CGFloat(lowerIndex)
      let lower = points[lowerIndex]
      let upper = points[upperIndex]
      return CGPoint(
        x: lower.x + (upper.x - lower.x) * progress,
        y: lower.y + (upper.y - lower.y) * progress
      )
    }
  }
}
