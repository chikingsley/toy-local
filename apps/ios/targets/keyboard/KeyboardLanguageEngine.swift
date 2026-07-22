import Foundation

#if canImport(UIKit)
  import UIKit
#endif

struct KeyboardPersonalVocabularyDocument: Codable, Equatable {
  static let currentVersion = 2

  var entries: [KeyboardPersonalVocabularyEntry]
  var version: Int

  init(entries: [KeyboardPersonalVocabularyEntry], version: Int = currentVersion) {
    self.entries = entries
    self.version = version
  }
}

struct KeyboardPersonalVocabularyEntry: Codable, Equatable {
  var lastUsedAt: Double
  var pinnedSlot: Int?
  var usageCount: Int
  var value: String

  init(
    value: String,
    usageCount: Int = 0,
    pinnedSlot: Int? = nil,
    lastUsedAt: Double = 0
  ) {
    self.lastUsedAt = lastUsedAt
    self.pinnedSlot = pinnedSlot
    self.usageCount = usageCount
    self.value = value
  }

  private enum CodingKeys: String, CodingKey {
    case lastUsedAt
    case manualRank
    case pinnedSlot
    case usageCount
    case value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    lastUsedAt = try container.decodeIfPresent(Double.self, forKey: .lastUsedAt) ?? 0
    pinnedSlot =
      try container.decodeIfPresent(Int.self, forKey: .pinnedSlot)
      ?? container.decodeIfPresent(Int.self, forKey: .manualRank)
    usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
    value = try container.decode(String.self, forKey: .value)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(lastUsedAt, forKey: .lastUsedAt)
    try container.encodeIfPresent(pinnedSlot, forKey: .pinnedSlot)
    try container.encode(usageCount, forKey: .usageCount)
    try container.encode(value, forKey: .value)
  }
}

struct KeyboardContext {
  let contextWords: [String]
  let currentCompletion: String
  let currentCompletionText: String
  let currentWord: String
  let currentWordText: String
  let isSentenceStart: Bool
  let previousWord: String?

  init(textBeforeCursor: String) {
    let trailingCompletion = textBeforeCursor.reversed().prefix { character in
      KeyboardLanguageEngine.isPersonalCompletionCharacter(character)
    }
    currentCompletionText = String(trailingCompletion.reversed())
    currentCompletion = currentCompletionText.lowercased()

    let trailingWord = textBeforeCursor.reversed().prefix { character in
      character.isLetter || character == "'"
    }
    currentWordText = String(trailingWord.reversed())
    currentWord = currentWordText.lowercased()

    let committedText = String(textBeforeCursor.dropLast(currentCompletion.count))
    let lastCommittedCharacter = committedText.last { !$0.isWhitespace }
    isSentenceStart =
      lastCommittedCharacter == nil
      || lastCommittedCharacter == "."
      || lastCommittedCharacter == "!"
      || lastCommittedCharacter == "?"
    contextWords =
      committedText
      .split { character in !(character.isLetter || character == "'") }
      .suffix(16)
      .map { $0.lowercased() }
    previousWord = contextWords.last
  }
}

@MainActor
final class KeyboardLanguageEngine {
  private static let learnedBigramsKey = "keyboardLearnedBigrams"
  private static let learnedWordsKey = "keyboardLearnedWords"
  static let personalVocabularyKey = "keyboardPersonalVocabulary"
  static let personalVocabularyRevisionKey = "keyboardPersonalVocabularyRevision"
  private static let preferredFormsKey = "keyboardPreferredForms"
  private static let supplementaryFrequency: Float = 250_000

  private let baseVocabularyWords: Set<String>
  private let defaults: UserDefaults?
  private let vocabulary: [SwipeVocabularyEntry]
  private let indicesByInitial: [Character: [Int]]
  private let indicesByEndpoints: [String: [Int]]

  private var learnedBigrams: [String: Int]
  private var learnedIndicesByEndpoints: [String: Set<String>]
  private var learnedWords: [String: Int]
  private var personalEntries: [String: KeyboardPersonalVocabularyEntry] = [:]
  private var personalIndicesByEndpoints: [String: Set<String>] = [:]
  private var personalVocabularyRevision = -1
  private var preferredForms: [String: String]
  private var supplementaryIndicesByEndpoints: [String: Set<String>] = [:]
  private var supplementaryPreferredForms: [String: String] = [:]
  private var supplementaryWords: Set<String> = []

