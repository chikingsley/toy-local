import AppKit
import Foundation

@MainActor
final class AppCommandCenter {
  private weak var appDelegate: TimberVoxAppDelegate?

  init(appDelegate: TimberVoxAppDelegate) {
    self.appDelegate = appDelegate
  }

  func handle(_ command: DeepLinkCommand) {
    guard let appDelegate else { return }

    switch command {
    case .settings:
      appDelegate.presentSettingsOrPermissions()

    case .permissions:
      appDelegate.presentPermissionsView()

    case .recordToggle:
      appDelegate.performRecordToggleCommand()

    case .debugState:
      appDelegate.writeDebugState()

    case .debugCheckPermissions:
      appDelegate.checkPermissionsForCommand()

    case .debugShowOnboarding:
      appDelegate.presentPermissionsView()

    case .debugDownloadModel(let model):
      appDelegate.downloadModelForCommand(model)

    case .debugTranscribeFile(let model, let path):
      appDelegate.transcribeFileForCommand(model: model, path: path)

    case .debugTextTransform(let text, let mode, let model, let customInstructions):
      appDelegate.textTransformForCommand(
        text: text,
        mode: mode,
        model: model,
        customInstructions: customInstructions
      )

    case .debugQuit:
      NSApp.terminate(nil)
    }
  }
}
