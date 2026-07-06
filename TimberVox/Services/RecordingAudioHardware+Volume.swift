import TimberVoxCore
import AudioToolbox
import CoreAudio
import Foundation

private let recordingLogger = TimberVoxLog.recording

extension RecordingAudioHardware {
  static func muteSystemVolume() -> Float {
    let currentVolume = getSystemVolume()
    setSystemVolume(0)
    recordingLogger.notice("Muted system volume (was \(String(format: "%.2f", currentVolume)))")
    return currentVolume
  }

  static func lowerSystemVolume(to factor: Float) -> Float {
    let currentVolume = getSystemVolume()
    setSystemVolume(currentVolume * factor)
    recordingLogger.notice(
      "Lowered system volume to \(String(format: "%.2f", currentVolume * factor)) (was \(String(format: "%.2f", currentVolume)))"
    )
    return currentVolume
  }

  static func restoreSystemVolume(_ volume: Float) {
    setSystemVolume(volume)
    recordingLogger.notice("Restored system volume to \(String(format: "%.2f", volume))")
  }

  static func raiseInputVolumeToMax() -> Float? {
    guard let deviceID = getDefaultInputDevice() else { return nil }
    guard let currentVolume = getInputVolume(deviceID) else { return nil }
    setInputVolume(deviceID, 1.0)
    recordingLogger.notice("Raised input volume to max (was \(String(format: "%.2f", currentVolume)))")
    return currentVolume
  }

  static func restoreInputVolume(_ volume: Float) {
    guard let deviceID = getDefaultInputDevice() else { return }
    setInputVolume(deviceID, volume)
    recordingLogger.notice("Restored input volume to \(String(format: "%.2f", volume))")
  }

  private static func getInputVolume(_ deviceID: AudioDeviceID) -> Float? {
    var volume: Float32 = 0.0
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = audioPropertyAddress(
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      scope: kAudioDevicePropertyScopeInput
    )

    guard AudioObjectHasProperty(deviceID, &address) else {
      recordingLogger.notice("Input device \(deviceID) has no main volume control")
      return nil
    }

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    if status != 0 {
      recordingLogger.error("Failed to get input volume: \(status)")
      return nil
    }

    return volume
  }

  private static func setInputVolume(_ deviceID: AudioDeviceID, _ volume: Float) {
    var newVolume = volume
    let size = UInt32(MemoryLayout<Float32>.size)
    var address = audioPropertyAddress(
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      scope: kAudioDevicePropertyScopeInput
    )

    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newVolume)
    if status != 0 {
      recordingLogger.error("Failed to set input volume: \(status)")
    }
  }

  private static func getDefaultOutputDevice() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = audioPropertyAddress(kAudioHardwarePropertyDefaultOutputDevice)

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )

    if status != 0 {
      recordingLogger.error("Failed to get default output device: \(status)")
      return nil
    }

    return deviceID
  }

  private static func getSystemVolume() -> Float {
    guard let deviceID = getDefaultOutputDevice() else {
      return 0.0
    }

    var volume: Float32 = 0.0
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = audioPropertyAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)

    let status = AudioObjectGetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      &size,
      &volume
    )

    if status != 0 {
      recordingLogger.error("Failed to get system volume: \(status)")
      return 0.0
    }

    return volume
  }

  private static func setSystemVolume(_ volume: Float) {
    guard let deviceID = getDefaultOutputDevice() else {
      return
    }

    var newVolume = volume
    let size = UInt32(MemoryLayout<Float32>.size)
    var address = audioPropertyAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)

    let status = AudioObjectSetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      size,
      &newVolume
    )

    if status != 0 {
      recordingLogger.error("Failed to set system volume: \(status)")
    }
  }
}
