import SwiftUI

struct ModeCustomPromptSettings: View {
  @Binding var instructions: String
  @Binding var includeApplication: Bool
  @Binding var includeSelection: Bool
  @Binding var includeClipboard: Bool
  @Binding var includeScreen: Bool

  @Environment(\.theme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
      SCField {
        SCFieldLabel("Custom instructions")
          .fontWeight(.semibold)
        SCFieldDescription("Adjust the transcript to your style using natural language.")
        SCTextarea(
          "Enter custom instructions for this mode...",
          text: $instructions,
          minHeight: 112
        )
      }

      ViewThatFits(in: .horizontal) {
        HStack(spacing: AppSpacing.lg) {
          contextHeading
          Spacer(minLength: AppSpacing.md)
          contextOptions
        }

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
          contextHeading
          contextOptions
        }
      }
    }
  }

  private var contextHeading: some View {
    HStack(spacing: AppSpacing.xs) {
      Text("Context")
        .font(.system(size: 14, weight: .semibold))

      SCPopover(
        position: SCPopoverPosition(side: .bottom, alignment: .start)
      ) {
        SCPopoverTrigger {
          Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.sc(.ghost, size: .iconXS))
        .accessibilityLabel("Context information")
      } content: {
        SCPopoverContent(width: 320) {
          VStack(alignment: .leading, spacing: AppSpacing.md) {
            SCPopoverTitle("Prompt context")
            contextHelp
          }
        }
      }
    }
  }

  private var contextOptions: some View {
    HStack(spacing: AppSpacing.md) {
      contextCheckbox("Application", isChecked: $includeApplication)
      contextCheckbox("Copied text", isChecked: $includeClipboard)
      contextCheckbox("Selected text", isChecked: $includeSelection)
      contextCheckbox("Screen text", isChecked: $includeScreen)
    }
  }

  private func contextCheckbox(_ label: String, isChecked: Binding<Bool>) -> some View {
    SCCheckbox(isChecked: isChecked) {
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.mutedForeground)
        .fixedSize()
    }
  }

  private var contextHelp: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      Text(
        "Enabled context is captured while you record and included with the transcript when TimberVox runs your custom prompt."
      )
      contextHelpRow(
        "Application",
        "Includes the active application, window, and focused-element details."
      )
      contextHelpRow(
        "Copied text",
        "Includes clipboard text from the three seconds before recording and changes copied while recording."
      )
      contextHelpRow(
        "Selected text",
        "Includes text selected in the active application while recording."
      )
      contextHelpRow(
        "Screen text",
        "Includes visible text captured at the start and end of recording when Screen Recording permission is available."
      )
    }
    .font(.caption)
    .foregroundStyle(theme.popoverForeground)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func contextHelpRow(_ title: String, _ description: String) -> some View {
    Text("**\(title):** \(description)")
  }
}
