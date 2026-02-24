import ToyLocalCore
import SwiftUI

private let appLogger = ToyLocalLog.app
private let cacheLogger = ToyLocalLog.caches

private var isTesting: Bool {
	NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

@MainActor
class ToyLocalAppDelegate: NSObject, NSApplicationDelegate {
	var invisibleWindow: InvisibleWindow?
	var settingsWindow: NSWindow?

	private var settingsManager: SettingsManager { ToyLocalApp.services.settings }
	private var soundEffects: SoundEffectsClientLive { ToyLocalApp.services.soundEffects }
	private var recording: RecordingClientLive { ToyLocalApp.services.recording }

	func applicationDidFinishLaunching(_: Notification) {
		DiagnosticsLogging.bootstrapIfNeeded()
		// Ensure Parakeet/FluidAudio caches live under Application Support, not ~/.cache
		configureLocalCaches()
		if isTesting {
			appLogger.debug("Running in testing mode")
			return
		}

		Task {
			await soundEffects.preloadSounds()
		}
		appLogger.info("Application did finish launching")

		// Set activation policy first
		updateAppMode()

		// Add notification observer
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleAppModeUpdate),
			name: .updateAppMode,
			object: nil
		)

		// Start long-running app effects (global hotkeys, permissions, etc.)
		startLifecycleTasksIfNeeded()

		// Then present main views
		presentMainView()
		presentSettingsView()
		NSApp.activate(ignoringOtherApps: true)
	}

	private func startLifecycleTasksIfNeeded() {
		Task { @MainActor in
			ToyLocalApp.appStore.start()
		}
	}

	/// Sets XDG_CACHE_HOME so FluidAudio stores models under our app's
	/// Application Support folder, keeping everything in one place.
    private func configureLocalCaches() {
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let cache = support.appendingPathComponent("com.chiejimofor.toylocal/cache", isDirectory: true)
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            setenv("XDG_CACHE_HOME", cache.path, 1)
            cacheLogger.info("XDG_CACHE_HOME set to \(cache.path)")
        } catch {
            cacheLogger.error("Failed to configure local caches: \(error.localizedDescription)")
        }
    }

	func presentMainView() {
		guard invisibleWindow == nil else {
			return
		}
		let appStore = ToyLocalApp.appStore
		let transcriptionView = IndicatorHostView(
			transcriptionStore: appStore.transcription,
			alwaysOnStore: appStore.alwaysOn
		)
		.padding()
		.padding(.top)
		.padding(.top)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		invisibleWindow = InvisibleWindow.fromView(transcriptionView)
		invisibleWindow?.makeKeyAndOrderFront(nil)
	}

	func presentSettingsView() {
		if let settingsWindow = settingsWindow {
			settingsWindow.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			return
		}

		let settingsView = AppView(store: ToyLocalApp.appStore)
		let settingsWindow = NSWindow(
			contentRect: .init(x: 0, y: 0, width: 700, height: 700),
			styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
			backing: .buffered,
			defer: false
		)
		settingsWindow.titleVisibility = .visible
		settingsWindow.contentView = NSHostingView(rootView: settingsView)
		settingsWindow.isReleasedWhenClosed = false
		settingsWindow.center()
		settingsWindow.toolbarStyle = NSWindow.ToolbarStyle.unified
		settingsWindow.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		self.settingsWindow = settingsWindow
	}

	@MainActor @objc private func handleAppModeUpdate() {
		updateAppMode()
	}

	@MainActor
	private func updateAppMode() {
		let hexSettings = settingsManager.settings
		appLogger.debug("showDockIcon = \(hexSettings.showDockIcon)")
		if hexSettings.showDockIcon {
			NSApp.setActivationPolicy(.regular)
		} else {
			NSApp.setActivationPolicy(.accessory)
		}
	}

	func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
		presentSettingsView()
		return true
	}

	func applicationWillTerminate(_: Notification) {
		Task {
			await recording.cleanup()
		}
	}
}
