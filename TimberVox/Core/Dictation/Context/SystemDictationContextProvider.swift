import AppKit
import ApplicationServices
import Foundation

@MainActor
enum SystemDictationContextProvider {
  static func capture(for mode: DictationMode) -> DictationContext {
    let options = mode.effectiveTextTransformContextOptions
    let app = options.includeApplicationContext ? NSWorkspace.shared.frontmostApplication : nil
    let focusedElement = options.includeApplicationContext ? focusedElementContext() : nil
    return DictationContext(
      application: app.map(applicationContext),
      focusedElement: focusedElement,
      selectedText: options.includeSelectionContext ? selectedText() : nil,
      clipboardText: options.includeClipboardContext ? NSPasteboard.general.string(forType: .string) : nil,
      system: systemContext(languageCode: mode.languageCode),
      user: userContext()
    )
  }

  private static func applicationContext(_ app: NSRunningApplication) -> ApplicationContext {
    let window = focusedWindow(for: app)
    return ApplicationContext(
      name: app.localizedName ?? app.bundleIdentifier ?? "Unknown Application",
      bundleIdentifier: app.bundleIdentifier,
      documentURL: window.flatMap { stringAttribute(kAXDocumentAttribute, element: $0) },
      windowTitle: window.flatMap { stringAttribute(kAXTitleAttribute, element: $0) },
      visibleText: window.flatMap { visibleText(from: $0) }
    )
  }

  private static func focusedElementContext() -> FocusedElementContext? {
    guard let focusedElement = focusedElement() else { return nil }
    return FocusedElementContext(
      role: stringAttribute(kAXRoleAttribute, element: focusedElement),
      title: stringAttribute(kAXTitleAttribute, element: focusedElement),
      description: stringAttribute(kAXDescriptionAttribute, element: focusedElement),
      content: stringAttribute(kAXValueAttribute, element: focusedElement).map {
        String($0.prefix(4_000))
      }
    )
  }

  private static func selectedText() -> String? {
    guard let element = focusedElement() else { return nil }
    if let selectedText = stringAttribute(kAXSelectedTextAttribute, element: element) {
      return String(selectedText.prefix(6_000))
    }
    if let markerRange = copyAttribute("AXSelectedTextMarkerRange", element: element),
      let selectedText = parameterizedStringAttribute(
        "AXStringForTextMarkerRange",
        parameter: markerRange,
        element: element
      )
    {
      return String(selectedText.prefix(6_000))
    }
    if let selectedRange = copyAttribute(kAXSelectedTextRangeAttribute, element: element),
      let selectedText = parameterizedStringAttribute(
        kAXStringForRangeParameterizedAttribute,
        parameter: selectedRange,
        element: element
      )
    {
      return String(selectedText.prefix(6_000))
    }
    return nil
  }

  private static func focusedElement() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElementRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      systemWideElement,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElementRef
    )
    guard result == .success,
      let focusedElementRef,
      CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID()
    else {
      return nil
    }
    return unsafeDowncast(focusedElementRef, to: AXUIElement.self)
  }

  private static func focusedWindow(for app: NSRunningApplication) -> AXUIElement? {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        appElement,
        kAXFocusedWindowAttribute as CFString,
        &windowRef
      ) == .success,
      let windowRef,
      CFGetTypeID(windowRef) == AXUIElementGetTypeID()
    else {
      return nil
    }
    return unsafeDowncast(windowRef, to: AXUIElement.self)
  }

  private static func visibleText(from element: AXUIElement) -> String? {
    var chunks: [String] = []
    collectVisibleText(from: element, into: &chunks)
    let text = chunks.joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : String(text.prefix(6_000))
  }

  private static func collectVisibleText(from element: AXUIElement, into chunks: inout [String]) {
    if chunks.joined(separator: "\n").count > 6_000 {
      return
    }
    for attribute in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
      if let text = stringAttribute(attribute, element: element), !text.isEmpty {
        chunks.append(text)
      }
    }
    let children = arrayAttribute(kAXChildrenAttribute, element: element)
    for child in children.prefix(80) {
      collectVisibleText(from: child, into: &chunks)
    }
  }

  private static func systemContext(languageCode: String?) -> SystemContext {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    return SystemContext(
      language: languageCode.map(ModeLanguageLabel.name(for:)),
      currentTime: formatter.string(from: .now),
      timeZone: TimeZone.current.identifier,
      locale: Locale.current.identifier,
      computerName: Host.current().localizedName
    )
  }

  private static func userContext() -> UserContext {
    UserContext(fullName: NSFullUserName())
  }

  private static func stringAttribute(_ attribute: String, element: AXUIElement) -> String? {
    copyAttribute(attribute, element: element) as? String
  }

  private static func arrayAttribute(_ attribute: String, element: AXUIElement) -> [AXUIElement] {
    guard let values = copyAttribute(attribute, element: element) as? [Any] else { return [] }
    return values.compactMap { value in
      guard CFGetTypeID(value as CFTypeRef) == AXUIElementGetTypeID() else { return nil }
      return unsafeDowncast(value as CFTypeRef, to: AXUIElement.self)
    }
  }

  private static func parameterizedStringAttribute(
    _ attribute: String,
    parameter: CFTypeRef,
    element: AXUIElement
  ) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyParameterizedAttributeValue(
      element,
      attribute as CFString,
      parameter,
      &value
    )
    return result == .success ? value as? String : nil
  }

  private static func copyAttribute(_ attribute: String, element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return result == .success ? value : nil
  }
}
