@preconcurrency import AVFoundation
import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  actor FluidAudioVadClient {
    private var manager: VadManager?

    func isModelAvailable() -> Bool {
      let dir = modelDirectory()
      return FileManager.default.fileExists(atPath: dir.path)
    }

    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      if manager != nil { return }
      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      self.manager = try await VadManager { downloadProgress in
        p.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
        progress(p)
      }

      p.completedUnitCount = 100
      progress(p)
    }

    func process(_ url: URL) async throws -> [VadResult] {
      guard let manager else {
        throw NSError(domain: "FluidAudioVad", code: -1, userInfo: [NSLocalizedDescriptionKey: "VAD model not initialized"])
      }
      return try await manager.process(url)
    }

    func process(_ buffer: AVAudioPCMBuffer) async throws -> [VadResult] {
      guard let manager else {
        throw NSError(domain: "FluidAudioVad", code: -1, userInfo: [NSLocalizedDescriptionKey: "VAD model not initialized"])
      }
      return try await manager.process(buffer)
    }

    func deleteCaches() throws {
      let dir = modelDirectory()
      if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
      }
      manager = nil
    }

    private func modelDirectory() -> URL {
      (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true))
        .appendingPathComponent("FluidAudio", isDirectory: true)
        .appendingPathComponent("Models", isDirectory: true)
        .appendingPathComponent(Repo.vad.folderName, isDirectory: true)
    }
  }

#else

  actor FluidAudioVadClient {
    func isModelAvailable() -> Bool { false }
    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(domain: "FluidAudioVad", code: -2, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func deleteCaches() throws {}
  }

#endif
