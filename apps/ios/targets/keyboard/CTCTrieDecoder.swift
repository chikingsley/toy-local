import Foundation

struct CTCEmissionSequence {
  let classCount: Int
  let logProbabilities: [Float]
  let timeStepCount: Int

  func probability(at timeStep: Int, classIndex: Int) -> Float {
    logProbabilities[timeStep * classCount + classIndex]
  }
}

struct CTCScoringParameters {
  let frequencyBonus: Double
  let lengthBonus: Double
  let lengthNormalizationExponent: Double
  let pruningLengthBonus: Double
  let pruningLengthNormalizationExponent: Double

  static let futoEncoderAndRefiner = CTCScoringParameters(
    frequencyBonus: 0.0134,
    lengthBonus: 0.7271,
    lengthNormalizationExponent: 0.5949,
    pruningLengthBonus: 1.2727,
    pruningLengthNormalizationExponent: 0.1902
  )

  static let futoEncoderRefinerAndContext = CTCScoringParameters(
    frequencyBonus: 0.0060,
    lengthBonus: 2.2138,
    lengthNormalizationExponent: 0.1126,
    pruningLengthBonus: 1.2727,
    pruningLengthNormalizationExponent: 0.1902
  )
}

struct CTCDecodedCandidate: Equatable {
  let score: Double
  let word: String
}

enum ContextCandidateReranker {
  static func predictions(
    candidates: [CTCDecodedCandidate],
    languageModelScores: [Float],
    languageModelWeight: Double = 0.6387,
    limit: Int = 3
  ) -> [String] {
    guard candidates.count == languageModelScores.count else {
      return Array(candidates.prefix(limit).map(\.word))
    }
    let ctcTop = candidates.first?.word
    var words = zip(candidates, languageModelScores).map { candidate, lmScore in
      (candidate.word, candidate.score + languageModelWeight * Double(lmScore))
    }
    .sorted { left, right in
      if left.1 == right.1 { return left.0 < right.0 }
      return left.1 > right.1
    }
    .prefix(limit)
    .map(\.0)
    if let ctcTop, !words.contains(ctcTop), !words.isEmpty {
      words[words.count - 1] = ctcTop
    }
    return words
  }
}

struct CTCTrieDecoder {
  private let beamWidth: Int
  private let scoring: CTCScoringParameters

  init(
    beamWidth: Int = 100,
    scoring: CTCScoringParameters = .futoEncoderAndRefiner
  ) {
    self.beamWidth = beamWidth
    self.scoring = scoring
  }

  func predictions(
    for emissions: CTCEmissionSequence,
    vocabulary: [SwipeVocabularyEntry]
  ) -> [String] {
    candidates(for: emissions, vocabulary: vocabulary, limit: 3).map(\.word)
  }

  func candidates(
    for emissions: CTCEmissionSequence,
    vocabulary: [SwipeVocabularyEntry],
    limit: Int
  ) -> [CTCDecodedCandidate] {
    guard emissions.classCount == CharacterOrder.count + 1,
      emissions.timeStepCount > 0,
      emissions.logProbabilities.count
        == emissions.classCount * emissions.timeStepCount
    else { return [] }

    let root = makeTrie(vocabulary: vocabulary)
    let blankIndex = emissions.classCount - 1
    var beams = [
      BeamKey(prefix: "", endedInBlank: false): Beam(node: root, score: 0)
    ]

    for timeStep in 0..<emissions.timeStepCount {
      var nextBeams: [BeamKey: Beam] = [:]
      for (key, beam) in beams {
        merge(
          key: BeamKey(prefix: key.prefix, endedInBlank: true),
          node: beam.node,
          score: beam.score
            + Double(emissions.probability(at: timeStep, classIndex: blankIndex)),
          into: &nextBeams
        )

        for (character, child) in beam.node.children {
          guard let classIndex = CharacterOrder.indexByCharacter[character] else { continue }
          merge(
            key: BeamKey(
              prefix: key.prefix + String(character),
              endedInBlank: false
            ),
            node: child,
            score: beam.score
              + Double(emissions.probability(at: timeStep, classIndex: classIndex)),
            into: &nextBeams
          )
        }

        if !key.endedInBlank,
          let lastCharacter = key.prefix.last,
          let classIndex = CharacterOrder.indexByCharacter[lastCharacter]
        {
          merge(
            key: key,
            node: beam.node,
            score: beam.score
              + Double(emissions.probability(at: timeStep, classIndex: classIndex)),
            into: &nextBeams
          )
        }
      }

      let strongestBeams = nextBeams.sorted { left, right in
        pruneScore(left.key, beam: left.value)
          > pruneScore(right.key, beam: right.value)
      }.prefix(beamWidth)
      beams = Dictionary(
        uniqueKeysWithValues: strongestBeams.map { ($0.key, $0.value) }
      )
    }

    return beams.compactMap { key, beam -> CTCDecodedCandidate? in
      guard beam.node.frequency > 0 else { return nil }
      let length = Double(max(key.prefix.count, 1))
      let score =
        beam.score / pow(length, scoring.lengthNormalizationExponent)
        + scoring.lengthBonus * length
        + scoring.frequencyBonus * log(Double(beam.node.frequency))
      return CTCDecodedCandidate(score: score, word: key.prefix)
    }
    .sorted { left, right in
      if left.score == right.score { return left.word < right.word }
      return left.score > right.score
    }
    .prefix(limit)
    .map { $0 }
  }

  private func makeTrie(vocabulary: [SwipeVocabularyEntry]) -> TrieNode {
    let root = TrieNode()
    for entry in vocabulary {
      guard entry.word.allSatisfy({ CharacterOrder.indexByCharacter[$0] != nil }) else {
        continue
      }
      var node = root
      for character in entry.word {
        if let child = node.children[character] {
          node = child
        } else {
          let child = TrieNode()
          node.children[character] = child
          node = child
        }
      }
      node.frequency = entry.frequency
    }
    return root
  }

  private func merge(
    key: BeamKey,
    node: TrieNode,
    score: Double,
    into beams: inout [BeamKey: Beam]
  ) {
    if let existing = beams[key], existing.score >= score { return }
    beams[key] = Beam(node: node, score: score)
  }

  private func pruneScore(_ key: BeamKey, beam: Beam) -> Double {
    let length = Double(max(key.prefix.count, 1))
    return
      beam.score / pow(length, scoring.pruningLengthNormalizationExponent)
      + scoring.pruningLengthBonus * Double(key.prefix.count)
  }
}

enum CharacterOrder {
  static let characters = Array("abcdefghijklmnopqrstuvwxyz")
  static let count = characters.count
  static let indexByCharacter = Dictionary(
    uniqueKeysWithValues: characters.enumerated().map { ($0.element, $0.offset) }
  )
}

private final class TrieNode {
  var children: [Character: TrieNode] = [:]
  var frequency: Float = 0
}

private struct BeamKey: Hashable {
  let prefix: String
  let endedInBlank: Bool
}

private struct Beam {
  let node: TrieNode
  let score: Double
}
