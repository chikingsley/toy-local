import TimberVoxCore
import PermissionPilot
import SwiftUI

private let appLogger = TimberVoxLog.app
private let cacheLogger = TimberVoxLog.caches

private var isTesting: Bool {
  NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

private var isRunningForPreviews: Bool {
  let environment = ProcessInfo.processInfo.environment
  return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
}

private struct RequiredPermissionSnapshot {
  let microphone: TimberVoxCore.PermissionStatus
  let accessibility: TimberVoxCore.PermissionStatus
  let screenCapture: TimberVoxCore.PermissionStatus

  var allGranted: Bool {
    microphone == .granted && accessibility == .granted && screenCapture == .granted
  }
}

@MainActor
class TimberVoxAppDelegate: NSObject, NSApplicationDelegate {
  var invisibleWindow: InvisibleWindow?
  var settingsWindow: NSWindow?
  private var onboardingPermissionManager: PermissionManager?
  private var onboardingWindow: NSWindow?
  private var hasStartedMainExperience = false
  var debugLocalTranscription: DebugStateSnapshot.LocalTranscriptionSnapshot?
  private lazy var commandCenter = AppCommandCenter(appDelegate: self)

  private var settingsManager: SettingsManager { TimberVoxApp.services.settings }
  private var soundEffects: SoundEffectsClientLive { TimberVoxApp.services.soundEffects }
  private var recording: RecordingClientLive { TimberVoxApp.services.recording }

  var mainExperienceStartedForDebug: Bool {
    hasStartedMainExperience
  }

  func applicationDidFinishLaunching(_: Notification) {
    DiagnosticsLogging.bootstrapIfNeeded()
    // Ensure Parakeet/FluidAudio caches live under Application Support, not ~/.cache
    configureLocalCaches()
    if isTesting || isRunningForPreviews {
      appLogger.debug("Running in testing/preview mode")
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

    TimberVoxApp.appStore.onRequiredPermissionsMissing = { [weak self] in
      self?.presentOnboardingView()
    }

    presentSetupOrStartMainExperience()
    NSApp.activate(ignoringOtherApps: true)
  }

  private func startMainExperienceIfNeeded() {
    if !hasStartedMainExperience {
      hasStartedMainExperience = true
      Task { @MainActor in
        TimberVoxApp.appStore.start()
      }
    }
    presentMainView()
    presentSettingsView()
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
      let cache = support.appendingPathComponent("com.chiejimofor.timbervox/cache", isDirectory: true)
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
    let appStore = TimberVoxApp.appStore
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

    let settingsView = AppView(store: TimberVoxApp.appStore)
    let settingsWindow = NSWindow(
      contentRect: .init(x: 0, y: 0, width: 780, height: 660),
      styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    settingsWindow.titleVisibility = .hidden
    settingsWindow.titlebarAppearsTransparent = true
    settingsWindow.contentView = NSHostingView(rootView: settingsView)
    settingsWindow.isReleasedWhenClosed = false
    settingsWindow.contentMinSize = .init(width: 820, height: 560)
    settingsWindow.contentMaxSize = .init(width: 820, height: 4000)
    settingsWindow.standardWindowButton(.zoomButton)?.isHidden = true
    settingsWindow.center()
    settingsWindow.setFrameAutosaveName("TimberVoxMainWindow")
    settingsWindow.toolbarStyle = NSWindow.ToolbarStyle.unified
    settingsWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.settingsWindow = settingsWindow
  }

  private func presentSetupOrStartMainExperience() {
    Task { @MainActor in
      let permissions = await refreshPermissionState()

      if permissions.allGranted {
        startMainExperienceIfNeeded()
      } else {
        presentOnboardingView()
      }
    }
  }

  func presentSettingsOrPermissions() {
    Task { @MainActor in
      let permissions = await refreshPermissionState()
      guard permissions.allGranted else {
        presentOnboardingView()
        return
      }
      startMainExperienceIfNeeded()
      presentSettingsView()
    }
  }

  func presentPermissionsView() {
    presentOnboardingView()
  }

  func performRecordToggleCommand() {
    Task { @MainActor in
      let permissions = await refreshPermissionState()
      guard permissions.allGranted else {
        presentOnboardingView()
        return
      }

      startMainExperienceIfNeeded()
      if TimberVoxApp.appStore.transcription.isRecording {
        TimberVoxApp.appStore.transcription.stopRecording()
      } else {
        TimberVoxApp.appStore.transcription.startRecording()
      }
      writeDebugState()
    }
  }

  func checkPermissionsForCommand() {
    Task { @MainActor in
      _ = await refreshPermissionState()
      writeDebugState()
      if TimberVoxApp.appStore.microphonePermission != .granted
        || TimberVoxApp.appStore.accessibilityPermission != .granted
        || TimberVoxApp.appStore.screenCapturePermission != .granted
      {
        presentOnboardingView()
      }
    }
  }

  @discardableResult
  func writeDebugState() -> DebugStateSnapshot? {
    DebugStateReporter.writeSnapshot(
      appStore: TimberVoxApp.appStore,
      mainExperienceStarted: hasStartedMainExperience,
      visibleWindows: semanticVisibleWindows(),
      localTranscription: debugLocalTranscription
    )
  }

  private func semanticVisibleWindows() -> [String] {
    var windows: [String] = []
    if onboardingWindow?.isVisible == true {
      windows.append("onboarding")
    }
    if settingsWindow?.isVisible == true {
      windows.append("settings")
    }
    if invisibleWindow?.isVisible == true {
      windows.append("indicator")
    }
    return windows
  }

  private func refreshPermissionState() async -> RequiredPermissionSnapshot {
    async let mic = TimberVoxApp.services.permissions.microphoneStatus()
    async let acc = TimberVoxApp.services.permissions.accessibilityStatus()
    async let screen = TimberVoxApp.services.permissions.screenCaptureStatus()
    let (microphonePermission, accessibilityPermission, screenCapturePermission) = await (mic, acc, screen)
    TimberVoxApp.appStore.microphonePermission = microphonePermission
    TimberVoxApp.appStore.accessibilityPermission = accessibilityPermission
    TimberVoxApp.appStore.screenCapturePermission = screenCapturePermission
    return RequiredPermissionSnapshot(
      microphone: microphonePermission,
      accessibility: accessibilityPermission,
      screenCapture: screenCapturePermission
    )
  }

  private func presentOnboardingView() {
    closeMainExperienceWindows()

    guard onboardingWindow == nil else {
      onboardingWindow?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let manager = makePermissionManager()
    onboardingPermissionManager = manager

    let onboardingView = PermissionOnboardingView(manager: manager) { [weak self] in
      TimberVoxApp.appStore.checkPermissions()
      self?.onboardingPermissionManager = nil
      self?.onboardingWindow?.close()
      self?.onboardingWindow = nil
      self?.startMainExperienceIfNeeded()
    }
    let window = NSWindow(
      contentRect: .init(x: 0, y: 0, width: 680, height: 680),
      styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Set up \(AppBrand.name)"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.contentView = NSHostingView(rootView: onboardingView)
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    onboardingWindow = window
  }

  private func makePermissionManager() -> PermissionManager {
    PermissionManager(
      required: [.microphone, .accessibility, .screenRecording],
      infoOverrides: [
        .microphone: .init(
          title: "Microphone",
          reason: "\(AppBrand.name) records your voice so it can transcribe dictation locally.",
          systemImage: "mic.fill"
        ),
        .accessibility: .init(
          title: "Accessibility",
          reason: "\(AppBrand.name) uses Accessibility to handle the global hotkey and place text in the active app.",
          systemImage: "accessibility"
        ),
        .screenRecording: .init(
          title: "Screen Recording",
          reason: "\(AppBrand.name) captures visible context for Super and Custom prompt modes.",
          systemImage: "rectangle.on.rectangle"
        ),
      ]
    )
  }

  private func closeMainExperienceWindows() {
    settingsWindow?.close()
    settingsWindow = nil
    invisibleWindow?.close()
    invisibleWindow = nil
  }

  @MainActor @objc private func handleAppModeUpdate() {
    updateAppMode()
  }

  @MainActor
  private func updateAppMode() {
    let timberVoxSettings = settingsManager.settings
    appLogger.debug("showDockIcon = \(timberVoxSettings.showDockIcon)")
    if timberVoxSettings.showDockIcon {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    presentSettingsOrPermissions()
    return true
  }

  func application(_: NSApplication, open urls: [URL]) {
    for url in urls {
      guard let command = DeepLinkRouter.command(for: url) else {
        appLogger.warning("Ignoring unsupported URL: \(url.absoluteString)")
        continue
      }
      appLogger.info("Handling URL command: \(url.absoluteString)")
      commandCenter.handle(command)
    }
  }

  func applicationWillTerminate(_: Notification) {
    Task {
      await recording.cleanup()
    }
  }
}
