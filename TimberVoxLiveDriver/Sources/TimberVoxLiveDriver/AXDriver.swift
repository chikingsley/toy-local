import ApplicationServices
import TimberVoxCore
import Foundation

struct AXDriver {
  let app: AppControl

  func printTree(maxDepth: Int = 8) throws {
    let root = try applicationElement()
    dumpElement(root, depth: 0, maxDepth: maxDepth)
  }

  func assertElement(identifier: String, timeout: TimeInterval = 5) throws {
    _ = try waitForElement(identifier: identifier, timeout: timeout)
  }

  func assertText(_ text: String, timeout: TimeInterval = 5) throws {
    _ = try waitForElement(text: text, timeout: timeout)
  }

  func pressButton(identifier: String, timeout: TimeInterval = 5) throws {
    let element = try waitForElement(identifier: identifier, timeout: timeout)
    try press(element: element, label: identifier)
  }

  func pressButton(text: String, timeout: TimeInterval = 5) throws {
    let element = try waitForElement(text: text, role: kAXButtonRole as String, timeout: timeout)
    try press(element: element, label: text)
  }

  func assertButton(text: String, timeout: TimeInterval = 5) throws {
    _ = try waitForElement(text: text, role: kAXButtonRole as String, timeout: timeout)
  }

  private func press(element: AXUIElement, label: String) throws {
    let actions = copyActionNames(from: element)
    guard actions.contains(kAXPressAction as String) else {
      throw DriverError("Element \(label) does not support AXPress. Actions: \(actions)")
    }

    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard result == .success else {
      throw DriverError("AXPress failed for \(label): \(result.rawValue)")
    }
  }

  private func waitForElement(
    identifier: String? = nil,
    text: String? = nil,
    role: String? = nil,
    timeout: TimeInterval
  ) throws -> AXUIElement {
    let deadline = Date().addingTimeInterval(timeout)
    var lastFailure: String = "not searched"

    while Date() < deadline {
      do {
        let root = try applicationElement()
        if let found = findElement(root, identifier: identifier, text: text, role: role, depth: 0) {
          return found
        }
        lastFailure = "element not found"
      } catch {
        lastFailure = String(describing: error)
      }
      Thread.sleep(forTimeInterval: 0.2)
    }

    let description = identifier.map { "identifier=\($0)" } ?? "text=\(text ?? "")"
    throw DriverError("Timed out waiting for AX element \(description): \(lastFailure)")
  }

  private func applicationElement() throws -> AXUIElement {
    let state = try app.requestState()
    let pid = pid_t(state.processIdentifier)
    return AXUIElementCreateApplication(pid)
  }

  private func findElement(
    _ element: AXUIElement,
    identifier: String?,
    text: String?,
    role: String?,
    depth: Int
  ) -> AXUIElement? {
    guard depth < 16 else { return nil }

    if matches(element, identifier: identifier, text: text, role: role) {
      return element
    }

    for child in copyChildren(of: element) {
      if let found = findElement(child, identifier: identifier, text: text, role: role, depth: depth + 1) {
        return found
      }
    }
    return nil
  }

  private func dumpElement(_ element: AXUIElement, depth: Int, maxDepth: Int) {
    guard depth <= maxDepth else { return }
    let indent = String(repeating: "  ", count: depth)
    let role = copyStringAttribute(kAXRoleAttribute, from: element) ?? "-"
    let identifier = copyStringAttribute(kAXIdentifierAttribute, from: element) ?? "-"
    let title = copyStringAttribute(kAXTitleAttribute, from: element) ?? "-"
    let description = copyStringAttribute(kAXDescriptionAttribute, from: element) ?? "-"
    let value = copyStringAttribute(kAXValueAttribute, from: element) ?? "-"
    print("\(indent)\(role) id=\(identifier) title=\(title) desc=\(description) value=\(value)")

    for child in copyChildren(of: element) {
      dumpElement(child, depth: depth + 1, maxDepth: maxDepth)
    }
  }

  private func matches(_ element: AXUIElement, identifier: String?, text: String?, role: String?) -> Bool {
    if let role,
      copyStringAttribute(kAXRoleAttribute, from: element) != role
    {
      return false
    }

    if let identifier,
      copyStringAttribute(kAXIdentifierAttribute, from: element) == identifier
    {
      return true
    }

    guard let text else { return false }
    let candidates = [
      copyStringAttribute(kAXTitleAttribute, from: element),
      copyStringAttribute(kAXDescriptionAttribute, from: element),
      copyStringAttribute(kAXValueAttribute, from: element),
    ]
    return candidates.contains(text)
  }

  private func copyChildren(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    guard result == .success, let children = value as? [AXUIElement] else {
      return []
    }
    return children
  }

  private func copyActionNames(from element: AXUIElement) -> [String] {
    var value: CFArray?
    let result = AXUIElementCopyActionNames(element, &value)
    guard result == .success, let values = value as? [String] else {
      return []
    }
    return values
  }

  private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value as? String
  }
}
