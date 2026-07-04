import Foundation

public enum TextTransformOutputNormalizer {
  public static func normalize(_ text: String) -> String {
    text
      .replacingOccurrences(of: "<sw_response_content>", with: "")
      .replacingOccurrences(of: "</sw_response_content>", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
