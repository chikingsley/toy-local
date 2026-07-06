# Backend Prototype Probe Status

Last updated: 2026-07-03

## Verified commands

- `swift build` passes for `TimberVoxBackendPrototype`.
- `inventory` writes the FluidAudio/cloud inventory to `Runs/<timestamp>-inventory-fluidaudio/`.
- `runs` writes `Runs/index.json` so prior outputs can be reused as fixtures without rerunning models.
- `coverage` writes `Runs/coverage.json` and compares the FluidAudio inventory against persisted run artifacts.
- `artifacts` writes `Runs/artifacts.json`, decodes old and current successful run schemas, records zero decode warnings, tracks `progress.jsonl` availability, and keeps interrupted-run reasons available.
- `diagnostics --audio ... --models silero-vad` works and writes a machine-local `diagnostics.json` report with per-model timing, status, and output shape.
- `vad --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav` works with Silero VAD.
- `asr --model parakeet-tdt-ctc-110m-coreml --audio ...` works and returns text, confidence, token timings, and load/inference/wall timing.
- `asr --model parakeet-tdt-0.6b-v3-coreml --audio ...` works and returns text, confidence, and token timings.
- `asr --model parakeet-tdt-0.6b-v2-coreml --audio ...` works after forcing the v2 encoder load to `computeUnits: .cpuOnly`. The default encoder compute path downloaded fully, then stalled at `Encoder.mlmodelc` load/compile.
- `asr --model parakeet-0.6b-ja-coreml --audio ...` works and returns text, confidence, and token timings. The English smoke fixture produces Japanese text, so quality needs a Japanese fixture before ranking.
- `asr --model parakeet-eou-160ms --audio ...` works, but the first-load run was slow and the transcript was weaker than TDT/TDT-CTC.
- `asr --model parakeet-eou-320ms --audio ...` works after an isolated retry. The earlier interruption was a stale/partial download run, not a model failure.
- `asr --model parakeet-eou-1280ms --audio ...` works and returns final streaming text. Token timings are not normalized yet because the EOU API exposes timing through EOU-specific callbacks/getters.
- `asr --model nemotron-560ms --audio ...` works and returns token timings, but emitted an E5RT shape warning and misheard the first word in the fixture.
- `asr --model nemotron-1120ms --audio ...` works and returns token timings, but emitted the same E5RT shape warning and misheard the first word in the fixture.
- `asr --model nemotron-2240ms --audio ...` works and returns token timings, but emitted the same E5RT shape warning and misheard the first word in the fixture.
- `asr --model nemotron-multilingual-560ms --audio ...` works and returns token timings with `producesLanguage=true`, but emitted an E5RT shape warning and smart-spec fallback warning.
- `asr --model nemotron-multilingual-1120ms --audio ...` works and returns token timings with `producesLanguage=true`; the first-load run took roughly 605 seconds to download/load/compile and roughly 1.19 seconds for inference on the 4.91 second smoke clip.
- `asr --model nemotron-multilingual-2240ms --audio ...` works after an isolated retry. The earlier interruption was a partial download; the successful run still emitted an E5RT shape warning and smart-spec fallback warning.
- `asr --model nemotron-multilingual-4480ms --audio ...` works and returns token timings with `producesLanguage=true`; the first-load run took roughly 105 seconds to download/load/compile and roughly 0.32 seconds for inference on the 4.91 second smoke clip.
- `keyword --terms "TimberVox,FluidAudio,Parakeet" --audio ... --model ctc110m` works and records detection timings plus the CTC log-probability matrix shape.
- `keyword --terms "TimberVox,FluidAudio,Parakeet" --audio ... --model ctc06b` works after a long uninterrupted download/compile. The public CTC loader exposes little progress for the first large bundle, so the earlier interruption was premature.
- `asr --model cohere-transcribe-03-2026-coreml --audio ...` works after a long uninterrupted download/load/decode run. The smoke transcript was correct, but first-run wall time was roughly 17 minutes.
- `asr --model parakeet-unified-offline-15s --audio ...` works after the prototype removes an incomplete Unified cache before loading. FluidAudio's current cache check only looked for the offline encoder, so an incomplete cache with a missing preprocessor was incorrectly treated as usable.
- `diarize --model offline-diarizer --audio ...` works and returns offline `TimedSpeakerSegment` style output.
- `diarize --model sortformer-fast-v2 --audio ...` works after matching FluidAudioCLI's Sortformer path and loading the model with `computeUnits: .cpuOnly`. The earlier `.all` run stalled at CoreML compile/load.
- `diarize --model sortformer-fast-v2.1 --audio ...` works with the same CPU-only Sortformer path.
- `diarize --model sortformer-balanced-v2 --audio ...` works with the same CPU-only Sortformer path.
- `diarize --model sortformer-balanced-v2.1 --audio ...` works with the same CPU-only Sortformer path.
- `diarize --model sortformer-high-context-v2 --audio ...` works with the same CPU-only Sortformer path, but the short smoke fixture is not long enough to judge output quality.
- `diarize --model sortformer-high-context-v2.1 --audio ...` works with the same CPU-only Sortformer path, but the short smoke fixture is not long enough to judge output quality.
- `diarize --model ls-eend-ami --audio ...` works and returns timeline-style speaker segments.
- `diarize --model ls-eend-callhome --audio ...` works and returns timeline-style speaker segments.
- `diarize --model ls-eend-dihard2 --audio ...` works and returns timeline-style speaker segments.
- `diarize --model ls-eend-dihard3 --audio ...` works and returns timeline-style speaker segments.
- `deepgram --model nova-3 --audio ... --diarize false` works and saves both normalized `result.json` and raw provider `raw.json`.
- `deepgram --model nova-3 --audio ... --diarize true` works and saves word-level speaker labels plus synthesized speaker segments.