  #if canImport(UIKit)
    convenience init() {
      self.init(
        defaults: UserDefaults(suiteName: KeyboardBridge.group),
        vocabulary: Self.loadVocabulary()
      )
    }
  #endif

  init(
    defaults: UserDefaults?,
    vocabulary loadedVocabulary: [SwipeVocabularyEntry]
  ) {
    self.defaults = defaults
    vocabulary = loadedVocabulary
    baseVocabularyWords = Set(loadedVocabulary.map(\.word))
    indicesByInitial = Dictionary(grouping: loadedVocabulary.indices) {
      loadedVocabulary[$0].word.first ?? " "
    }
    indicesByEndpoints = Dictionary(grouping: loadedVocabulary.indices) { index in
      let word = loadedVocabulary[index].word
      return "\(word.first ?? " ")\(word.last ?? " ")"
    }
    learnedWords = defaults?.dictionary(forKey: Self.learnedWordsKey) as? [String: Int] ?? [:]
    learnedBigrams =
      defaults?.dictionary(forKey: Self.learnedBigramsKey) as? [String: Int] ?? [:]
    preferredForms =
      defaults?.dictionary(forKey: Self.preferredFormsKey) as? [String: String] ?? [:]
    learnedIndicesByEndpoints = Self.endpointIndex(for: learnedWords.keys)
    refreshPersonalVocabularyIfNeeded()
  }

  #if canImport(UIKit)
    func addSupplementaryLexicon(_ lexicon: UILexicon) {
      for entry in lexicon.entries {
        addSupplementaryWords([entry.documentText, entry.userInput])
      }
    }
  #endif

  func addSupplementaryWords(_ words: [String]) {
    for word in words {
      let normalized = word.lowercased()
      guard Self.isKeyboardWord(normalized) else { continue }
      supplementaryWords.insert(normalized)
      if Self.isSwipeWord(normalized), let endpointKey = Self.endpointKey(for: normalized) {
        supplementaryIndicesByEndpoints[endpointKey, default: []].insert(normalized)
      }
      if word != normalized {
        supplementaryPreferredForms[normalized] = word
      }
    }
  }

  func predictions(textBeforeCursor: String) -> [String] {
    refreshPersonalVocabularyIfNeeded()
    let context = KeyboardContext(textBeforeCursor: textBeforeCursor)
    if context.currentWord.isEmpty && context.currentCompletion.isEmpty {
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

    if !prefix.isEmpty {
      // The exact token always wins. A learned longer name must never turn the
      // nickname "Chi" into "Chibuzor" before the user types a stronger prefix.
      let exactTokenIsKnown =
        baseVocabularyWords.contains(prefix) || supplementaryWords.contains(prefix)
        || learnedWords[prefix] != nil || personalEntries[prefix] != nil
      include(prefix, bonus: exactTokenIsKnown ? 10_000_000 : 16)
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
        include(word, bonus: 24 + Double(count) * 5)
      }
    }

    let completionPrefix = context.currentCompletion
    if completionPrefix.count >= 4 || personalEntries[completionPrefix] != nil {
      let matchingPersonalEntries = Self.rankedPersonalEntries(
        personalEntries.values.filter { entry in
          entry.value.lowercased().hasPrefix(completionPrefix)
        }
      )
      for (index, entry) in matchingPersonalEntries.enumerated() {
        let normalized = entry.value.lowercased()
        let orderingBonus = max(0, 1_000_000 - Double(index) * 1_500)
        let usageBonus = Double(min(entry.usageCount, 100)) * 12
        let lengthPenalty = Double(max(0, normalized.count - completionPrefix.count)) * 0.1
        let score = 100 + orderingBonus + usageBonus - lengthPenalty
        scores[normalized] = max(scores[normalized] ?? -.infinity, score)
      }
    }

    let shouldCapitalize = context.currentWordText.first?.isUppercase ?? false
    return scores.sorted(by: Self.rankCandidates).prefix(3).map {
      displayForm(for: $0.key, capitalized: shouldCapitalize)
    }
  }

