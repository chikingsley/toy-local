import Foundation

public enum TextTransformPromptBuilder {
  public static let defaultUserTemplate = """
    INSTRUCTIONS:
    {{instructions}}

    {{language_context}}
    {{system_context}}
    {{user_context}}
    {{application_context}}
    {{selection_context}}
    {{clipboard_context}}
    {{vocabulary_context}}
    {{examples}}
    USER MESSAGE:
    {{user_message}}
    """

  public static func messages(
    preset: TextTransformPreset,
    transcript: String,
    context: DictationContext? = nil,
    contextOptions: DictationContextOptions = .init()
  ) -> [TextMessage] {
    [
      TextMessage(
        role: .system,
        content: render(
          preset.systemPrompt,
          values: templateValues(
            preset: preset,
            transcript: transcript,
            context: context,
            contextOptions: contextOptions
          )
        )
      ),
      TextMessage(
        role: .user,
        content: userMessage(
          preset: preset,
          transcript: transcript,
          context: context,
          contextOptions: contextOptions
        )
      ),
    ]
  }

  public static func userMessage(
    preset: TextTransformPreset,
    transcript: String,
    context: DictationContext? = nil,
    contextOptions: DictationContextOptions = .init()
  ) -> String {
    render(
      defaultUserTemplate,
      values: templateValues(
        preset: preset,
        transcript: transcript,
        context: context,
        contextOptions: contextOptions
      )
    )
  }

  public static func render(_ template: String, values: [String: String]) -> String {
    let rendered = values.reduce(template) { partial, entry in
      partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
    }
    return normalizeBlankLines(rendered)
  }

  private static func templateValues(
    preset: TextTransformPreset,
    transcript: String,
    context: DictationContext?,
    contextOptions: DictationContextOptions
  ) -> [String: String] {
    var values = [
      "instructions": preset.instructions,
      "user_message": transcript,
      "language_context": "",
      "system_context": "",
      "user_context": "",
      "application_context": "",
      "selection_context": "",
      "clipboard_context": "",
      "vocabulary_context": "",
      "examples": "",
    ]

    guard let context else { return values }

    if let language = nonEmpty(context.system.language) {
      values["language_context"] = "The user is speaking \(language), reformatted message should also be in \(language)."
    }

    values["system_context"] = keyedLines(
      title: "SYSTEM CONTEXT:",
      pairs: [
        ("Current time", context.system.currentTime),
        ("Time zone", context.system.timeZone),
        ("Locale", context.system.locale),
        ("Computer name", context.system.computerName),
      ]
    )

    if let fullName = nonEmpty(context.user.fullName) {
      values["user_context"] = """
        USER INFORMATION:
            User's full name: \(fullName)
        """
    }

    if contextOptions.includeApplicationContext, let application = context.application {
      values["application_context"] = applicationContext(application, focusedElement: context.focusedElement)
    }

    if contextOptions.includeSelectionContext, let selectedText = nonEmpty(context.selectedText) {
      values["selection_context"] = "Selected Text Context: \(selectedText)"
    }

    if contextOptions.includeClipboardContext, let clipboardText = nonEmpty(context.clipboardText) {
      values["clipboard_context"] = contextOptions.contextTemplate + clipboardText
    }

    if !context.vocabulary.isEmpty {
      values["vocabulary_context"] = "Names and Usernames: " + context.vocabulary.joined(separator: ", ")
    }

    return values
  }

  private static func applicationContext(
    _ application: ApplicationContext,
    focusedElement: FocusedElementContext?
  ) -> String {
    var lines = [
      "APPLICATION CONTEXT:",
      "User is currently using \(application.name)",
    ]
    if let bundleIdentifier = nonEmpty(application.bundleIdentifier) {
      lines.append("Bundle Identifier: \(bundleIdentifier)")
    }
    if let category = nonEmpty(application.category) {
      lines.append("Category: \(category)")
    }
    if let windowTitle = nonEmpty(application.windowTitle) {
      lines.append("Window Title: \(windowTitle)")
    }
    if let description = nonEmpty(application.description) {
      lines.append("Description: \(description)")
    }
    if let textInputFormat = nonEmpty(application.textInputFormat) {
      lines.append("Text Input Format: \(textInputFormat)")
    }
    if let focusedElement {
      let role = focusedElement.role ?? ""
      let title = focusedElement.title ?? ""
      let description = focusedElement.description ?? ""
      lines.append("Focused element: \(role), Title: \(title), Description: \(description)")
      if let content = nonEmpty(focusedElement.content) {
        lines.append("Focused element content: \(content)")
      }
    }
    if let visibleText = nonEmpty(application.visibleText) {
      lines.append("Visible text: \(visibleText)")
    }
    if let screenText = nonEmpty(application.screenText) {
      lines.append("Screen text: \(screenText)")
    }
    return lines.joined(separator: "\n")
  }

  private static func keyedLines(title: String, pairs: [(String, String?)]) -> String {
    let lines = pairs.compactMap { key, value -> String? in
      guard let value = nonEmpty(value) else { return nil }
      return "\(key): \(value)"
    }
    guard !lines.isEmpty else { return "" }
    return ([title] + lines).joined(separator: "\n")
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func normalizeBlankLines(_ text: String) -> String {
    let normalizedLines = text.split(separator: "\n", omittingEmptySubsequences: false)
      .reduce(into: [String]()) { lines, line in
        let value = String(line)
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          if lines.last?.isEmpty != true {
            lines.append("")
          }
        } else {
          lines.append(value)
        }
      }
    return normalizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
