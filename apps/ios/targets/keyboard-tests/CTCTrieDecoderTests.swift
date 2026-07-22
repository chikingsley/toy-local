import XCTest

@testable import TimberVoxSwipeDecoder

final class CTCTrieDecoderTests: XCTestCase {
  private let decoder = CTCTrieDecoder()

  func testRanksWhenFirstFromSyntheticEmissions() {
    let emissions = makeEmissions(for: Array("when"))
    let vocabulary = [
      SwipeVocabularyEntry(frequency: 1_531_731, word: "when"),
      SwipeVocabularyEntry(frequency: 1_786, word: "watermelon"),
      SwipeVocabularyEntry(frequency: 40_246, word: "written"),
    ]

    XCTAssertEqual(
      decoder.predictions(for: emissions, vocabulary: vocabulary).first,
      "when"
    )
  }

  func testRanksReportedLongWordRegressionsFromSyntheticEmissions() {
    for word in ["haptic", "industrial"] {
      let emissions = makeEmissions(for: Array(word))
      let vocabulary = [
        SwipeVocabularyEntry(frequency: 5_374, word: word),
        SwipeVocabularyEntry(frequency: 100_000, word: "habit"),
        SwipeVocabularyEntry(frequency: 100_000, word: "individual"),
      ]

      XCTAssertEqual(
        decoder.predictions(for: emissions, vocabulary: vocabulary).first,
        word
      )
    }
  }

  func testContextScoresCanPromoteCandidateAndPreserveCTCTopInSlate() {
    let candidates = [
      CTCDecodedCandidate(score: 10, word: "their"),
      CTCDecodedCandidate(score: 9.5, word: "there"),
      CTCDecodedCandidate(score: 9, word: "three"),
      CTCDecodedCandidate(score: 8.5, word: "these"),
    ]

    XCTAssertEqual(
      ContextCandidateReranker.predictions(
        candidates: candidates,
        languageModelScores: [0, 10, 2, 1]
      ),
      ["there", "three", "their"]
    )
  }

  func testBlankSeparatesRepeatedLetters() {
    let emissions = makeEmissions(for: Array("letter"))
    let vocabulary = [
      SwipeVocabularyEntry(frequency: 100_000, word: "letter"),
      SwipeVocabularyEntry(frequency: 100_000, word: "leter"),
    ]

    XCTAssertEqual(
      decoder.predictions(for: emissions, vocabulary: vocabulary).first,
      "letter"
    )
  }

  func testRepeatedLettersDoNotRequireBlankEmissions() {
    let emissions = makeEmissionsWithoutBlanks(for: Array("hello"))
    let vocabulary = [
      SwipeVocabularyEntry(frequency: 100_000, word: "hello"),
      SwipeVocabularyEntry(frequency: 100_000, word: "helo"),
    ]

    XCTAssertEqual(
      decoder.predictions(for: emissions, vocabulary: vocabulary).first,
      "hello"
    )
  }

  func testIgnoresWordsOutsideModelAlphabet() {
    let emissions = makeEmissions(for: Array("cant"))
    let vocabulary = [
      SwipeVocabularyEntry(frequency: 10_000_000, word: "can't"),
      SwipeVocabularyEntry(frequency: 100_000, word: "cant"),
    ]

    XCTAssertEqual(
      decoder.predictions(for: emissions, vocabulary: vocabulary).first,
      "cant"
    )
  }

  private func makeEmissions(for characters: [Character]) -> CTCEmissionSequence {
    let blankIndex = CharacterOrder.count
    let labels = characters.flatMap { character -> [Int] in
      [CharacterOrder.indexByCharacter[character]!, blankIndex]
    }
    let classCount = CharacterOrder.count + 1
    var probabilities = [Float](
      repeating: -12,
      count: labels.count * classCount
    )
    for (timeStep, classIndex) in labels.enumerated() {
      probabilities[timeStep * classCount + classIndex] = 0
    }
    return CTCEmissionSequence(
      classCount: classCount,
      logProbabilities: probabilities,
      timeStepCount: labels.count
    )
  }

  private func makeEmissionsWithoutBlanks(
    for characters: [Character]
  ) -> CTCEmissionSequence {
    let classCount = CharacterOrder.count + 1
    var probabilities = [Float](
      repeating: -12,
      count: characters.count * classCount
    )
    for (timeStep, character) in characters.enumerated() {
      let classIndex = CharacterOrder.indexByCharacter[character]!
      probabilities[timeStep * classCount + classIndex] = 0
    }
    return CTCEmissionSequence(
      classCount: classCount,
      logProbabilities: probabilities,
      timeStepCount: characters.count
    )
  }
}