  func correction(for word: String) -> String? {
    refreshPersonalVocabularyIfNeeded()
    let normalized = word.lowercased()
    guard normalized.count > 1, let initial = normalized.first else { return nil }
    if supplementaryWords.contains(normalized) || learnedWords[normalized] != nil
      || personalEntries[normalized] != nil
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

  func learn(
    word: String,
    after previousWord: String?,
    atSentenceStart: Bool
  ) {
    refreshPersonalVocabularyIfNeeded()
    let normalized = word.lowercased()
    guard Self.isPersonalCompletion(normalized) else { return }

    if !Self.isKeyboardWord(normalized) {
      recordPersonalEntry(word)
      return
    }

    let isNewLearnedWord = learnedWords[normalized] == nil
    learnedWords[normalized, default: 0] += 1
    if isNewLearnedWord, Self.isSwipeWord(normalized),
      let endpointKey = Self.endpointKey(for: normalized)
    {
      learnedIndicesByEndpoints[endpointKey, default: []].insert(normalized)
    }
    if Self.shouldPreservePreferredForm(
      word,
      normalized: normalized,
      atSentenceStart: atSentenceStart,
      existsInBaseVocabulary: baseVocabularyWords.contains(normalized)
    ) {
      preferredForms[normalized] = word
    }
    if let previousWord, Self.isKeyboardWord(previousWord) {
      learnedBigrams[bigramKey(previousWord, normalized), default: 0] += 1
    }
    if Self.shouldTrackPersonalEntry(
      word,
      normalized: normalized,
      atSentenceStart: atSentenceStart,
      existsInBaseVocabulary: baseVocabularyWords.contains(normalized)
    ) {
      recordPersonalEntry(word)
    }
    trimAndPersistLearning()
  }

  func swipeVocabulary(
    first: Character,
    last: Character,
    previousWord: String?
  ) -> [SwipeVocabularyEntry] {
    refreshPersonalVocabularyIfNeeded()
    let endpointKey = "\(first.lowercased())\(last.lowercased())"
    var entriesByWord = Dictionary(
      uniqueKeysWithValues: (indicesByEndpoints[endpointKey] ?? []).map { index in
        let entry = vocabulary[index]
        return (entry.word, entry)
      }
    )
    for word in supplementaryIndicesByEndpoints[endpointKey] ?? [] {
      entriesByWord[word] = SwipeVocabularyEntry(
        frequency: max(entriesByWord[word]?.frequency ?? 0, Self.supplementaryFrequency),
        word: word
      )
    }
    for word in learnedIndicesByEndpoints[endpointKey] ?? [] where entriesByWord[word] == nil {
      entriesByWord[word] = SwipeVocabularyEntry(frequency: 1, word: word)
    }
    for word in personalIndicesByEndpoints[endpointKey] ?? [] where entriesByWord[word] == nil {
      entriesByWord[word] = SwipeVocabularyEntry(frequency: 1, word: word)
    }
    let personalizedEntries = entriesByWord.values.map { entry in
      SwipeVocabularyEntry(
        frequency: Float(contextualFrequency(entry, previousWord: previousWord)),
        word: entry.word
      )
    }
    return
      personalizedEntries
      .sorted { left, right in
        left.frequency > right.frequency
      }
  }

  func displayForm(for word: String, capitalized: Bool) -> String {
    refreshPersonalVocabularyIfNeeded()
    let normalized = word.lowercased()
    if let preferred = personalEntries[normalized]?.value ?? preferredForms[normalized]
      ?? supplementaryPreferredForms[normalized]
    {
      return preferred
    }
    return capitalized ? normalized.capitalized : normalized
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
      .map { displayForm(for: $0, capitalized: false) }
    return learned.isEmpty ? ["the", "and", "to"] : learned
  }

  private func contextualFrequency(
    _ entry: SwipeVocabularyEntry,
    previousWord: String?
  ) -> Double {
    let personalEntry = personalEntries[entry.word]
    let pinnedBonus =
      personalEntry?.pinnedSlot.map {
        max(0, 10_000_000_000 - Double($0) * 10_000_000)
      } ?? 0
    let personalUsageBonus = Double(min(personalEntry?.usageCount ?? 0, 100)) * 2_000_000
    return Double(entry.frequency)
      + Double(learnedWords[entry.word] ?? 0) * 500_000
      + Double(learnedBigrams[bigramKey(previousWord, entry.word)] ?? 0) * 1_000_000
      + pinnedBonus + personalUsageBonus
  }

  private func bigramKey(_ previousWord: String?, _ word: String) -> String {
    guard let previousWord else { return "" }
    return "\(previousWord)\u{1f}\(word)"
  }

  private func trimAndPersistLearning() {
    var didTrimWords = false
    if learnedWords.count > 2_000 {
      learnedWords = Dictionary(
        uniqueKeysWithValues: learnedWords.sorted {
          $0.value > $1.value
        }.prefix(1_500).map { ($0.key, $0.value) })
      didTrimWords = true
    }
    if learnedBigrams.count > 5_000 {
      learnedBigrams = Dictionary(
        uniqueKeysWithValues: learnedBigrams.sorted {
          $0.value > $1.value
        }.prefix(4_000).map { ($0.key, $0.value) })
    }
    if didTrimWords {
      learnedIndicesByEndpoints = Self.endpointIndex(for: learnedWords.keys)
      preferredForms = preferredForms.filter { learnedWords[$0.key] != nil }
    }
    defaults?.set(learnedWords, forKey: Self.learnedWordsKey)
    defaults?.set(learnedBigrams, forKey: Self.learnedBigramsKey)
    defaults?.set(preferredForms, forKey: Self.preferredFormsKey)
  }

  private func recordPersonalEntry(_ value: String) {
    let normalized = value.lowercased()
    guard Self.isPersonalCompletion(normalized) else { return }
    var entry =
      personalEntries[normalized]
      ?? KeyboardPersonalVocabularyEntry(value: value)
    entry.usageCount += 1
    entry.lastUsedAt = Date().timeIntervalSince1970
    if entry.pinnedSlot == nil {
      entry.value = value
    }
    personalEntries[normalized] = entry
    trimAndPersistPersonalVocabulary()
  }

  private func refreshPersonalVocabularyIfNeeded() {
    let revision = defaults?.integer(forKey: Self.personalVocabularyRevisionKey) ?? 0
    guard revision != personalVocabularyRevision else { return }
    personalVocabularyRevision = revision
    guard let json = defaults?.string(forKey: Self.personalVocabularyKey),
      let data = json.data(using: .utf8),
      let document = try? JSONDecoder().decode(
        KeyboardPersonalVocabularyDocument.self,
        from: data
      )
    else {
      personalEntries = [:]
      personalIndicesByEndpoints = [:]
      return
    }
    personalEntries = Dictionary(
      document.entries.compactMap { entry in
        let normalized = entry.value.lowercased()
        guard Self.isPersonalCompletion(normalized) else { return nil }
        return (normalized, entry)
      },
      uniquingKeysWith: Self.preferredPersonalEntry
    )
    personalIndicesByEndpoints = Self.endpointIndex(for: personalEntries.keys)
  }

  private func trimAndPersistPersonalVocabulary() {
    let ranked = Self.rankedPersonalEntries(Array(personalEntries.values))
    if ranked.count > 500 {
      personalEntries = Dictionary(
        uniqueKeysWithValues: ranked.prefix(400).map { ($0.value.lowercased(), $0) }
      )
    }
    personalIndicesByEndpoints = Self.endpointIndex(for: personalEntries.keys)
    let document = KeyboardPersonalVocabularyDocument(
      entries: Self.rankedPersonalEntries(Array(personalEntries.values))
    )
    guard let data = try? JSONEncoder().encode(document),
      let json = String(data: data, encoding: .utf8)
    else { return }
    defaults?.set(json, forKey: Self.personalVocabularyKey)
    let revision = (defaults?.integer(forKey: Self.personalVocabularyRevisionKey) ?? 0) + 1
    defaults?.set(revision, forKey: Self.personalVocabularyRevisionKey)
    personalVocabularyRevision = revision
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

  nonisolated static func isPersonalCompletionCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || "'@._-+%".contains(character)
  }

  private static func isPersonalCompletion(_ value: String) -> Bool {
    (2...254).contains(value.count)
      && value.contains(where: { $0.isLetter || $0.isNumber })
      && value.allSatisfy(isPersonalCompletionCharacter)
  }

  private static func isSwipeWord(_ word: String) -> Bool {
    isKeyboardWord(word) && word.allSatisfy { ("a"..."z").contains($0) }
  }

  private static func endpointIndex<S: Sequence>(for words: S) -> [String: Set<String>]
  where S.Element == String {
    Dictionary(grouping: words.filter(isSwipeWord), by: { endpointKey(for: $0) ?? "" })
      .mapValues(Set.init)
  }

  private static func endpointKey(for word: String) -> String? {
    guard let first = word.first, let last = word.last else { return nil }
    return "\(first)\(last)"
  }

  private static func shouldPreservePreferredForm(
    _ word: String,
    normalized: String,
    atSentenceStart: Bool,
    existsInBaseVocabulary: Bool
  ) -> Bool {
    guard word != normalized else { return false }
    let hasInternalUppercase = word.dropFirst().contains(where: \.isUppercase)
    return hasInternalUppercase || !atSentenceStart || !existsInBaseVocabulary
  }

  private static func shouldTrackPersonalEntry(
    _ word: String,
    normalized: String,
    atSentenceStart: Bool,
    existsInBaseVocabulary: Bool
  ) -> Bool {
    !existsInBaseVocabulary
      || word.dropFirst().contains(where: \.isUppercase)
      || (!atSentenceStart && word.first?.isUppercase == true)
      || normalized.contains(where: { $0.isNumber })
  }

  private static func preferredPersonalEntry(
    _ left: KeyboardPersonalVocabularyEntry,
    _ right: KeyboardPersonalVocabularyEntry
  ) -> KeyboardPersonalVocabularyEntry {
    if left.pinnedSlot != nil && right.pinnedSlot == nil { return left }
    if right.pinnedSlot != nil && left.pinnedSlot == nil { return right }
    if let leftSlot = left.pinnedSlot, let rightSlot = right.pinnedSlot,
      leftSlot != rightSlot
    {
      return leftSlot < rightSlot ? left : right
    }
    if left.usageCount == right.usageCount { return left.lastUsedAt >= right.lastUsedAt ? left : right }
    return left.usageCount >= right.usageCount ? left : right
  }

  private static func automaticallyRanksBefore(
    _ left: KeyboardPersonalVocabularyEntry,
    _ right: KeyboardPersonalVocabularyEntry
  ) -> Bool {
    if left.usageCount != right.usageCount { return left.usageCount > right.usageCount }
    if left.lastUsedAt != right.lastUsedAt { return left.lastUsedAt > right.lastUsedAt }
    return left.value.localizedCaseInsensitiveCompare(right.value) == .orderedAscending
  }

  static func rankedPersonalEntries(
    _ entries: [KeyboardPersonalVocabularyEntry]
  ) -> [KeyboardPersonalVocabularyEntry] {
    guard entries.count > 1 else { return entries }
    var slots = [KeyboardPersonalVocabularyEntry?](
      repeating: nil,
      count: entries.count
    )
    let pinned = entries.filter { $0.pinnedSlot != nil }.sorted { left, right in
      let leftSlot = left.pinnedSlot ?? 0
      let rightSlot = right.pinnedSlot ?? 0
      if leftSlot != rightSlot { return leftSlot < rightSlot }
      return automaticallyRanksBefore(left, right)
    }
    for entry in pinned {
      var slot = min(entry.pinnedSlot ?? 0, slots.count - 1)
      while slot < slots.count, slots[slot] != nil {
        slot += 1
      }
      if slot >= slots.count,
        let availableSlot = slots.lastIndex(where: { $0 == nil })
      {
        slot = availableSlot
      }
      if slot < slots.count {
        slots[slot] = entry
      }
    }

    let automatic = entries.filter { $0.pinnedSlot == nil }.sorted(
      by: automaticallyRanksBefore
    )
    var automaticIndex = 0
    return slots.compactMap { entry in
      if let entry { return entry }
      defer { automaticIndex += 1 }
      return automatic[automaticIndex]
    }
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
