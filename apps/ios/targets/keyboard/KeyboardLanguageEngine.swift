import Foundation
import UIKit

struct KeyboardContext {
  let currentWord: String
  let previousWord: String?

  init(textBeforeCursor: String) {
    let trailingWord = textBeforeCursor.reversed().prefix { character in
      character.isLetter || character == "'"
    }
    currentWord = String(trailingWord.reversed()).lowercased()

    let committedText =
      currentWord.isEmpty
      ? textBeforeCursor
      : String(textBeforeCursor.dropLast(currentWord.count))
    previousWord =
      committedText
      .split { character in !(character.isLetter || character == "'") }
      .last?
      .lowercased()
  }
}

struct SwipeVocabularyEntry {
  let frequency: Float
  let word: String
}

@MainActor
final class KeyboardLanguageEngine {
  private let defaults = UserDefaults(suiteName: KeyboardBridge.group)
  private let vocabulary: [SwipeVocabularyEntry]
  private let indicesByInitial: [Character: [Int]]
  private let indicesByEndpoints: [String: [Int]]

  private var learnedBigrams: [String: Int]
  private var learnedWords: [String: Int]
  private var supplementaryWords: Set<String> = []

  init() {
    let loadedVocabulary = Self.loadVocabulary()
    vocabulary = loadedVocabulary
    indicesByInitial = Dictionary(grouping: loadedVocabulary.indices) {
      loadedVocabulary[$0].word.first ?? " "
    }
    indicesByEndpoints = Dictionary(grouping: loadedVocabulary.indices) { index in
      let word = loadedVocabulary[index].word
      return "\(word.first ?? " ")\(word.last ?? " ")"
    }
    learnedWords = defaults?.dictionary(forKey: "keyboardLearnedWords") as? [String: Int] ?? [:]
    learnedBigrams = defaults?.dictionary(forKey: "keyboardLearnedBigrams") as? [String: Int] ?? [:]
  }

  func addSupplementaryLexicon(_ lexicon: UILexicon) {
    supplementaryWords.formUnion(
      lexicon.entries.flatMap { entry in
        [entry.userInput.lowercased(), entry.documentText.lowercased()]
      }.filter(Self.isKeyboardWord)
    )
  }

  func predictions(textBeforeCursor: String) -> [String] {
    let context = KeyboardContext(textBeforeCursor: textBeforeCursor)
    if context.currentWord.isEmpty {
      return nextWordPredictions(after: context.previousWord)
    }

    var scores: [String: Double] = [:]
    let prefix = context.currentWord
    let previous = context.previousWord

    func include(_ word: String, frequency: Float? = nil, bonus: Double = 0) {
      let normalized = word.lowercased()
      guard Self.isKeyboardWord(normalized), normalized.hasPrefix(prefix) else { return }
      let frequencyScore = frequency.map { log10(Double(max(1, $0))) * 5 } ?? 0
      let learned = Double(learnedWords[normalized] ?? 0) * 8
      let bigram = Double(learnedBigrams[bigramKey(previous, normalized)] ?? 0) * 14
      scores[normalized] = max(
        scores[normalized] ?? -.infinity,
        frequencyScore + learned + bigram + bonus
      )
    }

    include(prefix, bonus: 16)
    for word in supplementaryWords where word.hasPrefix(prefix) {
      include(word, bonus: 42)
    }
    if let initial = prefix.first {
      for index in indicesByInitial[initial] ?? [] {
        let entry = vocabulary[index]
        guard entry.word.hasPrefix(prefix) else { continue }
        include(entry.word, frequency: entry.frequency)
      }
    }
    for (word, count) in learnedWords where count > 0 && word.hasPrefix(prefix) {
      include(word, bonus: Double(count) * 5)
    }

    return scores.sorted(by: Self.rankCandidates).prefix(3).map(\.key)
  }

  func correction(for word: String) -> String? {
    let normalized = word.lowercased()
    guard normalized.count > 1, let initial = normalized.first else { return nil }
    if supplementaryWords.contains(normalized) || learnedWords[normalized] != nil
      || (indicesByInitial[initial] ?? []).contains(where: { vocabulary[$0].word == normalized })
    {
      return nil
    }

    let ranked = (indicesByInitial[initial] ?? []).compactMap { index -> (String, Double)? in
      let entry = vocabulary[index]
      guard abs(entry.word.count - normalized.count) <= 2 else { return nil }
      let distance = Self.editDistance(entry.word, normalized)
      guard distance <= 2 else { return nil }
      let editPenalty = Double(distance) * 30
      let frequencyBonus = log10(Double(max(1, entry.frequency))) * 3
      let learnedBonus = Double(learnedWords[entry.word] ?? 0) * 10
      return (entry.word, editPenalty - frequencyBonus - learnedBonus)
    }
    return ranked.min { $0.1 < $1.1 }?.0
  }

