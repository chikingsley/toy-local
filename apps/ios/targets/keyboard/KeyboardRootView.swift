import SwiftUI

enum KeyboardMetrics {
  static let suggestionHeight: CGFloat = 40
  static let keySurfaceHeight: CGFloat = 148
  static let bottomRowHeight: CGFloat = 44
  static let sectionSpacing: CGFloat = 5
  static let horizontalPadding: CGFloat = 5
  static let verticalPadding: CGFloat = 4
  static let totalHeight =
    suggestionHeight + keySurfaceHeight + bottomRowHeight + sectionSpacing * 2
    + verticalPadding * 2
}

struct KeyboardRootView: View {
  @ObservedObject var model: KeyboardModel

  var body: some View {
    VStack(spacing: KeyboardMetrics.sectionSpacing) {
      KeyboardSuggestionBar(
        suggestions: model.predictions,
        partialTranscript: model.partialTranscript,
        isEnabled: model.predictionsEnabled,
        onSelect: model.acceptPrediction
      )
      Group {
        if model.page == .letters {
          SwipeKeySurface(model: model)
        } else {
          AlternateKeySurface(model: model)
        }
      }
      .frame(height: KeyboardMetrics.keySurfaceHeight)
      bottomRow
        .frame(height: KeyboardMetrics.bottomRowHeight)
    }
    .padding(.horizontal, KeyboardMetrics.horizontalPadding)
    .padding(.vertical, KeyboardMetrics.verticalPadding)
    .frame(maxWidth: .infinity)
    .frame(height: KeyboardMetrics.totalHeight)
    .background(Color.clear)
  }

  private var bottomRow: some View {
    HStack(spacing: 5) {
      Button {
        if model.page == .letters {
          model.showNumbers()
        } else {
          model.showLetters()
        }
      } label: {
        Text(model.page == .letters ? "123" : "ABC")
          .font(.system(size: 13, weight: .medium))
          .frame(width: 43, height: 44)
      }
      .buttonStyle(KeyboardSpecialKeyStyle())

      if model.needsGlobe {
        KeyboardModeSwitchButton(controller: model.controller)
          .frame(width: 40, height: 44)
      }

      if let contextualKey {
        Button(contextualKey) { model.insert(contextualKey) }
          .font(.system(size: 17))
          .frame(width: 38, height: 44)
          .buttonStyle(KeyboardKeyStyle())
      }

      Button(action: model.insertSpace) {
        Text("space")
          .font(.system(size: 14))
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(KeyboardKeyStyle())

      Button(action: model.insertReturn) {
        Group {
          if model.returnKeyLabel == "return" {
            Image(systemName: "return")
              .font(.system(size: 17, weight: .medium))
          } else {
            Text(model.returnKeyLabel)
              .font(.system(size: 12, weight: .semibold))
              .minimumScaleFactor(0.7)
          }
        }
        .frame(width: 48, height: 44)
      }
      .buttonStyle(KeyboardSpecialKeyStyle())

      Button(action: model.toggleDictation) {
        Image(systemName: model.recordingRequested ? "stop.fill" : "mic.fill")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 46, height: 44)
          .background(model.recordingRequested ? Color.red : Color.accentColor)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay {
            if model.recordingRequested {
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 2)
            }
          }
      }
      .accessibilityLabel(model.recordingRequested ? "Stop dictation" : "Start dictation")
      .accessibilityIdentifier("timbervox-dictation")
    }
  }

  private var contextualKey: String? {
    switch model.keyboardType {
    case .emailAddress: "@"
    case .URL: "/"
    case .twitter: "#"
    case .webSearch: "."
    default: nil
    }
  }
}

private struct KeyboardModeSwitchButton: UIViewRepresentable {
  let controller: UIInputViewController?

  func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: "globe"), for: .normal)
    button.tintColor = .label
    button.backgroundColor = KeyboardPalette.specialUIColor
    button.layer.cornerRadius = 7
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.18
    button.layer.shadowRadius = 0.5
    button.layer.shadowOffset = CGSize(width: 0, height: 1)
    if let controller {
      button.addTarget(
        controller,
        action: #selector(UIInputViewController.handleInputModeList(from:with:)),
        for: .allTouchEvents
      )
    }
    return button
  }

  func updateUIView(_ button: UIButton, context: Context) {}
}

struct KeyboardKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .background(configuration.isPressed ? KeyboardPalette.pressedKey : KeyboardPalette.key)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
  }
}

struct KeyboardSpecialKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .background(
        configuration.isPressed ? KeyboardPalette.pressedSpecialKey : KeyboardPalette.specialKey
      )
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .shadow(color: .black.opacity(0.12), radius: 0.5, y: 1)
  }
}
