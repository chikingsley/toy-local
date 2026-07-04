import FluidAudio
import Foundation

struct ProbeProgressEvent: Encodable {
  let timestamp: Date
  let kind: String
  let fractionCompleted: Double?
  let phase: String
  let completedFiles: Int?
  let totalFiles: Int?
  let modelName: String?
  let processedSamples: Int?
  let totalSamples: Int?
  let chunksProcessed: Int?
}

final class ProbeProgressLog: @unchecked Sendable {
  private let lock = NSLock()
  private let handle: FileHandle
  private let encoder: JSONEncoder
  private var isClosed = false

  init(runURL: URL) throws {
    let url = runURL.appendingPathComponent("progress.jsonl")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    self.handle = try FileHandle(forWritingTo: url)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    self.encoder = encoder
  }

  deinit {
    close()
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }
    guard !isClosed else { return }
    try? handle.close()
    isClosed = true
  }

  func downloadHandler() -> DownloadUtils.ProgressHandler {
    { [weak self] progress in
      self?.recordDownload(progress)
    }
  }

  func recordDiarizationProgress(processedSamples: Int, totalSamples: Int, chunksProcessed: Int) {
    write(
      ProbeProgressEvent(
        timestamp: Date(),
        kind: "diarization",
        fractionCompleted: totalSamples > 0 ? Double(processedSamples) / Double(totalSamples) : nil,
        phase: "processing",
        completedFiles: nil,
        totalFiles: nil,
        modelName: nil,
        processedSamples: processedSamples,
        totalSamples: totalSamples,
        chunksProcessed: chunksProcessed
      )
    )
  }

  func recordOfflineDiarizationProgress(chunksProcessed: Int, totalChunks: Int) {
    write(
      ProbeProgressEvent(
        timestamp: Date(),
        kind: "offline-diarization",
        fractionCompleted: totalChunks > 0 ? Double(chunksProcessed) / Double(totalChunks) : nil,
        phase: "processing",
        completedFiles: nil,
        totalFiles: nil,
        modelName: nil,
        processedSamples: nil,
        totalSamples: nil,
        chunksProcessed: chunksProcessed
      )
    )
  }

  private func recordDownload(_ progress: DownloadUtils.DownloadProgress) {
    let phase: String
    let completedFiles: Int?
    let totalFiles: Int?
    let modelName: String?
    switch progress.phase {
    case .listing:
      phase = "listing"
      completedFiles = nil
      totalFiles = nil
      modelName = nil
    case .downloading(let completed, let total):
      phase = "downloading"
      completedFiles = completed
      totalFiles = total
      modelName = nil
    case .compiling(let name):
      phase = "compiling"
      completedFiles = nil
      totalFiles = nil
      modelName = name.isEmpty ? nil : name
    }

    write(
      ProbeProgressEvent(
        timestamp: Date(),
        kind: "download",
        fractionCompleted: progress.fractionCompleted,
        phase: phase,
        completedFiles: completedFiles,
        totalFiles: totalFiles,
        modelName: modelName,
        processedSamples: nil,
        totalSamples: nil,
        chunksProcessed: nil
      )
    )
  }

  private func write(_ event: ProbeProgressEvent) {
    lock.lock()
    defer { lock.unlock() }
    guard !isClosed, let data = try? encoder.encode(event) else { return }
    handle.write(data)
    handle.write(Data("\n".utf8))
  }
}
