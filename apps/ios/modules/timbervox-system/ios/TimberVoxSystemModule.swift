import AppIntents
import ExpoModulesCore
import UIKit

public final class TimberVoxSystemModule: Module {
  public func definition() -> ModuleDefinition {
    Name("TimberVoxSystem")

    View(TimberVoxShortcutsButton.self) {}
  }
}

final class TimberVoxShortcutsButton: ExpoView {
  private let shortcutsButton = ShortcutsUIButton(style: .automatic)

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    clipsToBounds = true
    isAccessibilityElement = false
    shortcutsButton.accessibilityIdentifier = "timbervox-shortcuts-button"
    shortcutsButton.accessibilityLabel = "Open TimberVox Shortcuts"
    addSubview(shortcutsButton)
    accessibilityElements = [shortcutsButton]
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    shortcutsButton.frame = bounds
  }
}