  func learn(word: String, after previousWord: String?) {
    let normalized = word.lowercased()
    guard Self.isKeyboardWord(normalized) else { return }
    learnedWords[normalized, default: 0] += 1
    if let previousWord, Self.isKeyboardWord(previousWord) {
      learnedBigrams[bigramKey(previousWord, normalized), default: 0] += 1
    }
    trimAndPersistLearning()
  }

  func swipeVocabulary(
    first: Character,
    last: Character,
    estimatedLength: Int,
    previousWord: String?
  ) -> [SwipeVocabularyEntry] {
    let endpointKey = "\(first.lowercased())\(last.lowercased())"
    let candidates = (indicesByEndpoints[endpointKey] ?? []).map { vocabulary[$0] }
    return
      candidates
      .filter { abs($0.word.count - estimatedLength) <= 5 }
      .sorted { left, right in
        contextualFrequency(left, previousWord: previousWord)
          > contextualFrequency(right, previousWord: previousWord)
      }
  }

  private func nextWordPredictions(after previousWord: String?) -> [String] {
    guard let previousWord else { return ["I", "the", "and"] }
    let prefix = "\(previousWord)\u{1f}"
    let learned =
      learnedBigrams
      .filter { $0.key.hasPrefix(prefix) }
      .sorted { left, right in
        if left.value == right.value { return left.key < right.key }
        return left.value > right.value
      }
      .prefix(3)
      .compactMap { $0.key.split(separator: "\u{1f}").last.map(String.init) }
    return learned.isEmpty ? ["the", "and", "to"] : learned
  }

  private func contextualFrequency(
    _ entry: SwipeVocabularyEntry,
    previousWord: String?
  ) -> Double {
    Double(entry.frequency)
      + Double(learnedWords[entry.word] ?? 0) * 500_000
      + Double(learnedBigrams[bigramKey(previousWord, entry.word)] ?? 0) * 1_000_000
  }

  private func bigramKey(_ previousWord: String?, _ word: String) -> String {
    guard let previousWord else { return "" }
    return "\(previousWord)\u{1f}\(word)"
  }

  private func trimAndPersistLearning() {
    if learnedWords.count > 2_000 {
      learnedWords = Dictionary(
        uniqueKeysWithValues: learnedWords.sorted {
          $0.value > $1.value
        }.prefix(1_500).map { ($0.key, $0.value) })
    }
    if learnedBigrams.count > 5_000 {
      learnedBigrams = Dictionary(
        uniqueKeysWithValues: learnedBigrams.sorted {
          $0.value > $1.value
        }.prefix(4_000).map { ($0.key, $0.value) })
    }
    defaults?.set(learnedWords, forKey: "keyboardLearnedWords")
    defaults?.set(learnedBigrams, forKey: "keyboardLearnedBigrams")
  }

  private static func loadVocabulary() -> [SwipeVocabularyEntry] {
    guard let url = Bundle.main.url(forResource: "english_frequency", withExtension: "txt"),
      let text = try? String(contentsOf: url, encoding: .utf8)
    else { return [] }
    return text.split(whereSeparator: \.isNewline).prefix(25_000).compactMap { line in
      let pieces = line.split(separator: " ", maxSplits: 1)
      guard pieces.count == 2,
        let frequency = Float(pieces[1]),
        isKeyboardWord(String(pieces[0]))
      else { return nil }
      return SwipeVocabularyEntry(frequency: frequency, word: String(pieces[0]))
    }
  }

  private static func isKeyboardWord(_ word: String) -> Bool {
    (2...20).contains(word.count)
      && word.allSatisfy { $0.isASCII && ($0.isLetter || $0 == "'") }
  }

  private static func rankCandidates(
    _ left: Dictionary<String, Double>.Element,
    _ right: Dictionary<String, Double>.Element
  ) -> Bool {
    if left.value == right.value { return left.key < right.key }
    return left.value > right.value
  }

  private static func editDistance(_ left: String, _ right: String) -> Int {
    let leftCharacters = Array(left)
    let rightCharacters = Array(right)
    var previous = Array(0...rightCharacters.count)
    for (leftIndex, leftCharacter) in leftCharacters.enumerated() {
      var current = [leftIndex + 1]
      for (rightIndex, rightCharacter) in rightCharacters.enumerated() {
        current.append(
          min(
            current[rightIndex] + 1,
            previous[rightIndex + 1] + 1,
            previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
          )
        )
      }
      previous = current
    }
    return previous.last ?? 0
  }
}
