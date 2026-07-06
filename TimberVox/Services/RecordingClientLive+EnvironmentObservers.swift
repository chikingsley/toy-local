import AVFoundation
import AppKit
import TimberVoxCore
import CoreAudio
import Foundation

private let environmentLogger = TimberVoxLog.recording

typealias CoreAudioPropertyListenerBlock = @convention(block) (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void

extension RecordingClientLive {
  func startObservingSystemChanges() {
    guard !isObservingSystemChanges else { return }
    isObservingSystemChanges = true

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    notificationObservers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.didWakeNotification,
        object: nil,
        queue: .main
      ) { _ in
        Task { await self.enqueueCaptureEnvironmentChange(reason: "system-wake") }
      }
    )
    notificationObservers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.screensDidWakeNotification,
        object: nil,
        queue: .main
      ) { _ in
        Task { await self.enqueueCaptureEnvironmentChange(reason: "display-wake") }
      }
    )

    let center = NotificationCenter.default
    notificationObservers.append(
      center.addObserver(
        forName: NSNotification.Name(rawValue: "AVCaptureDeviceWasConnected"),
        object: nil,
        queue: .main
      ) { _ in
        Task { await self.enqueueCaptureEnvironmentChange(reason: "capture-device-connected") }
      }
    )
    notificationObservers.append(
      center.addObserver(
        forName: NSNotification.Name(rawValue: "AVCaptureDeviceWasDisconnected"),
        object: nil,
        queue: .main
      ) { _ in
        Task { await self.enqueueCaptureEnvironmentChange(reason: "capture-device-disconnected") }
      }
    )

    installAudioHardwareObserver(selector: kAudioHardwarePropertyDefaultInputDevice, reason: "default-input-changed")
    installAudioHardwareObserver(selector: kAudioHardwarePropertyDefaultOutputDevice, reason: "default-output-changed")
    installAudioHardwareObserver(selector: kAudioHardwarePropertyDevices, reason: "audio-devices-changed")

    environmentLogger.notice("Installed recording environment observers")
  }

  private func installAudioHardwareObserver(
    selector: AudioObjectPropertySelector,
    reason: String
  ) {
    let listener: CoreAudioPropertyListenerBlock = { _, _ in
      Task { await self.enqueueCaptureEnvironmentChange(reason: reason) }
    }

    var address = RecordingAudioHardware.audioPropertyAddress(selector)
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      DispatchQueue.main,
      listener
    )

    if status == noErr {
      audioHardwareObservers.append(
        AudioHardwareObserver(selector: selector, reason: reason, listener: listener)
      )
    } else {
      environmentLogger.error("Failed to install audio observer reason=\(reason) status=\(status)")
    }
  }

  func enqueueCaptureEnvironmentChange(reason: String) {
    environmentChangeDebounceTask?.cancel()
    environmentChangeDebounceTask = Task { [self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      await handleCaptureEnvironmentChange(reason: reason)
    }
  }

  func stopObservingSystemChanges() {
    guard isObservingSystemChanges else { return }
    isObservingSystemChanges = false
    environmentChangeDebounceTask?.cancel()
    environmentChangeDebounceTask = nil

    for observer in notificationObservers {
      NotificationCenter.default.removeObserver(observer)
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    notificationObservers.removeAll()

    for observer in audioHardwareObservers {
      var address = RecordingAudioHardware.audioPropertyAddress(observer.selector)
      let status = AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        DispatchQueue.main,
        observer.listener
      )
      if status != noErr {
        environmentLogger.error("Failed to remove audio observer reason=\(observer.reason) status=\(status)")
      }
    }
    audioHardwareObservers.removeAll()
  }

  private func handleCaptureEnvironmentChange(reason: String) async {
    let settings = await settingsManager.settings
    let currentInputDevice = RecordingAudioHardware.getDefaultInputDevice()
    let isRecordingActive = captureController.isRecording

    let environmentDetails =
      "activeRecording=\(isRecordingActive) input=\(self.describeDevice(currentInputDevice)) "
      + "captureEngineArmed=\(self.captureController.isRunning)"
    environmentLogger.notice("Capture environment changed reason=\(reason) \(environmentDetails)")

    if isRecordingActive {
      deferredCaptureRestartReason = reason
      environmentLogger.notice("Deferring capture restart until current recording stops reason=\(reason)")
      return
    }

    deferredCaptureRestartReason = nil
    if settings.superFastModeEnabled {
      captureControllerNeedsRestartReason = reason
      captureController.clearWarmBuffer()
      environmentLogger.notice("Deferring capture engine rebuild until next recording reason=\(reason)")
      return
    }

    applyPreferredInputDevice(settings: settings)
    stopCaptureController(reason: reason)
    environmentLogger.debug("Standard mode uses on-demand capture startup after reason=\(reason)")
  }

  func flushDeferredCaptureRestartIfNeeded() async {
    guard let deferredCaptureRestartReason else { return }
    environmentLogger.notice("Applying deferred capture restart reason=\(deferredCaptureRestartReason)")
    await handleCaptureEnvironmentChange(reason: "deferred-\(deferredCaptureRestartReason)")
  }

  private func ensureCaptureControllerReady(
    for deviceID: AudioDeviceID?,
    reason: String,
    mode: CaptureRecordingMode,
    forceRestart: Bool = false
  ) throws {
    if forceRestart || captureControllerDeviceID != deviceID {
      let restartDetails =
        "previousInput=\(self.describeDevice(self.captureControllerDeviceID)) "
        + "newInput=\(self.describeDevice(deviceID)) force=\(forceRestart)"
      environmentLogger.notice("Restarting capture engine reason=\(reason) \(restartDetails)")
      stopCaptureController(reason: forceRestart ? "restart-\(reason)" : "input-device-changed")
    }

    try captureController.startIfNeeded(reason: reason, keepWarmBuffer: mode.keepsWarmBuffer)
    captureControllerDeviceID = deviceID
  }

  func ensureCaptureControllerReadyAfterDeferredRestart(
    for deviceID: AudioDeviceID?,
    reason: String,
    mode: CaptureRecordingMode
  ) throws {
    let deferredReason = captureControllerNeedsRestartReason
    try ensureCaptureControllerReady(
      for: deviceID,
      reason: deferredReason.map { "deferred-\($0)-\(reason)" } ?? reason,
      mode: mode,
      forceRestart: deferredReason != nil
    )
    captureControllerNeedsRestartReason = nil
  }

  func stopCaptureController(reason: String) {
    captureController.stop(reason: reason)
    captureControllerDeviceID = nil
  }

  func formatDuration(_ duration: TimeInterval?) -> String {
    guard let duration else { return "n/a" }
    return String(format: "%.3fs", duration)
  }

  func describeDevice(_ deviceID: AudioDeviceID?) -> String {
    guard let deviceID else { return "none" }
    if let name = RecordingAudioHardware.getDeviceName(deviceID: deviceID) {
      return "\(name) [\(deviceID)]"
    }
    return "unknown [\(deviceID)]"
  }

  func logRecordingStartRequest(mode: CaptureRecordingMode, inputDeviceID: AudioDeviceID?) {
    let idleDuration = lastRecordingEndedAt.map { Date().timeIntervalSince($0) }
    let requestDetails = "idle=\(self.formatDuration(idleDuration)) input=\(self.describeDevice(inputDeviceID))"
    environmentLogger.notice("Recording requested mode=\(mode.rawValue) \(requestDetails)")
  }
}
