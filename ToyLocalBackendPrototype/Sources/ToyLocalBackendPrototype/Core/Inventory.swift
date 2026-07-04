import Foundation

struct InventoryOutput: Codable {
  let generatedAt: Date
  let fluidAudioVersion: String
  let models: [PrototypeModel]
}

struct PrototypeModel: Codable {
  let id: String
  let displayName: String
  let family: String
  let runtime: String
  let probeCommand: String?
  let runnable: Bool
  let notes: String
}

enum ModelInventory {
  static let all: [PrototypeModel] = localASR + localSupport + cloudASR

  static let localASR: [PrototypeModel] = [
    model("parakeet-tdt-0.6b-v3-coreml", "Parakeet TDT 0.6B v3", "local-asr", "asr", true, "FluidAudio AsrModels .v3"),
    model("parakeet-tdt-0.6b-v2-coreml", "Parakeet TDT 0.6B v2", "local-asr", "asr", true, "FluidAudio AsrModels .v2"),
    model("parakeet-tdt-ctc-110m-coreml", "Parakeet TDT-CTC 110M", "local-asr", "asr", true, "FluidAudio AsrModels .tdtCtc110m"),
    model("parakeet-0.6b-ja-coreml", "Parakeet Japanese 0.6B", "local-asr", "asr", true, "FluidAudio AsrModels .tdtJa"),
    model("cohere-transcribe-03-2026-coreml", "Cohere Transcribe 03-2026", "local-asr", "asr", true, "FluidAudio CoherePipeline q8"),
    model("parakeet-unified-offline-15s", "Parakeet Unified Offline 15s", "local-asr", "asr", true, "FluidAudio UnifiedAsrManager offline"),
    model("parakeet-eou-160ms", "Parakeet EOU 160ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingEouAsrManager"),
    model("parakeet-eou-320ms", "Parakeet EOU 320ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingEouAsrManager"),
    model("parakeet-eou-1280ms", "Parakeet EOU 1280ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingEouAsrManager"),
    model("nemotron-560ms", "Nemotron Streaming 560ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronAsrManager"),
    model("nemotron-1120ms", "Nemotron Streaming 1120ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronAsrManager"),
    model("nemotron-2240ms", "Nemotron Streaming 2240ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronAsrManager"),
    model("nemotron-multilingual-560ms", "Nemotron Multilingual 560ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronMultilingualAsrManager"),
    model("nemotron-multilingual-1120ms", "Nemotron Multilingual 1120ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronMultilingualAsrManager"),
    model("nemotron-multilingual-2240ms", "Nemotron Multilingual 2240ms", "local-streaming-asr", "asr", true, "FluidAudio StreamingNemotronMultilingualAsrManager"),
    model("nemotron-multilingual-4480ms", "Nemotron Multilingual 4480ms", "local-streaming-asr", "asr", true, "FluidAudio multilingual download supports 4480ms tier"),
  ]

  static let localSupport: [PrototypeModel] = [
    model("silero-vad", "Silero VAD", "local-vad", "vad", true, "FluidAudio VadManager"),
    model("sortformer-fast-v2", "Sortformer Fast v2", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("sortformer-fast-v2.1", "Sortformer Fast v2.1", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("sortformer-balanced-v2", "Sortformer Balanced v2", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("sortformer-balanced-v2.1", "Sortformer Balanced v2.1", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("sortformer-high-context-v2", "Sortformer High Context v2", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("sortformer-high-context-v2.1", "Sortformer High Context v2.1", "local-diarization", "diarize", true, "FluidAudio SortformerDiarizer"),
    model("ls-eend-ami", "LS-EEND AMI", "local-diarization", "diarize", true, "FluidAudio LSEENDDiarizer"),
    model("ls-eend-callhome", "LS-EEND CallHome", "local-diarization", "diarize", true, "FluidAudio LSEENDDiarizer"),
    model("ls-eend-dihard2", "LS-EEND DIHARD II", "local-diarization", "diarize", true, "FluidAudio LSEENDDiarizer"),
    model("ls-eend-dihard3", "LS-EEND DIHARD III", "local-diarization", "diarize", true, "FluidAudio LSEENDDiarizer"),
    model("offline-diarizer", "Offline Pyannote/VBx Diarizer", "local-diarization", "diarize", true, "FluidAudio OfflineDiarizerManager"),
    model("ctc110m", "CTC Keyword Spotting 110M", "local-keyword", "keyword", true, "FluidAudio CtcKeywordSpotter"),
    model("ctc06b", "CTC Keyword Spotting 0.6B", "local-keyword", "keyword", true, "FluidAudio CtcKeywordSpotter"),
  ]

  static let cloudASR: [PrototypeModel] = [
    model("deepgram-nova-3", "Deepgram Nova 3", "cloud-asr", "deepgram", true, "Direct Deepgram probe"),
    model("deepgram-nova-3-diarized", "Deepgram Nova 3 diarized", "cloud-asr", "deepgram", true, "Direct Deepgram probe with diarize=true"),
  ]

  private static func model(_ id: String, _ displayName: String, _ family: String, _ command: String?, _ runnable: Bool, _ notes: String) -> PrototypeModel {
    PrototypeModel(id: id, displayName: displayName, family: family, runtime: family.hasPrefix("cloud") ? "cloud" : "local", probeCommand: command, runnable: runnable, notes: notes)
  }
}
