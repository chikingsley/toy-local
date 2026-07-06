import AVFoundation
import TimberVoxCore
import AudioToolbox
import CoreAudio
import Foundation

private let systemAudioLogger = TimberVoxLog.recording

final class SystemAudioTapRecorder: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.chiejimofor.timbervox.system-audio-tap", qos: .userInitiated)
  private let meterContinuation: AsyncStream<Meter>.Continuation

  private var processTapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
  private var deviceProcID: AudioDeviceIOProcID?
  private var audioFile: AVAudioFile?
  private var outputURL: URL?

  private(set) var isRecording = false

  init(meterContinuation: AsyncStream<Meter>.Continuation) {
    self.meterContinuation = meterContinuation
  }

  func startRecording(to url: URL) throws {
    guard !isRecording else { return }

    do {
      try prepareTap()
      let format = try recordingFormat()
      let file = try AVAudioFile(
        forWriting: url,
        settings: fileSettings(for: format),
        commonFormat: .pcmFormatFloat32,
        interleaved: format.isInterleaved
      )

      audioFile = file
      outputURL = url

      try startAggregateDevice(format: format)
      isRecording = true
      systemAudioLogger.notice("System audio recording started")
    } catch {
      cleanup()
      throw error
    }
  }

  @discardableResult
  func stopRecording() throws -> URL {
    let url = outputURL
    cleanup()
    guard let url else {
      throw SystemAudioTapRecorderError.missingRecordingURL
    }
    return url
  }

  func cleanup() {
    isRecording = false
    audioFile = nil
    outputURL = nil

    if aggregateDeviceID.isKnown {
      let stopStatus = AudioDeviceStop(aggregateDeviceID, deviceProcID)
      if stopStatus != noErr {
        systemAudioLogger.warning("Failed to stop system audio aggregate device: \(stopStatus)")
      }

      if let deviceProcID {
        let destroyProcStatus = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
        if destroyProcStatus != noErr {
          systemAudioLogger.warning("Failed to destroy system audio IOProc: \(destroyProcStatus)")
        }
      }
      deviceProcID = nil

      let destroyAggregateStatus = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
      if destroyAggregateStatus != noErr {
        systemAudioLogger.warning("Failed to destroy system audio aggregate device: \(destroyAggregateStatus)")
      }
      aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    }

    if processTapID.isKnown {
      let destroyTapStatus = AudioHardwareDestroyProcessTap(processTapID)
      if destroyTapStatus != noErr {
        systemAudioLogger.warning("Failed to destroy system audio tap: \(destroyTapStatus)")
      }
      processTapID = AudioObjectID(kAudioObjectUnknown)
    }
  }

  private func prepareTap() throws {
    let tapDescription = CATapDescription(monoGlobalTapButExcludeProcesses: [])
    tapDescription.uuid = UUID()
    tapDescription.name = AppBrand.systemAudioDeviceName
    tapDescription.isPrivate = true
    tapDescription.muteBehavior = .unmuted

    var tapID = AudioObjectID(kAudioObjectUnknown)
    let createTapStatus = AudioHardwareCreateProcessTap(tapDescription, &tapID)
    guard createTapStatus == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Create process tap", createTapStatus)
    }
    processTapID = tapID

    let outputDeviceID = try AudioObjectID.defaultSystemOutputDevice()
    let outputUID = try outputDeviceID.deviceUID()
    let aggregateUID = UUID().uuidString
    let aggregateDescription: [String: Any] = [
      kAudioAggregateDeviceNameKey: AppBrand.systemAudioDeviceName,
      kAudioAggregateDeviceUIDKey: aggregateUID,
      kAudioAggregateDeviceMainSubDeviceKey: outputUID,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceSubDeviceListKey: [
        [
          kAudioSubDeviceUIDKey: outputUID
        ]
      ],
      kAudioAggregateDeviceTapListKey: [
        [
          kAudioSubTapDriftCompensationKey: true,
          kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
        ]
      ],
    ]

    var deviceID = AudioObjectID(kAudioObjectUnknown)
    let createDeviceStatus = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &deviceID)
    guard createDeviceStatus == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Create aggregate device", createDeviceStatus)
    }
    aggregateDeviceID = deviceID
  }

  private func recordingFormat() throws -> AVAudioFormat {
    var streamDescription = try processTapID.tapStreamBasicDescription()
    guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
      throw SystemAudioTapRecorderError.invalidAudioFormat
    }
    return format
  }

  private func startAggregateDevice(format: AVAudioFormat) throws {
    let ioBlock: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
      guard let self, let audioFile = self.audioFile else { return }
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inputData, deallocator: nil) else {
        systemAudioLogger.error("Failed to wrap system audio buffer")
        return
      }
      do {
        try audioFile.write(from: buffer)
        self.yieldMeter(from: buffer)
      } catch {
        systemAudioLogger.error("Failed to write system audio buffer: \(error.localizedDescription)")
      }
    }

    var createdProcID: AudioDeviceIOProcID?
    var status = AudioDeviceCreateIOProcIDWithBlock(&createdProcID, aggregateDeviceID, queue, ioBlock)
    guard status == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Create system audio IOProc", status)
    }
    deviceProcID = createdProcID

    status = AudioDeviceStart(aggregateDeviceID, createdProcID)
    guard status == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Start system audio aggregate device", status)
    }
  }

  private func yieldMeter(from buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    guard frameCount > 0, channelCount > 0 else { return }

    var squareSum: Float = 0
    var peak: Float = 0
    for channel in 0..<channelCount {
      let samples = channelData[channel]
      for frame in 0..<frameCount {
        let sample = samples[frame]
        squareSum += sample * sample
        peak = max(peak, abs(sample))
      }
    }

    let sampleCount = Float(frameCount * channelCount)
    let rms = sqrt(squareSum / sampleCount)
    meterContinuation.yield(Meter(averagePower: Double(rms), peakPower: Double(peak)))
  }

  private func fileSettings(for format: AVAudioFormat) -> [String: Any] {
    [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: Int(format.channelCount),
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: !format.isInterleaved,
    ]
  }
}

