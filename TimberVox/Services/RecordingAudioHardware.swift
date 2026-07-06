import TimberVoxCore
import AudioToolbox
import CoreAudio
import Foundation

private let recordingLogger = TimberVoxLog.recording

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
    getDeviceStringProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceNameCFString)
  }

  static func getDeviceUID(deviceID: AudioDeviceID) -> String? {
    getDeviceStringProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID)
  }

  static func getDeviceID(uid: String) -> AudioDeviceID? {
    var address = audioPropertyAddress(kAudioHardwarePropertyDeviceForUID)
    var deviceUID = uid as CFString
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = withUnsafePointer(to: &deviceUID) { pointer in
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        UInt32(MemoryLayout<CFString>.size),
        pointer,
        &size,
        &deviceID
      )
    }

    guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
    return deviceID
  }

  private static func getDeviceStringProperty(
    deviceID: AudioDeviceID,
    selector: AudioObjectPropertySelector
  ) -> String? {
    var address = audioPropertyAddress(selector)

    var value: CFString?
    var size = UInt32(MemoryLayout<CFString?>.size)
    let valuePtr: UnsafeMutableRawPointer = .allocate(byteCount: Int(size), alignment: MemoryLayout<CFString?>.alignment)
    defer { valuePtr.deallocate() }

    let status = AudioObjectGetPropertyData(
      deviceID,
      &address,
      0,
      nil,
      &size,
      valuePtr
    )

    if status != 0 {
      recordingLogger.error("Failed to fetch device property \(selector): \(status)")
      return nil
    }

    value = valuePtr.load(as: CFString?.self)
    return value as String?
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

  static func ensureInputDeviceUnmuted() {
    guard let deviceID = getDefaultInputDevice() else { return }
    if isInputDeviceMuted(deviceID) {
      recordingLogger.error("Input device \(deviceID) is MUTED at Core Audio level! This causes silent recordings.")
      unmuteInputDevice(deviceID)
    }
  }

  static func audioPropertyAddress(
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
}

struct SilentRecordingError: LocalizedError {
  var errorDescription: String? {
    "No microphone audio was captured. Check Recording Input and choose an active microphone instead of a silent virtual device."
  }
}

struct RecordedAudioSignal {
  let duration: TimeInterval
  let rms: Double
  let peak: Double
  let nonZeroSamples: Int

  var isSilent: Bool {
    rms < 0.00001 && peak < 0.0001 && nonZeroSamples == 0
  }
}

enum RecordedAudioInspector {
  private struct WaveLayout {
    var formatTag: UInt16 = 0
    var channelCount: UInt16 = 0
    var sampleRate: UInt32 = 0
    var byteRate: UInt32 = 0
    var bitDepth: UInt16 = 0
    var dataStart: Int?
    var dataLength: Int?
  }

  static func analyze(_ url: URL) throws -> RecordedAudioSignal {
    let data = try Data(contentsOf: url)
    guard data.count >= 12,
      chunkID(data, at: 0) == "RIFF",
      chunkID(data, at: 8) == "WAVE"
    else {
      throw inspectorError("Recording is not a WAV file.")
    }

    let layout = try readLayout(from: data)
    return try measureSamples(in: data, layout: layout)
  }

  private static func readLayout(from data: Data) throws -> WaveLayout {
    var layout = WaveLayout()
    var offset = 12
    while offset + 8 <= data.count {
      let id = chunkID(data, at: offset)
      let size = Int(readUInt32LE(data, at: offset + 4))
      let start = offset + 8
      let end = start + size
      guard end <= data.count else { break }

      if id == "fmt ", size >= 16 {
        layout.formatTag = readUInt16LE(data, at: start)
        layout.channelCount = readUInt16LE(data, at: start + 2)
        layout.sampleRate = readUInt32LE(data, at: start + 4)
        layout.byteRate = readUInt32LE(data, at: start + 8)
        layout.bitDepth = readUInt16LE(data, at: start + 14)
      } else if id == "data" {
        layout.dataStart = start
        layout.dataLength = size
      }
      offset = end + (size % 2)
    }

    guard layout.dataStart != nil, layout.dataLength != nil else {
      throw inspectorError("Recording WAV has no data chunk.")
    }
    return layout
  }

  private static func measureSamples(in data: Data, layout: WaveLayout) throws -> RecordedAudioSignal {
    guard let dataStart = layout.dataStart, let dataLength = layout.dataLength else {
      throw inspectorError("Recording WAV has no data chunk.")
    }
    let reader = try sampleReader(data: data, layout: layout, dataStart: dataStart, dataLength: dataLength)

    var sumSquares = 0.0
    var peak = 0.0
    var nonZeroSamples = 0
    for index in 0..<reader.sampleCount {
      let sample = reader.sample(index)
      guard sample.isFinite else { continue }
      let magnitude = abs(sample)
      sumSquares += sample * sample
      peak = max(peak, magnitude)
      if magnitude > 0.0000001 {
        nonZeroSamples += 1
      }
    }

    return RecordedAudioSignal(
      duration: duration(dataLength: dataLength, sampleCount: reader.sampleCount, layout: layout),
      rms: reader.sampleCount > 0 ? sqrt(sumSquares / Double(reader.sampleCount)) : 0,
      peak: peak,
      nonZeroSamples: nonZeroSamples
    )
  }

  private static func sampleReader(
    data: Data,
    layout: WaveLayout,
    dataStart: Int,
    dataLength: Int
  ) throws -> (sampleCount: Int, sample: (Int) -> Double) {
    if layout.formatTag == 3, layout.bitDepth == 32 {
      return (
        sampleCount: dataLength / 4,
        sample: { index in
          Double(Float(bitPattern: readUInt32LE(data, at: dataStart + index * 4)))
        }
      )
    }
    if layout.formatTag == 1, layout.bitDepth == 16 {
      return (
        sampleCount: dataLength / 2,
        sample: { index in
          Double(Int16(bitPattern: readUInt16LE(data, at: dataStart + index * 2))) / 32768.0
        }
      )
    }
    throw inspectorError("Unsupported recording WAV format tag=\(layout.formatTag) bitDepth=\(layout.bitDepth).")
  }

  private static func duration(dataLength: Int, sampleCount: Int, layout: WaveLayout) -> TimeInterval {
    if layout.byteRate > 0 {
      return Double(dataLength) / Double(layout.byteRate)
    }
    guard layout.sampleRate > 0, layout.channelCount > 0 else { return 0 }
    return Double(sampleCount) / Double(layout.sampleRate * UInt32(layout.channelCount))
  }

  private static func chunkID(_ data: Data, at offset: Int) -> String {
    guard offset + 4 <= data.count else { return "" }
    return String(bytes: data[offset..<offset + 4], encoding: .utf8) ?? ""
  }

  private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
    UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
  }

  private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
      | (UInt32(data[offset + 1]) << 8)
      | (UInt32(data[offset + 2]) << 16)
      | (UInt32(data[offset + 3]) << 24)
  }

  private static func inspectorError(_ message: String) -> NSError {
    NSError(domain: "RecordedAudioInspector", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
