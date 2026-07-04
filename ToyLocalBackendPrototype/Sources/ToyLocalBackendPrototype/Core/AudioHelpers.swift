import AVFoundation
import FluidAudio
import Foundation

struct AudioInfo: Codable {
  let path: String
  let durationSeconds: Double
  let inputSampleRate: Double
  let inputChannels: UInt32
  let resampledSampleRate: Double
  let resampledSamples: Int
}

enum AudioHelpers {
  static func load16kMonoSamples(from url: URL) throws -> [Float] {
    try AudioConverter().resampleAudioFile(url)
  }

  static func info(for url: URL, samples: [Float]) throws -> AudioInfo {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    return AudioInfo(
      path: url.path,
      durationSeconds: Double(file.length) / format.sampleRate,
      inputSampleRate: format.sampleRate,
      inputChannels: format.channelCount,
      resampledSampleRate: 16_000,
      resampledSamples: samples.count
    )
  }

  static func buffer(from samples: [Float], sampleRate: Double = 16_000) throws -> AVAudioPCMBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
      throw CLIError("failed to allocate audio buffer")
    }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    let target = buffer.floatChannelData![0]
    samples.withUnsafeBufferPointer { source in
      target.update(from: source.baseAddress!, count: samples.count)
    }
    return buffer
  }
}
