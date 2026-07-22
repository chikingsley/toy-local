import Foundation

enum FutoContextVocabularyError: Error {
  case invalidVocabulary
}

struct FutoContextVocabulary {
  let exactWordCount: Int
  let hashBucketCount: Int
  private let wordIDs: [String: Int64]

  init(
    text: String,
    exactWordCount: Int,
    hashBucketCount: Int
  ) throws {
    let words = text.split(whereSeparator: \.isNewline).map(String.init)
    guard exactWordCount == words.count, hashBucketCount > 0 else {
      throw FutoContextVocabularyError.invalidVocabulary
    }
    self.exactWordCount = exactWordCount
    self.hashBucketCount = hashBucketCount
    wordIDs = Dictionary(
      words.enumerated().map { index, word in
        (word, Int64(index))
      },
      uniquingKeysWith: { first, _ in first }
    )
  }

  func lookup(_ rawWord: String) -> (id: Int64, hashes: [Int64]) {
    let word = rawWord.lowercased()
    if let id = wordIDs[word] {
      return (id, [0, 0])
    }
    return (
      Int64(exactWordCount),
      FutoWordHash.bucketIndices(for: word, bucketCount: hashBucketCount)
    )
  }
}
