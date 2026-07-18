import Combine
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
  private let model = KeyboardModel()
  private var hostingController: UIHostingController<KeyboardRootView>?
  private var keyboardHeightConstraint: NSLayoutConstraint?
  private var pollTimer: Timer?
  private var lastTranscriptRevision = -1

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
    KeyboardBridge.set(true, for: .keyboardSeen)
    KeyboardBridge.set(hasFullAccess, for: .keyboardHasFullAccess)
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
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    pollTimer?.invalidate()
    pollTimer = nil
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
    KeyboardBridge.set(true, for: .keyboardSeen)
    model.refreshBridgeState()
    let revision = KeyboardBridge.integer(for: .transcriptRevision)
    guard revision != lastTranscriptRevision else { return }
    lastTranscriptRevision = revision
    guard let resultID = KeyboardBridge.string(for: .finalResultId), !resultID.isEmpty,
      resultID != KeyboardBridge.string(for: .consumedResultId),
      let requestID = KeyboardBridge.string(for: .finalRequestId),
      requestID == KeyboardBridge.string(for: .keyboardRequestId),
      let text = KeyboardBridge.string(for: .finalTranscript), !text.isEmpty
    else { return }
    textDocumentProxy.insertText(model.textForInsertion(text))
    KeyboardBridge.set(resultID, for: .consumedResultId)
    KeyboardBridge.remove(.finalTranscript)
    model.partialTranscript = ""
    model.refreshCapitalization()
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
  @Published var hasFullAccess = false
  @Published var needsGlobe = true
  @Published var shifted = false
  @Published var hapticsEnabled = true
  @Published var soundEnabled = true
  @Published var predictionsEnabled = true
  @Published var autocorrectEnabled = true
  @Published var swipeEnabled = true
  @Published var page = KeyboardPage.letters
  @Published var keyboardType = UIKeyboardType.default
  @Published var returnKeyType = UIReturnKeyType.default

  weak var controller: UIInputViewController?
  weak var proxy: UITextDocumentProxy?

  let decoder = GeometricSwipeDecoder()
  private let languageEngine = KeyboardLanguageEngine()
  private var deleteRepeatTask: Task<Void, Never>?

  func refreshBridgeState() {
    let nextSessionActive = KeyboardBridge.bool(for: .sessionActive)
    if sessionActive != nextSessionActive { sessionActive = nextSessionActive }
    let nextRecordingRequested = KeyboardBridge.bool(for: .recordingRequested)
    if recordingRequested != nextRecordingRequested { recordingRequested = nextRecordingRequested }
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
    if !context.currentWord.isEmpty {
      let committed =
        autocorrectEnabled
        ? languageEngine.correction(for: context.currentWord) ?? context.currentWord
        : context.currentWord
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
      openPersonalSession()
      return
    }
    let next = !recordingRequested
    feedback()
    if next {
      let requestID = "keyboard_\(UUID().uuidString.lowercased())"
      KeyboardBridge.set(requestID, for: .keyboardRequestId)
      KeyboardBridge.set(requestID, for: .activeRequestId)
      KeyboardBridge.set("keyboard", for: .requestedEntryPoint)
    }
    KeyboardBridge.set(next, for: .recordingRequested)
    KeyboardBridge.set(KeyboardBridge.integer(for: .requestRevision) + 1, for: .requestRevision)
    recordingRequested = next
    if next {
      predictions = ["Listening…", "Speak", "naturally"]
    }
  }

  func handleSwipe(points: [CGPoint], layout: KeyLayout) {
    guard swipeEnabled, page == .letters else { return }
    guard let firstPoint = points.first,
      let lastPoint = points.last,
      let first = layout.key(at: firstPoint),
      let last = layout.key(at: lastPoint)
    else { return }
    let context = KeyboardContext(textBeforeCursor: proxy?.documentContextBeforeInput ?? "")
    let vocabulary = languageEngine.swipeVocabulary(
      first: first,
      last: last,
      estimatedLength: decoder.estimatedKeyCount(points, layout: layout),
      previousWord: context.previousWord
    )
    let results = decoder.predictions(for: points, layout: layout, vocabulary: vocabulary)
    guard let first = results.first else { return }
    predictions = Array(results.prefix(3))
    let insertion = shifted ? first.capitalized : first
    proxy?.insertText(textForInsertion(insertion) + " ")
    languageEngine.learn(word: first, after: context.previousWord)
    shifted = false
    refreshSuggestions()
  }

  private func feedback() {
    if hapticsEnabled {
      UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
    }
    if soundEnabled {
      UIDevice.current.playInputClick()
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
    for _ in context.currentWord {
      proxy?.deleteBackward()
    }
    let insertion = shifted ? word.capitalized : word
    proxy?.insertText(insertion)
    if appendSpace { proxy?.insertText(" ") }
    languageEngine.learn(word: word, after: context.previousWord)
    shifted = false
    refreshCapitalization()
    refreshSuggestions()
  }

  private func commitCurrentWord(append: String) {
    let context = KeyboardContext(textBeforeCursor: proxy?.documentContextBeforeInput ?? "")
    if !context.currentWord.isEmpty {
      languageEngine.learn(word: context.currentWord, after: context.previousWord)
    }
    proxy?.insertText(append)
  }

  private func openPersonalSession() {
    guard let url = URL(string: "timbervox://session") else { return }
    let selector = NSSelectorFromString("openURL:")
    var responder: UIResponder? = controller
    while let current = responder {
      if current.responds(to: selector) {
        _ = current.perform(selector, with: url)
        return
      }
      responder = current.next
    }
    predictions = ["Open TimberVox", "Start session", "Return here"]
  }
}
