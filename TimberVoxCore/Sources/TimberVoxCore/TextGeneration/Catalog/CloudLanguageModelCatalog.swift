import Foundation

public enum CloudLanguageModels {
  public static let mistralSmallLatest = LanguageModelSpec(
    id: "mistral-mistral-small-latest",
    displayName: "Mistral Small",
    provider: .mistral
  )

  public static let openAIGPT54Mini = LanguageModelSpec(
    id: "openai-gpt-5.4-mini",
    displayName: "OpenAI GPT-5.4 Mini",
    provider: .openAI,
    supportsJSONOutput: true
  )

  public static let claudeSonnet45 = LanguageModelSpec(
    id: "anthropic-claude-sonnet-4-5",
    displayName: "Claude Sonnet 4.5",
    provider: .anthropic
  )

  public static let all: [LanguageModelSpec] = [
    mistralSmallLatest,
    openAIGPT54Mini,
    claudeSonnet45,
  ]

  public static let defaultModel = mistralSmallLatest

  public static func model(id: String) -> LanguageModelSpec? {
    all.first { $0.id == id }
  }

  public static func isSupportedModel(_ id: String) -> Bool {
    model(id: id) != nil
  }
}
