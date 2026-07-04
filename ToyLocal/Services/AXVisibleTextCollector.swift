import ApplicationServices
import Foundation

struct AXVisibleTextCollector {
  private let maxNodes: Int
  private let maxCharacters: Int
  private var visitedNodeCount = 0
  private var collectedCharacters = 0
  private var seenText = Set<String>()
  private var lines: [String] = []

  init(maxNodes: Int, maxCharacters: Int) {
    self.maxNodes = max(0, maxNodes)
    self.maxCharacters = max(0, maxCharacters)
  }

  var renderedText: String? {
    let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }

  mutating func collect(from root: AXUIElement) {
    collect(from: root, depth: 0)
  }

  private mutating func collect(from element: AXUIElement, depth: Int) {
    guard visitedNodeCount < maxNodes, collectedCharacters < maxCharacters, depth <= 6 else { return }
    visitedNodeCount += 1

    for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
      appendStringAttribute(attribute, element: element)
    }

    let children =
      elementArrayAttribute(kAXVisibleChildrenAttribute, element: element)
      + elementArrayAttribute(kAXChildrenAttribute, element: element)
    for child in children {
      collect(from: child, depth: depth + 1)
    }
  }

  private mutating func appendStringAttribute(_ attribute: String, element: AXUIElement) {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      let value,
      CFGetTypeID(value) == CFStringGetTypeID(),
      let rawString = value as? String
    else {
      return
    }
    append(rawString)
  }

  private mutating func append(_ rawText: String) {
    let text =
      rawText
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    guard !text.isEmpty, !seenText.contains(text) else { return }

    let remaining = maxCharacters - collectedCharacters
    guard remaining > 0 else { return }
    let clipped = String(text.prefix(remaining))
    lines.append(clipped)
    seenText.insert(text)
    collectedCharacters += clipped.count
  }

  private func elementArrayAttribute(_ attribute: String, element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      let value,
      CFGetTypeID(value) == CFArrayGetTypeID(),
      let array = value as? [Any]
    else {
      return []
    }

    return array.compactMap { item in
      let value = item as CFTypeRef
      guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
      return unsafeDowncast(value, to: AXUIElement.self)
    }
  }
}
