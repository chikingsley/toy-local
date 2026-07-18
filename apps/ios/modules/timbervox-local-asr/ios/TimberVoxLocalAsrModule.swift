import AVFoundation
import ExpoModulesCore
import FluidAudio
import Foundation

public final class TimberVoxLocalAsrModule: Module, @unchecked Sendable {
  private let runtime = LocalAsrRuntime()

  public func definition() -> ModuleDefinition {
    Name("TimberVoxLocalAsr")
    Events("onDownloadProgress", "onPartialTranscript")

    AsyncFunction("getPackageState") {
      try await self.runtime.packageState()
    }

    AsyncFunction("downloadPackage") {
      let progress: @Sendable (Double, String) -> Void = { [weak self] fraction, phase in
        self?.sendEvent(
          "onDownloadProgress",
          ["fraction": fraction, "phase": phase]
        )
      }
      return try await self.runtime.downloadPackage(progress: progress)
    }

    AsyncFunction("deletePackage") {
      try await self.runtime.deletePackage()
    }

    AsyncFunction("transcribeBatch") { (audio: Data) in
      try await self.runtime.transcribeBatch(audio: audio)
    }

    AsyncFunction("startRealtime") {
      let partial: @Sendable (String) -> Void = { [weak self] text in
        self?.sendEvent("onPartialTranscript", ["text": text])
      }
      try await self.runtime.startRealtime(partial: partial)
    }

    AsyncFunction("sendRealtimeAudio") { (audio: Data) in
      try await self.runtime.sendRealtimeAudio(audio: audio)
    }

    AsyncFunction("finishRealtime") {
      try await self.runtime.finishRealtime()
    }

    AsyncFunction("cancelRealtime") {
      await self.runtime.cancelRealtime()
    }
  }
}

private actor LocalAsrRuntime {
  private static let estimatedPackageBytes = 452 * 1_024 * 1_024
  private var batchManager: AsrManager?
  private var realtimeManager: StreamingEouAsrManager?

  func packageState() throws -> [String: Any] {
    let downloaded = modelsArePresent()
    return [
      "downloaded": downloaded,
      "downloadedBytes": downloaded ? Self.estimatedPackageBytes : directorySize(packageRoot),
    ]
  }

  func downloadPackage(
    progress: @escaping @Sendable (Double, String) -> Void
  ) async throws -> [String: Any] {
    try FileManager.default.createDirectory(
      at: packageRoot,
      withIntermediateDirectories: true
    )
    progress(0, "batch")
    let batchModels = try await AsrModels.downloadAndLoad(
      to: packageRoot,
      version: .tdtCtc110m,
      progressHandler: { update in
        progress(update.fractionCompleted * 0.5, "batch")
      }
    )
    let batch = AsrManager()
    try await batch.loadModels(batchModels)
    batchManager = batch

    progress(0.5, "realtime")
    let realtime = StreamingEouAsrManager(chunkSize: .ms320)
    try await realtime.loadModels(
      to: packageRoot,
      progressHandler: { update in
        progress(0.5 + update.fractionCompleted * 0.5, "realtime")
      }
    )
    realtimeManager = realtime
    progress(1, "ready")
    return try packageState()
  }

  func deletePackage() async throws -> [String: Any] {
    await realtimeManager?.cleanup()
    realtimeManager = nil
    batchManager = nil
    if FileManager.default.fileExists(atPath: packageRoot.path) {
      try FileManager.default.removeItem(at: packageRoot)
    }
    return try packageState()
  }

  func transcribeBatch(audio: Data) async throws -> String {
    let manager = try await loadedBatchManager()
    let buffer = try pcmBuffer(audio)
    var decoderState = try TdtDecoderState(
      decoderLayers: await manager.decoderLayerCount
    )
    let result = try await manager.transcribe(buffer, decoderState: &decoderState)
    return result.text
  }

  func startRealtime(partial: @escaping @Sendable (String) -> Void) async throws {
    let manager = try await loadedRealtimeManager()
    await manager.reset()
    await manager.setPartialTranscriptCallback(partial)
  }

  func sendRealtimeAudio(audio: Data) async throws {
    guard let realtimeManager else {
      throw LocalAsrError.realtimeSessionMissing
    }
    try await realtimeManager.process(audioBuffer: pcmBuffer(audio))
  }

  func finishRealtime() async throws -> String {
    guard let realtimeManager else {
      throw LocalAsrError.realtimeSessionMissing
    }
    return try await realtimeManager.finish()
  }

  func cancelRealtime() async {
    await realtimeManager?.reset()
  }

  private func loadedBatchManager() async throws -> AsrManager {
    if let batchManager { return batchManager }
    guard modelsArePresent() else { throw LocalAsrError.packageMissing }
    let models = try await AsrModels.downloadAndLoad(
      to: packageRoot,
      version: .tdtCtc110m
    )
    let manager = AsrManager()
    try await manager.loadModels(models)
    batchManager = manager
    return manager
  }

  private func loadedRealtimeManager() async throws -> StreamingEouAsrManager {
    if let realtimeManager { return realtimeManager }
    guard modelsArePresent() else { throw LocalAsrError.packageMissing }
    let manager = StreamingEouAsrManager(chunkSize: .ms320)
    try await manager.loadModels(to: packageRoot)
    realtimeManager = manager
    return manager
  }

  private func pcmBuffer(_ data: Data) throws -> AVAudioPCMBuffer {
    guard data.count.isMultiple(of: MemoryLayout<Int16>.size) else {
      throw LocalAsrError.invalidAudio
    }
    let sampleCount = data.count / MemoryLayout<Int16>.size
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
      ),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(sampleCount)
      ),
      let channel = buffer.int16ChannelData?.pointee
    else {
      throw LocalAsrError.invalidAudio
    }
    channel.withMemoryRebound(to: UInt8.self, capacity: data.count) { bytes in
      data.copyBytes(
        to: UnsafeMutableBufferPointer(start: bytes, count: data.count)
      )
    }
    buffer.frameLength = AVAudioFrameCount(sampleCount)
    return buffer
  }

  private var packageRoot: URL {
    FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    .appendingPathComponent("TimberVox", isDirectory: true)
    .appendingPathComponent("FluidAudioModels", isDirectory: true)
  }

  private func modelsArePresent() -> Bool {
    let batchPresent = AsrModels.modelsExist(
      at: packageRoot,
      version: .tdtCtc110m
    )
    let realtimeDirectory =
      packageRoot
      .appendingPathComponent("parakeet-eou-streaming", isDirectory: true)
      .appendingPathComponent("320ms", isDirectory: true)
    let realtimeFiles = [
      "streaming_encoder.mlmodelc",
      "decoder.mlmodelc",
      "joint_decision.mlmodelc",
      "vocab.json",
    ]
    return batchPresent
      && realtimeFiles.allSatisfy {
        FileManager.default.fileExists(
          atPath: realtimeDirectory.appendingPathComponent($0).path
        )
      }
  }

  private func directorySize(_ directory: URL) -> Int {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else { return 0 }
    var total = 0
    for case let file as URL in enumerator {
      total += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
    return total
  }
}

private enum LocalAsrError: LocalizedError {
  case invalidAudio
  case packageMissing
  case realtimeSessionMissing

  var errorDescription: String? {
    switch self {
    case .invalidAudio:
      return "The local transcription audio is invalid."
    case .packageMissing:
      return "Download Parakeet Local before using this mode."
    case .realtimeSessionMissing:
      return "The local realtime session has not started."
    }
  }
}
