import SwiftUI

struct KeyboardSuggestionBar: View {
  let suggestions: [String]
  let partialTranscript: String
  let isEnabled: Bool
  let onSelect: (String) -> Void

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(displayedSuggestions.enumerated()), id: \.offset) { index, suggestion in
        if index > 0 {
          Rectangle()
            .fill(Color(uiColor: .separator).opacity(0.65))
            .frame(width: 0.5, height: 22)
        }

        suggestionButton(suggestion, isPrimary: index == 1)
      }
    }
    .frame(height: KeyboardMetrics.suggestionHeight)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color(uiColor: .separator).opacity(0.45))
        .frame(height: 0.5)
    }
    .overlay {
      if !partialTranscript.isEmpty {
        Text(partialTranscript)
          .font(.system(size: 15, weight: .medium))
          .lineLimit(1)
          .padding(.horizontal, 12)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.thinMaterial)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Suggestions")
  }

  private var displayedSuggestions: [String] {
    let padded = Array(suggestions.prefix(3)) + Array(repeating: "", count: max(0, 3 - suggestions.count))
    guard padded.count == 3 else { return Array(padded.prefix(3)) }
    return [padded[1], padded[0], padded[2]]
  }

  private func suggestionButton(_ suggestion: String, isPrimary: Bool) -> some View {
    Button {
      onSelect(suggestion)
    } label: {
      Text(suggestion.isEmpty ? " " : suggestion)
        .font(.system(size: 17, weight: isPrimary ? .semibold : .regular))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          if isPrimary, isEnabled, !suggestion.isEmpty {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(Color(uiColor: .tertiarySystemFill))
              .padding(.horizontal, 4)
              .padding(.vertical, 3)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled || suggestion.isEmpty)
    .accessibilityLabel(suggestion)
  }
}
