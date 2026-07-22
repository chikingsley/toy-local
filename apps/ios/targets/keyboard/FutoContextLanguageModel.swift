import Foundation

enum FutoContextLanguageModelError: Error {
  case invalidScoreOutput
  case missingVocabulary
}

final class FutoContextLanguageModel {
  private let bridge: TimberVoxExecuTorchBridge
  private let maximumContextLength: Int
  private let vocabulary: FutoContextVocabulary

  init(bridge: TimberVoxExecuTorchBridge, bundle: Bundle = .main) throws {
    guard
      let url = bundle.url(
        forResource: "futo_swipe_context_vocab",
        withExtension: "txt"
      ),
      let text = try? String(contentsOf: url, encoding: .utf8)
    else { throw FutoContextLanguageModelError.missingVocabulary }

    maximumContextLength = bridge.contextMaximumLength
    guard maximumContextLength > 0 else {
      throw FutoContextVocabularyError.invalidVocabulary
    }
    vocabulary = try FutoContextVocabulary(
      text: text,
      exactWordCount: bridge.contextExactWordCount,
      hashBucketCount: bridge.contextHashBucketCount
    )
    self.bridge = bridge
  }

  func scores(contextWords: [String], candidates: [String]) throws -> [Float] {
    guard !candidates.isEmpty else { return [] }
    let context = Array(contextWords.suffix(maximumContextLength))
    var contextIDs = [Int64](repeating: 0, count: maximumContextLength)
    var contextHashes = [Int64](repeating: 0, count: maximumContextLength * 2)
    for (index, word) in context.enumerated() {
      let lookup = vocabulary.lookup(word)
      contextIDs[index] = lookup.id
      contextHashes[index * 2] = lookup.hashes[0]
      contextHashes[index * 2 + 1] = lookup.hashes[1]
    }

    var candidateIDs: [Int64] = []
    var candidateHashes: [Int64] = []
    candidateIDs.reserveCapacity(candidates.count)
    candidateHashes.reserveCapacity(candidates.count * 2)
    for candidate in candidates {
      let lookup = vocabulary.lookup(candidate)
      candidateIDs.append(lookup.id)
      candidateHashes.append(contentsOf: lookup.hashes)
    }

    let output = try bridge.contextScores(
      withContextIds: Self.data(contextIDs),
      contextHashes: Self.data(contextHashes),
      contextWordCount: context.count,
      candidateIds: Self.data(candidateIDs),
      candidateHashes: Self.data(candidateHashes)
    )
    guard let scores = Self.floats(output), scores.count == candidates.count else {
      throw FutoContextLanguageModelError.invalidScoreOutput
    }
    return scores
  }

  private static func data(_ values: [Int64]) -> Data {
    values.withUnsafeBytes { Data($0) }
  }

  private static func floats(_ data: Data) -> [Float]? {
    guard data.count.isMultiple(of: MemoryLayout<Float>.size) else { return nil }
    return data.withUnsafeBytes { bytes in
      Array(bytes.bindMemory(to: Float.self))
    }
  }
}