private enum SystemAudioTapRecorderError: LocalizedError {
  case coreAudio(String, OSStatus)
  case invalidAudioFormat
  case missingRecordingURL

  var errorDescription: String? {
    switch self {
    case .coreAudio(let operation, let status):
      "\(operation) failed with Core Audio status \(status)."
    case .invalidAudioFormat:
      "System audio tap returned an unsupported audio format."
    case .missingRecordingURL:
      "System audio recording stopped without an output file."
    }
  }
}

private extension AudioObjectID {
  var isKnown: Bool {
    self != AudioObjectID(kAudioObjectUnknown)
  }

  static func defaultSystemOutputDevice() throws -> AudioDeviceID {
    try AudioObjectID(kAudioObjectSystemObject).read(
      selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
      defaultValue: AudioDeviceID(kAudioObjectUnknown)
    )
  }

  func deviceUID() throws -> String {
    try read(selector: kAudioDevicePropertyDeviceUID, defaultValue: "" as CFString) as String
  }

  func tapStreamBasicDescription() throws -> AudioStreamBasicDescription {
    try read(selector: kAudioTapPropertyFormat, defaultValue: AudioStreamBasicDescription())
  }

  private func read<T>(selector: AudioObjectPropertySelector, defaultValue: T) throws -> T {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &dataSize)
    guard status == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Read Core Audio property size \(selector)", status)
    }

    var value = defaultValue
    status = withUnsafeMutablePointer(to: &value) { pointer in
      AudioObjectGetPropertyData(self, &address, 0, nil, &dataSize, pointer)
    }
    guard status == noErr else {
      throw SystemAudioTapRecorderError.coreAudio("Read Core Audio property \(selector)", status)
    }
    return value
  }
}
