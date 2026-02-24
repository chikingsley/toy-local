import Inject
import Sparkle
import AppKit
import SwiftUI

@main
struct ToyLocalApp: App {
	static let services = ServiceContainer()
	static let appStore = AppStore(services: services)

	@NSApplicationDelegateAdaptor(ToyLocalAppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            CheckForUpdatesView()

            // Copy last transcript to clipboard
            MenuBarCopyLastTranscriptButton(store: ToyLocalApp.appStore)

            Button("Settings...") {
                appDelegate.presentSettingsView()
            }.keyboardShortcut(",")

			Divider()

			Button("Quit") {
				NSApplication.shared.terminate(nil)
			}.keyboardShortcut("q")
		} label: {
			if let icon = NSImage(named: "ToyLocalIcon")?.copy() as? NSImage, icon.size.width > 0 {
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

		WindowGroup {}.defaultLaunchBehavior(.suppressed)
			.commands {
				CommandGroup(after: .appInfo) {
					CheckForUpdatesView()

					Button("Settings...") {
						appDelegate.presentSettingsView()
					}.keyboardShortcut(",")
				}

				CommandGroup(replacing: .help) {}
			}
	}
}
