import Combine
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()
  private var hostingController: UIHostingController<KeyboardRootView>?
  private var keyboardHeightConstraint: NSLayoutConstraint?
  private var pollTimer: Timer?
  private var blockedStreamingRequestID: String?
  private var insertedPartialText = ""
  private var lastKeyboardSeenWrite = Date.distantPast
  private var lastPartialTranscriptRevision = -1
  private var lastTranscriptRevision = -1
  private var streamingInsertionPrefix = ""
  private var streamingRequestID: String?

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    configureSystemKeyboardBehavior()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureSystemKeyboardBehavior()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    KeyboardBridge.initialize()
    view.backgroundColor = .clear
    view.clipsToBounds = true
    model.controller = self
    model.proxy = textDocumentProxy
    requestSupplementaryLexicon { [weak self] lexicon in
      Task { @MainActor in
        self?.model.addSupplementaryLexicon(lexicon)
      }
    }
    installKeyboard()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureSystemKeyboardBehavior()
    configureKeyboardHeight()
    model.controller = self
    model.proxy = textDocumentProxy
    model.hasFullAccess = hasFullAccess
    lastKeyboardSeenWrite = Date()
    KeyboardBridge.set(true, for: .keyboardSeen)
    KeyboardBridge.set(hasFullAccess, for: .keyboardHasFullAccess)
    KeyboardBridge.set(false, for: .keyboardVerificationRequired)
    KeyboardBridge.set(
      KeyboardBridge.integer(for: .keyboardStatusRevision) + 1,
      for: .keyboardStatusRevision
    )
    KeyboardBridge.synchronize()
    KeyboardStatusNotifier.post(hasFullAccess: hasFullAccess)
    model.refreshBridgeState()
    model.refreshSuggestions()
    startPolling()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      model.needsGlobe = needsInputModeSwitchKey
      model.refreshTraits()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.model.prepareSwipeContext()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    pollTimer?.invalidate()
    pollTimer = nil
    model.flushLearning()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    model.releaseSwipeContext()
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    model.proxy = textDocumentProxy
    model.refreshCapitalization()
    model.refreshTraits()
    model.refreshSuggestions()
  }

  override func textWillChange(_ textInput: UITextInput?) {
    super.textWillChange(textInput)
    model.proxy = textDocumentProxy
    model.refreshTraits()
  }

  private func installKeyboard() {
    let keyboard = KeyboardRootView(model: model)
    let hosting = UIHostingController(rootView: keyboard)
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    addChild(hosting)
    let container: UIInputView
    if let inputView {
      container = inputView
    } else {
      let generatedInputView = UIInputView(frame: .zero, inputViewStyle: .keyboard)
      generatedInputView.allowsSelfSizing = true
      inputView = generatedInputView
      container = generatedInputView
    }
    container.backgroundColor = .clear
    container.clipsToBounds = true
    container.addSubview(hosting.view)
    hosting.didMove(toParent: self)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    configureKeyboardHeight()
    hostingController = hosting
  }

  private func configureSystemKeyboardBehavior() {
    hasDictationKey = true
  }

  private func configureKeyboardHeight() {
    preferredContentSize = CGSize(width: 0, height: KeyboardMetrics.totalHeight)
    keyboardHeightConstraint?.isActive = false
    let constraint = view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.totalHeight)
    constraint.priority = .required
    constraint.isActive = true
    keyboardHeightConstraint = constraint
  }

  private func startPolling() {
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
      self?.pollBridge()
    }
    pollBridge()
  }

  private func pollBridge() {
    let now = Date()
    if !KeyboardBridge.bool(for: .keyboardSeen)
      || now.timeIntervalSince(lastKeyboardSeenWrite) >= 5
    {
      lastKeyboardSeenWrite = now
      KeyboardBridge.set(true, for: .keyboardSeen)
    }
    model.refreshBridgeState()
    applyPartialTranscriptIfNeeded()
    let revision = KeyboardBridge.integer(for: .transcriptRevision)
    guard revision != lastTranscriptRevision else { return }
    lastTranscriptRevision = revision
    guard let resultID = KeyboardBridge.string(for: .finalResultId), !resultID.isEmpty,
      resultID != KeyboardBridge.string(for: .consumedResultId),
      let requestID = KeyboardBridge.string(for: .finalRequestId),
      requestID == KeyboardBridge.string(for: .keyboardRequestId)
    else { return }
    let text = KeyboardBridge.string(for: .finalTranscript) ?? ""
    let status = KeyboardBridge.string(for: .finalResultStatus) ?? "failed"
    if !text.isEmpty {
      deliverFinalText(text, requestID: requestID)
      model.dictationFeedback(.success)
    } else if status == "no_speech" {
      discardStreamedText(requestID: requestID)
      model.dictationFeedback(.warning)
      model.predictions = ["No speech", "Try", "again"]
    } else {
      discardStreamedText(requestID: requestID)
      model.dictationFeedback(.failure)
      model.predictions = ["Dictation", "failed", "Try again"]
    }
    KeyboardBridge.set(resultID, for: .consumedResultId)
    KeyboardBridge.remove(.finalTranscript)
    model.partialTranscript = ""
    model.refreshCapitalization()
  }

  private func applyPartialTranscriptIfNeeded() {
    let revision = KeyboardBridge.integer(for: .partialTranscriptRevision)
    guard revision != lastPartialTranscriptRevision else { return }
    lastPartialTranscriptRevision = revision
    guard model.streamingInsertionEnabled,
      let requestID = KeyboardBridge.string(for: .partialTranscriptRequestId),
      !requestID.isEmpty,
      requestID == KeyboardBridge.string(for: .keyboardRequestId),
      requestID != blockedStreamingRequestID,
      let transcript = KeyboardBridge.string(for: .partialTranscript),
      !transcript.isEmpty
    else { return }

    if streamingRequestID != requestID {
      insertedPartialText = ""
      streamingInsertionPrefix = ""
      streamingRequestID = requestID
    }
    guard replaceStreamedText(with: transcript) else {
      blockedStreamingRequestID = requestID
      model.predictions = ["Live insertion", "paused", "Cursor moved"]
      return
    }
    model.refreshCapitalization()
  }

  private func deliverFinalText(_ text: String, requestID: String) {
    if streamingRequestID == requestID,
      blockedStreamingRequestID != requestID, !insertedPartialText.isEmpty
    {
      if replaceStreamedText(with: text) {
        resetStreamingInsertion()
      } else {
        blockedStreamingRequestID = requestID
        model.predictions = [text, "Final text", "Cursor moved"]
      }
      return
    }
    if blockedStreamingRequestID == requestID {
      model.predictions = [text, "Tap to insert", ""]
      resetStreamingInsertion()
      return
    }
    textDocumentProxy.insertText(model.textForInsertion(text))
    resetStreamingInsertion()
  }

  private func discardStreamedText(requestID: String) {
    guard streamingRequestID == requestID, !insertedPartialText.isEmpty else {
      resetStreamingInsertion()
      return
    }
    guard let context = textDocumentProxy.documentContextBeforeInput else { return }
    let verification = String(insertedPartialText.suffix(40))
    guard context.hasSuffix(verification) else {
      blockedStreamingRequestID = requestID
      return
    }
    for _ in insertedPartialText { textDocumentProxy.deleteBackward() }
    resetStreamingInsertion()
  }

  private func replaceStreamedText(with text: String) -> Bool {
    guard let context = textDocumentProxy.documentContextBeforeInput else { return false }
    if insertedPartialText.isEmpty {
      let insertion = model.textForInsertion(text)
      streamingInsertionPrefix = insertion.hasPrefix(" ") ? " " : ""
      textDocumentProxy.insertText(insertion)
      insertedPartialText = insertion
      return true
    }

    let verification = String(insertedPartialText.suffix(40))
    guard context.hasSuffix(verification) else { return false }
    for _ in insertedPartialText { textDocumentProxy.deleteBackward() }
    let insertion = streamingInsertionPrefix + text
    textDocumentProxy.insertText(insertion)
    insertedPartialText = insertion
    return true
  }

  private func resetStreamingInsertion() {
    blockedStreamingRequestID = nil
    insertedPartialText = ""
    streamingInsertionPrefix = ""
    streamingRequestID = nil
  }
}