## Current run artifacts

- Inventory: `Runs/20260703-211323-inventory-fluidaudio`
- Run index: `Runs/index.json`
- Coverage: `Runs/coverage.json`
- Artifact manifest: `Runs/artifacts.json`
- Silero VAD: `Runs/20260703-150204-vad-silero-vad`
- Parakeet TDT-CTC 110M: `Runs/20260703-152053-asr-parakeet-tdt-ctc-110m-coreml`
- Parakeet TDT 0.6B v3: `Runs/20260703-151050-asr-parakeet-tdt-0.6b-v3-coreml`
- Parakeet TDT 0.6B v2 CPU-only encoder: `Runs/20260703-193745-asr-parakeet-tdt-0.6b-v2-coreml`
- Parakeet Japanese 0.6B: `Runs/20260703-171239-asr-parakeet-0.6b-ja-coreml`
- Parakeet EOU 160ms: `Runs/20260703-151050-asr-parakeet-eou-160ms`
- Parakeet EOU 320ms: `Runs/20260703-191000-asr-parakeet-eou-320ms`
- Parakeet EOU 1280ms: `Runs/20260703-171625-asr-parakeet-eou-1280ms`
- Nemotron 560ms: `Runs/20260703-151240-asr-nemotron-560ms`
- Nemotron 1120ms: `Runs/20260703-155438-asr-nemotron-1120ms`
- Nemotron 2240ms: `Runs/20260703-160317-asr-nemotron-2240ms`
- Nemotron multilingual 560ms: `Runs/20260703-161235-asr-nemotron-multilingual-560ms`
- Nemotron multilingual 1120ms: `Runs/20260703-164851-asr-nemotron-multilingual-1120ms`
- Nemotron multilingual 2240ms: `Runs/20260703-191847-asr-nemotron-multilingual-2240ms`
- Nemotron multilingual 4480ms: `Runs/20260703-171823-asr-nemotron-multilingual-4480ms`
- Keyword CTC 110M: `Runs/20260703-150406-keyword-ctc110m`
- Keyword CTC 0.6B: `Runs/20260703-195540-keyword-ctc06b`
- Cohere Transcribe 03-2026: `Runs/20260703-193802-asr-cohere-transcribe-03-2026-coreml`
- Parakeet Unified Offline 15s: `Runs/20260703-191239-asr-parakeet-unified-offline-15s`
- Offline diarizer: `Runs/20260703-150251-diarize-offline-diarizer`
- Sortformer Fast v2.1 CPU-only: `Runs/20260703-180554-diarize-sortformer-fast-v2.1`
- Sortformer Fast v2 CPU-only: `Runs/20260703-181037-diarize-sortformer-fast-v2`
- Sortformer Balanced v2 CPU-only: `Runs/20260703-181055-diarize-sortformer-balanced-v2`
- Sortformer Balanced v2.1 CPU-only: `Runs/20260703-181121-diarize-sortformer-balanced-v2.1`
- Sortformer High Context v2 CPU-only: `Runs/20260703-181146-diarize-sortformer-high-context-v2`
- Sortformer High Context v2.1 CPU-only: `Runs/20260703-181201-diarize-sortformer-high-context-v2.1`
- LS-EEND AMI: `Runs/20260703-151009-diarize-ls-eend-ami`
- LS-EEND CallHome: `Runs/20260703-152753-diarize-ls-eend-callhome`
- LS-EEND DIHARD II: `Runs/20260703-152753-diarize-ls-eend-dihard2`
- LS-EEND DIHARD III: `Runs/20260703-152753-diarize-ls-eend-dihard3`
- Deepgram Nova 3 plain: `Runs/20260703-150612-deepgram-nova-3-diarize-false`
- Deepgram Nova 3 diarized: `Runs/20260703-150612-deepgram-nova-3-diarize-true`

