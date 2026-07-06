# Model Inventory Audit

Last updated: 2026-07-03

Prototype dependency:

- FluidAudio `0.15.4`
- Revision `b9d43724cbdb5a980e441fd54180964e94d470f7`
- Source: `Package.resolved`

This audit covers the backend prototype scope: ASR, VAD, diarization, keyword spotting, and direct cloud ASR probes. FluidAudio also exposes TTS/G2P model repositories in `ModelNames.swift`; those are intentionally outside this prototype objective.

## Pinned FluidAudio Source Surfaces

- Local Parakeet sliding-window ASR: `ASR/Parakeet/SlidingWindow/TDT/AsrModels.swift`
  - `AsrModelVersion.v3`
  - `AsrModelVersion.v2`
  - `AsrModelVersion.tdtCtc110m`
  - `AsrModelVersion.tdtJa`
- Unsupported local ASR surfaces, intentionally not inventoried after probe failures:
  - `ASR/SenseVoice/SenseVoiceManager.swift`
  - `ASR/Paraformer/ParaformerManager.swift`
- Local Cohere Transcribe ASR: `ASR/Cohere/CoherePipeline.swift`
- Local Parakeet Unified ASR: `ASR/Parakeet/Unified/UnifiedAsrManager.swift`
- Local Parakeet EOU streaming ASR: `ASR/Parakeet/Streaming/EOU/StreamingEouAsrManager.swift`
  - `StreamingChunkSize.ms160`
  - `StreamingChunkSize.ms320`
  - `StreamingChunkSize.ms1280`
- Local Nemotron English streaming ASR: `ASR/Parakeet/Streaming/Nemotron/NemotronChunkSize.swift`
  - `NemotronChunkSize.ms560`
  - `NemotronChunkSize.ms1120`
  - `NemotronChunkSize.ms2240`
- Local Nemotron multilingual streaming ASR: `ASR/Parakeet/Streaming/Nemotron/StreamingNemotronMultilingualAsrManager.swift`
  - Uses dynamic `languageCode` and `chunkMs`; this prototype currently inventories 560, 1120, 2240, and 4480 ms variants.
- Local VAD: `VAD/VadManager.swift`
  - Silero VAD unified 256 ms model.
- Local Sortformer diarization: `Diarizer/Sortformer/SortformerTypes.swift`
  - `fastV2`
  - `fastV2_1`
  - `balancedV2`
  - `balancedV2_1`
  - `highContextV2`
  - `highContextV2_1`
- Local LS-EEND diarization: `Diarizer/LS-EEND/LSEENDTypes.swift` and `ModelNames.LSEEND`
  - `ami`
  - `callhome`
  - `dihard2`
  - `dihard3`
  - FluidAudio also exposes LS-EEND step sizes from 100 ms through 500 ms; this prototype currently tests default 100 ms because model variant coverage is the first gate.
- Local offline diarization: `Diarizer/Offline/Core/OfflineDiarizerManager.swift`
- Local keyword spotting: `ASR/Parakeet/SlidingWindow/CustomVocabulary/WordSpotting/CtcModels.swift`
  - `CtcModelVariant.ctc110m`
  - `CtcModelVariant.ctc06b`
- Cloud ASR: direct Deepgram Nova 3 probe in this prototype.

## Prototype Inventory Status

`Sources/TimberVoxBackendPrototype/Core/Inventory.swift` currently inventories 32 supported backend entries:

- 16 local ASR / streaming ASR entries
- 14 local support entries: VAD, diarization, and keyword spotting
- 2 cloud ASR entries: Deepgram Nova 3 plain and diarized

Current machine-readable status:

- Model-level coverage: `Runs/coverage.json`
- Run-level fixture manifest: `Runs/artifacts.json`
- Human probe notes: `PROBE_STATUS.md`

As of the current status file, supported model-level coverage is 32 `ok` across 32 inventory entries. Historical SenseVoice and Paraformer run artifacts remain on disk, but those models are no longer part of supported inventory coverage.