enum KeyboardPage {
  case letters
  case numbers
  case symbols
}

@MainActor
final class KeyboardModel: ObservableObject {
  @Published var predictions: [String] = []
  @Published var partialTranscript = ""
  @Published var sessionActive = false
  @Published var recordingRequested = false
  @Published var sessionPhase = "off"
  @Published var hasFullAccess = false
  @Published var needsGlobe = true
  @Published var shifted = false
  @Published var hapticsEnabled = true
  @Published var soundEnabled = true
  @Published var predictionsEnabled = true
  @Published var autocorrectEnabled = true
  @Published var swipeEnabled = true
  @Published var streamingInsertionEnabled = false
  @Published var page = KeyboardPage.letters
  @Published var keyboardType = UIKeyboardType.default
  @Published var returnKeyType = UIReturnKeyType.default

  weak var controller: UIInputViewController?
  weak var proxy: UITextDocumentProxy?

  private let decoder = NeuralSwipeDecoder()
  private let languageEngine = KeyboardLanguageEngine()
  private var deleteRepeatTask: Task<Void, Never>?

  func prepareSwipeContext() {
    decoder.prepareContext()
  }

  func releaseSwipeContext() {
    decoder.releaseContext()
  }

  func flushLearning() {
    languageEngine.flushPendingLearning()
  }

