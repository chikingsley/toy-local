import Foundation

struct SuiteProbeOutput: Codable {
  let audioPath: String
  let includeHeavy: Bool
  let results: [SuiteProbeResult]
}

struct SuiteProbeResult: Codable {
  let command: String
  let modelID: String
  let status: String
  let error: String?
}

enum SuiteProbe {
  static func run(audioURL: URL, includeHeavy: Bool) async throws -> SuiteProbeOutput {
    var results: [SuiteProbeResult] = []

    do {
      _ = try await VADProbe.run(audioURL: audioURL)
      results.append(SuiteProbeResult(command: "vad", modelID: "silero-vad", status: "ok", error: nil))
    } catch {
      results.append(SuiteProbeResult(command: "vad", modelID: "silero-vad", status: "failed", error: error.localizedDescription))
    }

    let defaultASR = includeHeavy ? ModelInventory.localASR.map(\.id) : ["parakeet-tdt-ctc-110m-coreml"]
    for modelID in defaultASR {
      do {
        _ = try await LocalASRProbe.run(modelID: modelID, audioURL: audioURL)
        results.append(SuiteProbeResult(command: "asr", modelID: modelID, status: "ok", error: nil))
      } catch {
        results.append(SuiteProbeResult(command: "asr", modelID: modelID, status: "failed", error: error.localizedDescription))
      }
    }

    let defaultDiarization = includeHeavy ? ModelInventory.localSupport.filter { $0.family == "local-diarization" }.map(\.id) : ["sortformer-fast-v2.1"]
    for modelID in defaultDiarization {
      do {
        _ = try await DiarizationProbe.run(modelID: modelID, audioURL: audioURL)
        results.append(SuiteProbeResult(command: "diarize", modelID: modelID, status: "ok", error: nil))
      } catch {
        results.append(SuiteProbeResult(command: "diarize", modelID: modelID, status: "failed", error: error.localizedDescription))
      }
    }

    return SuiteProbeOutput(audioPath: audioURL.path, includeHeavy: includeHeavy, results: results)
  }
}
