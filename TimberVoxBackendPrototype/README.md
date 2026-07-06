# TimberVox Backend Prototype

Swift command-line prototype for proving backend audio model behavior before wiring the shipping app.

The prototype writes each run to `Runs/<timestamp>-<command>-<model>/`:

- `input.json`: command, model, audio path, options
- `result.json`: normalized result shape
- `raw.json`: raw provider payload where available
- `summary.json`: small summary for quick review

Common commands:

```sh
swift run TimberVoxBackendPrototype inventory
swift run TimberVoxBackendPrototype runs
swift run TimberVoxBackendPrototype coverage
swift run TimberVoxBackendPrototype artifacts
swift run TimberVoxBackendPrototype diagnostics --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav --scope quick
swift run TimberVoxBackendPrototype asr --model parakeet-tdt-ctc-110m-coreml --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav
swift run TimberVoxBackendPrototype vad --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav
swift run TimberVoxBackendPrototype diarize --model sortformer-fast-v2.1 --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav
swift run TimberVoxBackendPrototype keyword --terms "FluidAudio,Parakeet" --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav
DEEPGRAM_API_KEY=... swift run TimberVoxBackendPrototype deepgram --model nova-3 --audio ../TimberVoxCloudflareApi/tests/fixtures/audio/asr-smoke.wav --diarize true
```

`runs` writes `Runs/index.json`, which indexes completed, failed, interrupted, raw-provider, and diagnostic artifacts without rerunning models.

`coverage` writes `Runs/coverage.json`, which compares the FluidAudio/cloud inventory to persisted run artifacts.

`artifacts` writes `Runs/artifacts.json`, which decodes persisted run outputs into one reusable fixture manifest with ASR timings/output flags, VAD stats, diarization speaker stats/output shapes, keyword matrix shape, Deepgram word/speaker stats, raw-provider flags, and interrupted-run reasons.

`diagnostics` runs selected supported models sequentially and writes a machine-local `diagnostics.json` report with timing, output shape, and per-model status. Use `--scope quick`, `--scope supported-local`, `--scope asr`, `--scope support`, `--scope cloud`, or `--models id,id`.

This package intentionally does not import the TimberVox app target. It talks to FluidAudio and cloud APIs directly so the app contract can be derived from observed output shapes.

`MODEL_INVENTORY_AUDIT.md` maps the prototype inventory back to the pinned FluidAudio source files and distinguishes the ASR/VAD/diarization scope from FluidAudio's separate TTS/G2P surfaces.