  func refreshBridgeState() {
    let nextSessionActive = KeyboardBridge.bool(for: .sessionActive)
    if sessionActive != nextSessionActive { sessionActive = nextSessionActive }
    let nextRecordingRequested = KeyboardBridge.bool(for: .recordingRequested)
    if recordingRequested != nextRecordingRequested { recordingRequested = nextRecordingRequested }
    let nextSessionPhase = KeyboardBridge.string(for: .sessionPhase) ?? "off"
    if sessionPhase != nextSessionPhase { sessionPhase = nextSessionPhase }
    let nextPartialTranscript = KeyboardBridge.string(for: .partialTranscript) ?? ""
    if partialTranscript != nextPartialTranscript { partialTranscript = nextPartialTranscript }
    let nextHapticsEnabled = KeyboardBridge.bool(for: .keyboardHapticsEnabled)
    if hapticsEnabled != nextHapticsEnabled { hapticsEnabled = nextHapticsEnabled }
    let nextSoundEnabled = KeyboardBridge.bool(for: .keyboardSoundEnabled)
    if soundEnabled != nextSoundEnabled { soundEnabled = nextSoundEnabled }
    let nextPredictionsEnabled = KeyboardBridge.bool(for: .keyboardPredictionsEnabled)
    if predictionsEnabled != nextPredictionsEnabled { predictionsEnabled = nextPredictionsEnabled }
    let nextAutocorrectEnabled = KeyboardBridge.bool(for: .keyboardAutocorrectEnabled)
    if autocorrectEnabled != nextAutocorrectEnabled { autocorrectEnabled = nextAutocorrectEnabled }
    let nextSwipeEnabled = KeyboardBridge.bool(for: .keyboardSwipeEnabled)
    if swipeEnabled != nextSwipeEnabled { swipeEnabled = nextSwipeEnabled }
    let nextStreamingInsertionEnabled = KeyboardBridge.bool(for: .streamingInsertionEnabled)
    if streamingInsertionEnabled != nextStreamingInsertionEnabled {
      streamingInsertionEnabled = nextStreamingInsertionEnabled
    }
  }

  func addSupplementaryLexicon(_ lexicon: UILexicon) {
    languageEngine.addSupplementaryLexicon(lexicon)
    refreshSuggestions()
  }

  func refreshSuggestions() {
    guard predictionsEnabled else {
      predictions = []
      return
    }
    predictions = languageEngine.predictions(
      textBeforeCursor: proxy?.documentContextBeforeInput ?? ""
    )
  }

  func refreshTraits() {
    keyboardType = proxy?.keyboardType ?? .default
    returnKeyType = proxy?.returnKeyType ?? .default
  }

  func refreshCapitalization() {
    guard let context = proxy?.documentContextBeforeInput else {
      shifted = true
      return
    }
    shifted = context.isEmpty || (context.last?.isNewline ?? false) || context.hasSuffix(". ")
  }

  func insert(_ text: String) {
    feedback()
    if page == .letters {
      proxy?.insertText(shifted ? text.uppercased() : text)
      shifted = false
    } else {
      proxy?.insertText(text)
    }
    refreshSuggestions()
  }

  func acceptPrediction(_ prediction: String) {
    feedback()
    replaceCurrentWord(with: prediction, appendSpace: true)
  }

