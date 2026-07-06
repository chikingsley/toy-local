import AppKit
import SwiftUI

@main
struct TimberVoxApp: App {
  static let services = ServiceContainer()
  static let appStore = AppStore(services: services)

  @NSApplicationDelegateAdaptor(TimberVoxAppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      CheckForUpdatesView()

      // Copy last transcript to clipboard
      MenuBarCopyLastTranscriptButton(store: TimberVoxApp.appStore)

      Button("Settings...") {
        appDelegate.presentSettingsOrPermissions()
      }.keyboardShortcut(",")

      Divider()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }.keyboardShortcut("q")
    } label: {
      if let icon = NSImage(named: "TimberVoxIcon")?.copy() as? NSImage, icon.size.width > 0 {
        let image: NSImage = {
          let ratio = $0.size.height / $0.size.width
          $0.size.height = 18
          $0.size.width = 18 / ratio
          return $0
        }(icon)
        Image(nsImage: image)
      } else {
        Image(systemName: "waveform")
      }
    }
    .commands {
      CommandGroup(after: .appInfo) {
        CheckForUpdatesView()

        Button("Settings...") {
          appDelegate.presentSettingsOrPermissions()
        }.keyboardShortcut(",")
      }

      CommandGroup(replacing: .help) {}
    }
  }
}
