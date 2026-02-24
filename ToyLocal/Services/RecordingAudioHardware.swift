import AudioToolbox
import CoreAudio
import Foundation
import ToyLocalCore

private let recordingLogger = ToyLocalLog.recording

enum RecordingAudioHardware {
	static func getAllAudioDevices() -> [AudioDeviceID] {
		var propertySize: UInt32 = 0
		var address = audioPropertyAddress(kAudioHardwarePropertyDevices)

		var status = AudioObjectGetPropertyDataSize(
			AudioObjectID(kAudioObjectSystemObject),
			&address,
			0,
			nil,
			&propertySize
		)

		if status != 0 {
			recordingLogger.error("AudioObjectGetPropertyDataSize failed: \(status)")
			return []
		}

		let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
		var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

		status = AudioObjectGetPropertyData(
			AudioObjectID(kAudioObjectSystemObject),
			&address,
			0,
			nil,
			&propertySize,
			&deviceIDs
		)

		if status != 0 {
			recordingLogger.error("AudioObjectGetPropertyData failed while listing devices: \(status)")
			return []
		}

		return deviceIDs
	}

	static func getDeviceName(deviceID: AudioDeviceID) -> String? {
		var address = audioPropertyAddress(kAudioDevicePropertyDeviceNameCFString)

		var deviceName: CFString?
		var size = UInt32(MemoryLayout<CFString?>.size)
		let deviceNamePtr: UnsafeMutableRawPointer = .allocate(byteCount: Int(size), alignment: MemoryLayout<CFString?>.alignment)
		defer { deviceNamePtr.deallocate() }

		let status = AudioObjectGetPropertyData(
			deviceID,
			&address,
			0,
			nil,
			&size,
			deviceNamePtr
		)

		if status == 0 {
			deviceName = deviceNamePtr.load(as: CFString?.self)
		}

		if status != 0 {
			recordingLogger.error("Failed to fetch device name: \(status)")
			return nil
		}

		return deviceName as String?
	}

	static func deviceHasInput(deviceID: AudioDeviceID) -> Bool {
		var address = audioPropertyAddress(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)

		var propertySize: UInt32 = 0
		let status = AudioObjectGetPropertyDataSize(
			deviceID,
			&address,
			0,
			nil,
			&propertySize
		)

		if status != 0 {
			return false
		}

		let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propertySize))
		defer { bufferList.deallocate() }

		let getStatus = AudioObjectGetPropertyData(
			deviceID,
			&address,
			0,
			nil,
			&propertySize,
			bufferList
		)

		if getStatus != 0 {
			return false
		}

		let buffersPointer = UnsafeMutableAudioBufferListPointer(bufferList)
		return buffersPointer.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
	}

	static func setInputDevice(deviceID: AudioDeviceID) {
		var device = deviceID
		let size = UInt32(MemoryLayout<AudioDeviceID>.size)
		var address = audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice)

		let status = AudioObjectSetPropertyData(
			AudioObjectID(kAudioObjectSystemObject),
			&address,
			0,
			nil,
			size,
			&device
		)

		if status != 0 {
			recordingLogger.error("Failed to set default input device: \(status)")
		} else {
			recordingLogger.notice("Selected input device set to \(deviceID)")
		}
	}

	static func getDefaultInputDevice() -> AudioDeviceID? {
		var deviceID = AudioDeviceID(0)
		var size = UInt32(MemoryLayout<AudioDeviceID>.size)
		var address = audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice)

		let status = AudioObjectGetPropertyData(
			AudioObjectID(kAudioObjectSystemObject),
			&address,
			0,
			nil,
			&size,
			&deviceID
		)

		if status != 0 {
			recordingLogger.error("Failed to get default input device: \(status)")
			return nil
		}

		return deviceID
	}

	static func ensureInputDeviceUnmuted(settings: ToyLocalSettings) {
		var deviceIDsToCheck: [AudioDeviceID] = []

		if let selectedIDString = settings.selectedMicrophoneID,
		   let selectedID = AudioDeviceID(selectedIDString) {
			deviceIDsToCheck.append(selectedID)
		}

		if let defaultID = getDefaultInputDevice(), !deviceIDsToCheck.contains(defaultID) {
			deviceIDsToCheck.append(defaultID)
		}

		for deviceID in deviceIDsToCheck where isInputDeviceMuted(deviceID) {
			recordingLogger.error("Input device \(deviceID) is MUTED at Core Audio level! This causes silent recordings.")
			unmuteInputDevice(deviceID)
		}
	}

	static func muteSystemVolume() -> Float {
		let currentVolume = getSystemVolume()
		setSystemVolume(0)
		recordingLogger.notice("Muted system volume (was \(String(format: "%.2f", currentVolume)))")
		return currentVolume
	}

	static func restoreSystemVolume(_ volume: Float) {
		setSystemVolume(volume)
		recordingLogger.notice("Restored system volume to \(String(format: "%.2f", volume))")
	}

	private static func audioPropertyAddress(
		_ selector: AudioObjectPropertySelector,
		scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
		element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
	) -> AudioObjectPropertyAddress {
		AudioObjectPropertyAddress(
			mSelector: selector,
			mScope: scope,
			mElement: element
		)
	}

	private static func isInputDeviceMuted(_ deviceID: AudioDeviceID) -> Bool {
		var address = audioPropertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
		var muted: UInt32 = 0
		var size = UInt32(MemoryLayout<UInt32>.size)

		let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
		if status != noErr {
			return false
		}
		return muted == 1
	}

	private static func unmuteInputDevice(_ deviceID: AudioDeviceID) {
		var address = audioPropertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
		var muted: UInt32 = 0
		let size = UInt32(MemoryLayout<UInt32>.size)

		let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muted)
		if status == noErr {
			recordingLogger.warning("Input device \(deviceID) was muted at device level - automatically unmuted")
		} else {
			recordingLogger.error("Failed to unmute input device \(deviceID): \(status)")
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