  func deleteBackward() {
    feedback()
    proxy?.deleteBackward()
    refreshCapitalization()
    refreshSuggestions()
  }

  func beginDeleting() {
    endDeleting()
    deleteBackward()
    deleteRepeatTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(350))
      while !Task.isCancelled {
        self?.deleteBackward()
        try? await Task.sleep(for: .milliseconds(85))
      }
    }
  }

  func endDeleting() {
    deleteRepeatTask?.cancel()
    deleteRepeatTask = nil
  }

  func insertSpace() {
    feedback()
    let context = KeyboardContext(textBeforeCursor: proxy?.documentContextBeforeInput ?? "")
    if !context.currentCompletion.isEmpty && context.currentCompletion != context.currentWord {
      languageEngine.learn(
        word: context.currentCompletionText,
        after: context.previousWord,
        atSentenceStart: context.isSentenceStart
      )
      proxy?.insertText(" ")
      refreshSuggestions()
      return
    }
    if !context.currentWord.isEmpty {
      let correction =
        autocorrectEnabled
        ? languageEngine.correction(for: context.currentWord)
        : nil
      let committed =
        correction.map {
          languageEngine.displayForm(
            for: $0,
            capitalized: context.currentWordText.first?.isUppercase ?? false
          )
        } ?? context.currentWordText
      replaceCurrentWord(with: committed, appendSpace: true)
      return
    }
    proxy?.insertText(" ")
    refreshSuggestions()
  }

  func insertReturn() {
    feedback()
    commitCurrentWord(append: "\n")
    shifted = true
    page = .letters
    refreshSuggestions()
  }

  func toggleShift() {
    feedback()
    shifted.toggle()
  }

  func showLetters() {
    feedback()
    page = .letters
    refreshCapitalization()
    refreshSuggestions()
  }

  func showNumbers() {
    feedback()
    page = .numbers
  }

  func toggleSymbols() {
    feedback()
    page = page == .symbols ? .numbers : .symbols
  }

  var returnKeyLabel: String {
    switch returnKeyType {
    case .continue: "continue"
    case .done: "done"
    case .emergencyCall: "emergency"
    case .go: "go"
    case .google: "google"
    case .join: "join"
    case .next: "next"
    case .route: "route"
    case .search: "search"
    case .send: "send"
    case .yahoo: "yahoo"
    default: "return"
    }
  }

  func advanceKeyboard() {
    controller?.advanceToNextInputMode()
  }

  func toggleDictation() {
    guard hasFullAccess else {
      predictions = ["Enable", "Full Access", "in Settings"]
      return
    }
    if recordingRequested {
      dictationFeedback(.stop)
      KeyboardBridge.set(false, for: .recordingRequested)
      KeyboardBridge.set(
        KeyboardBridge.integer(for: .requestRevision) + 1,
        for: .requestRevision
      )
      recordingRequested = false
      partialTranscript = ""
      predictions = ["Processing…", "Record again", "Session stays on"]
      return
    }
    guard sessionActive else {
      let requestID = "keyboard_\(UUID().uuidString.lowercased())"
      KeyboardBridge.set(requestID, for: .keyboardRequestId)
      KeyboardBridge.set(requestID, for: .activeRequestId)
      KeyboardBridge.set("keyboard", for: .requestedEntryPoint)
      KeyboardBridge.set(true, for: .recordingRequested)
      KeyboardBridge.set(
        KeyboardBridge.integer(for: .requestRevision) + 1,
        for: .requestRevision
      )
      recordingRequested = true
      predictions = ["Opening", "TimberVox", "session"]
      dictationFeedback(.start)
      openPersonalSession()
      return
    }
    dictationFeedback(.start)
    let requestID = "keyboard_\(UUID().uuidString.lowercased())"
    KeyboardBridge.set(requestID, for: .keyboardRequestId)
    KeyboardBridge.set(requestID, for: .activeRequestId)
    KeyboardBridge.set("keyboard", for: .requestedEntryPoint)
    KeyboardBridge.set(true, for: .recordingRequested)
    KeyboardBridge.set(KeyboardBridge.integer(for: .requestRevision) + 1, for: .requestRevision)
    recordingRequested = true
    predictions = ["Listening…", "Speak", "naturally"]
  }

  func handleSwipe(samples: [SwipePoint], layout: KeyLayout) {
    guard swipeEnabled, page == .letters else { return }
    guard let firstPoint = samples.first?.location,
      let lastPoint = samples.last?.location,
      let first = layout.key(at: firstPoint),
      let last = layout.key(at: lastPoint)
    else { return }
    let context = KeyboardContext(textBeforeCursor: proxy?.documentContextBeforeInput ?? "")
    let vocabulary = languageEngine.swipeVocabulary(
      first: first,
      last: last,
      previousWord: context.previousWord
    )
    let results = decoder.predictions(
      for: samples,
      layout: layout,
      vocabulary: vocabulary,
      contextWords: context.contextWords
    )
    guard !results.isEmpty else { return }
    let displayResults = results.map {
      languageEngine.displayForm(for: $0, capitalized: shifted)
    }
    guard let first = displayResults.first else { return }
    ordinaryHapticFeedback()
    predictions = Array(displayResults.prefix(3))
    proxy?.insertText(textForInsertion(first) + " ")
    languageEngine.learn(
      word: first,
      after: context.previousWord,
      atSentenceStart: context.isSentenceStart
    )
    shifted = false
    refreshSuggestions()
  }

  private func feedback() {
    ordinaryHapticFeedback()
    if soundEnabled {
      UIDevice.current.playInputClick()
    }
  }

  private func ordinaryHapticFeedback() {
    if hapticsEnabled {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.78)
    }
  }

  func dictationFeedback(_ event: DictationFeedback) {
    guard hapticsEnabled else { return }
    switch event {
    case .start:
      UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
    case .stop:
      UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.8)
    case .success:
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .failure:
      UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
  }

  func textForInsertion(_ text: String) -> String {
    guard let last = proxy?.documentContextBeforeInput?.last,
      last.isLetter || last.isNumber,
      let first = text.first,
      first.isLetter || first.isNumber
    else { return text }
    return " " + text
  }

  private func replaceCurrentWord(with word: String, appendSpace: Bool) {
    let before = proxy?.documentContextBeforeInput ?? ""
    let context = KeyboardContext(textBeforeCursor: before)
    let replacingPersonalCompletion = word.contains {
      KeyboardLanguageEngine.isPersonalCompletionCharacter($0)
        && !($0.isLetter || $0 == "'")
    }
    let replacedText =
      replacingPersonalCompletion ? context.currentCompletionText : context.currentWordText
    for _ in replacedText {
      proxy?.deleteBackward()
    }
    let insertion = languageEngine.displayForm(
      for: word,
      capitalized: shifted || (context.currentWordText.first?.isUppercase ?? false)
    )
    proxy?.insertText(insertion)
    if appendSpace { proxy?.insertText(" ") }
    languageEngine.learn(
      word: insertion,
      after: context.previousWord,
      atSentenceStart: context.isSentenceStart
    )
    shifted = false
    refreshCapitalization()
    refreshSuggestions()
  }

  private func commitCurrentWord(append: String) {
    let context = KeyboardContext(textBeforeCursor: proxy?.documentContextBeforeInput ?? "")
    if !context.currentCompletion.isEmpty && context.currentCompletion != context.currentWord {
      languageEngine.learn(
        word: context.currentCompletionText,
        after: context.previousWord,
        atSentenceStart: context.isSentenceStart
      )
    } else if !context.currentWord.isEmpty {
      languageEngine.learn(
        word: context.currentWordText,
        after: context.previousWord,
        atSentenceStart: context.isSentenceStart
      )
    }
    proxy?.insertText(append)
  }

  private func openPersonalSession() {
    guard let url = URL(string: "timbervox://session"),
      let extensionContext = controller?.extensionContext
    else {
      rejectPersonalSessionOpen()
      return
    }
    extensionContext.open(url) { [weak self] opened in
      guard !opened else { return }
      Task { @MainActor [weak self] in
        self?.rejectPersonalSessionOpen()
      }
    }
  }

  private func rejectPersonalSessionOpen() {
    KeyboardBridge.set(false, for: .recordingRequested)
    KeyboardBridge.set(
      KeyboardBridge.integer(for: .requestRevision) + 1,
      for: .requestRevision
    )
    recordingRequested = false
    predictions = ["Open TimberVox", "Start session", "Return here"]
  }
}

enum DictationFeedback {
  case failure
  case start
  case stop
  case success
  case warning
}