## Current artifact summary

- `Runs/artifacts.json` currently sees 66 persisted run directories: 40 `ok`, 24 `interrupted`, and 2 `failed`. Historical interrupted/failed run folders remain available for forensic review.
- `Runs/coverage.json` is supported model-level coverage: 32 `ok` across 32 inventory entries. SenseVoice Small and Paraformer Large zh are no longer part of the supported inventory.
- VAD shape: per-chunk probability, active flag, processing time, plus derived speech segments. Current Silero fixture run has 20 chunks, 19 active chunks, one speech segment, 4.91 speech seconds, and 1.60 RTFx.
- Offline diarizer shape: timed speaker segments with speaker ID strings, start/end seconds, quality scores, and optional FluidAudio speaker database/chunk embeddings. Current fixture run produced two segments, one speaker, 4.58 speech seconds, no overlap, and 0.15 RTFx.
- LS-EEND diarizer shape: speaker-indexed timeline segments with frame bounds, time bounds, finalized flag, and activity score. Current AMI/CallHome/DIHARD runs produced one or two segments, one speaker, no overlap, and 0.06-0.19 RTFx on the short smoke fixture.
- Sortformer diarizer shape: speaker-indexed segments. The CPU-only Fast/Balanced smoke runs produced one speaker segment on the 4.91 second fixture. The High Context smoke runs produced zero segments, which should not be treated as quality evidence because the fixture is shorter than the intended context window.
- Deepgram Nova 3 plain and diarized both persist normalized `result.json` plus provider `raw.json`. Current latest plain run has 15 words, zero speakers, zero synthesized speaker segments. Current latest diarized run has 15 words, one speaker, and one synthesized speaker segment.
- Cohere Transcribe produced the correct smoke transcript, but the first full local CoreML run was very slow: roughly 674 seconds load/download, 354 seconds inference, and 1027 seconds total wall time on the 4.91 second fixture.
- CTC 0.6B produced a valid keyword result shape but detected zero of the three smoke terms. This means the model path works; keyword thresholds/quality still need calibration before UI ranking.
- Progress logs now exist for the latest Parakeet v2 retry, Sortformer retries, Nemotron multilingual runs, Cohere Transcribe retry, Parakeet Japanese run, Parakeet EOU 1280ms, and the recovered EOU 320ms/Unified runs.

## Gaps

- Supported FluidAudio/cloud inventory coverage is complete: 32 `ok` across 32 supported entries.
- FluidAudioCLI has a `fluidaudiocli` executable product in the checked-out FluidAudio package; it was not added to the app. The checked-out CLI target currently fails to build under this Swift toolchain in `NemotronMultilingualFleursBenchmark.swift` with "compiler is unable to type-check this expression in reasonable time." The failure is in the upstream CLI target, not the prototype app code. The Sortformer command source still provided the useful reference behavior: it loads Sortformer with `computeUnits: .cpuOnly`.
- Sortformer Fast/Balanced/High Context v2 and v2.1 all now have successful CPU-only runs. The earlier Sortformer `.all` compute-unit interruptions should be treated as obsolete run artifacts, not current model failures.
- SenseVoice Small is unsupported and removed from current inventory. Historical runs showed default fp16 and int8 encoder paths download, then sit alive with no output and 0% CPU. The fp32 fallback loaded, but failed on the short smoke fixture with `MultiArray shape (1 x 128 x 560) does not match the shape (1 x 1800 x 560) specified in the model description`.
- Paraformer Large zh is unsupported and removed from current inventory. Historical runs showed default fp16 and int8 precision paths download fully, then sit alive with no output and 0% CPU after load starts.
- Parakeet v2, Parakeet Unified, EOU 320ms, Nemotron multilingual 2240ms, Cohere Transcribe, and CTC 0.6B all now have successful isolated runs. Earlier interrupted artifacts for those models should be treated as obsolete history, not current failures.
- First-load streaming ASR timings still need fresh warm reruns before using speed numbers for UI ranking.
- Current supported model-level coverage is 32 ok across 32 inventory entries.
- Cloud routes beyond direct Deepgram still need per-model runs.
