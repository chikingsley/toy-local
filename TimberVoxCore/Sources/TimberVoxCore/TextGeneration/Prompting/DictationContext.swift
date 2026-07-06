import Foundation

public struct DictationContextOptions: Codable, Equatable, Sendable {
  public var includeApplicationContext: Bool
  public var includeSelectionContext: Bool
  public var includeClipboardContext: Bool
  public var contextTemplate: String

  public init(
    includeApplicationContext: Bool = false,
    includeSelectionContext: Bool = false,
    includeClipboardContext: Bool = false,
    contextTemplate: String = "Use the copied text as context to complete this task.\n\nCopied text: "
  ) {
    self.includeApplicationContext = includeApplicationContext
    self.includeSelectionContext = includeSelectionContext
    self.includeClipboardContext = includeClipboardContext
    self.contextTemplate = contextTemplate
  }

  public var capturesAnyContext: Bool {
    includeApplicationContext || includeSelectionContext || includeClipboardContext
  }
}

public struct DictationContext: Codable, Equatable, Sendable {
  public var application: ApplicationContext?
  public var focusedElement: FocusedElementContext?
  public var selectedText: String?
  public var clipboardText: String?
  public var vocabulary: [String]
  public var system: SystemContext
  public var user: UserContext

  public init(
    application: ApplicationContext? = nil,
    focusedElement: FocusedElementContext? = nil,
    selectedText: String? = nil,
    clipboardText: String? = nil,
    vocabulary: [String] = [],
    system: SystemContext = .init(),
    user: UserContext = .init()
  ) {
    self.application = application
    self.focusedElement = focusedElement
    self.selectedText = selectedText
    self.clipboardText = clipboardText
    self.vocabulary = vocabulary
    self.system = system
    self.user = user
  }
}

public struct ApplicationContext: Codable, Equatable, Sendable {
  public var name: String
  public var category: String?
  public var description: String?
  public var textInputFormat: String?
  public var bundleIdentifier: String?
  public var windowTitle: String?
  public var visibleText: String?
  public var screenText: String?

  public init(
    name: String,
    category: String? = nil,
    description: String? = nil,
    textInputFormat: String? = nil,
    bundleIdentifier: String? = nil,
    windowTitle: String? = nil,
    visibleText: String? = nil,
    screenText: String? = nil
  ) {
    self.name = name
    self.category = category
    self.description = description
    self.textInputFormat = textInputFormat
    self.bundleIdentifier = bundleIdentifier
    self.windowTitle = windowTitle
    self.visibleText = visibleText
    self.screenText = screenText
  }
}

public struct FocusedElementContext: Codable, Equatable, Sendable {
  public var role: String?
  public var title: String?
  public var description: String?
  public var content: String?

  public init(role: String? = nil, title: String? = nil, description: String? = nil, content: String? = nil) {
    self.role = role
    self.title = title
    self.description = description
    self.content = content
  }
}

public struct SystemContext: Codable, Equatable, Sendable {
  public var language: String?
  public var currentTime: String?
  public var timeZone: String?
  public var locale: String?
  public var computerName: String?

  public init(
    language: String? = nil,
    currentTime: String? = nil,
    timeZone: String? = nil,
    locale: String? = nil,
    computerName: String? = nil
  ) {
    self.language = language
    self.currentTime = currentTime
    self.timeZone = timeZone
    self.locale = locale
    self.computerName = computerName
  }
}

public struct UserContext: Codable, Equatable, Sendable {
  public var fullName: String?

  public init(fullName: String? = nil) {
    self.fullName = fullName
  }
}
