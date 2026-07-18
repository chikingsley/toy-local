# TimberVox rebuild

This is the product and architecture roadmap. `TODO.md` is the canonical active checklist. The old application is preserved read-only under `old-app/`; it is a parts bin for proven behavior, not an architecture to copy wholesale.

## Current truth

The rebuild is no longer a skeleton. The Mac target contains a visible shell, onboarding, cloud dictation, auto-paste behavior, GRDB history, settings, a passive recording indicator, modes, text transforms, app-side RevenueCat purchases, and authenticated batch/realtime Peacockery Voice clients.

The major runtime boundary refactor is complete. `DictationController` owns observable UI state and commands; `DictationWorkflow` owns record → transcribe → transform → persist → deliver; `TranscriptionRuntime` owns batch/realtime and cloud/local route execution; provider implementations live under `Core/Transcription`; mode persistence and capability interpretation are separated; and the Peacockery Voice catalog is authoritative for cloud routes, languages, and diarization.

The copied text-transform cleanup is now complete. The obsolete local language-model catalog/provider protocol was removed. The live prompt contract consists of `TextMessage`, presets, prompt assembly, a recording-scoped Dictation context session, and the Peacockery Voice text route. Context capture now spans record start through stop and includes application/window/focused text, selected-text changes, a three-second pre-recording clipboard window, clipboard changes and attachment metadata, and optional start/end screen OCR.

Earlier accepted runs covered the real temporary-GRDB persistence integration, unsigned Debug build, Worker checks, deployed-Worker/deployed-D1 integration, mixed microphone/system capture, local and cloud batch/realtime providers, playback policies, endurance, dual speech, local record-to-delivery, and the five production text-transform presets. Later source changes require their own gates and live acceptance; this July 14 backend pass intentionally runs only Apple Swift Format and SwiftLint. It does not prove global shortcuts, macOS focus, paste delivery in third-party apps, permission recovery, production UI interactions, or the undeployed text-stream route.

Peacockery Voice is deployed at `voice-lab.peacockery.studio` for internal development and `voice.peacockery.studio` for official-provider production traffic. Both hosts expose one authenticated `/v1` contract and currently share a Worker and Cloudflare bindings; the hostname selects environment-scoped credentials and provider policy. The service uses direct signed R2 audio uploads, keeps exact structured/text evidence in D1, supports realtime WebSockets through a Durable Object, and has passed lab and production text, batch, and realtime acceptance.

RevenueCat is app-side purchase UI only and is not part of service authorization. Debug macOS builds read the environment-scoped lab credential from the local `peacockery-voice/lab-api-key` Keychain item; release builds may inject `PEACOCKERY_VOICE_API_KEY`/`PeacockeryVoiceAPIKey`. Distributed clients must use the managed short-lived client-token flow rather than embedding its trusted parent key.

## What remains before the cloud-dictation alpha

The next work is verification and one contained History cleanup, not another general rewrite.

1. Make aggregate capture bounded and explicitly degradable, then accept device/permission/network lifecycle failures.
2. Verify global toggle/stop/cancel, paste into TextEdit and a browser/editor with the TimberVox window closed, and clipboard restoration behavior.
3. Accept application/window, selected text, clipboard boundaries, file/image metadata, and screen OCR in controlled macOS apps.
4. Persist the exact context snapshot and transform request/response metadata with each run, then verify History across quit/relaunch, search, playback, and rerun lineage.
5. Reconcile the accepted external UI mock-up with production one surface at a time, connected to real runtime state and verified in empty/loading/error/populated states through the launched app.
6. Repair RevenueCat Test Store products/packages and run purchase, cancellation, failure, entitlement-display, and restore acceptance as a separate app billing lane.

## Product paths

**Dictation** is a short record-to-delivery interaction. It returns text immediately, may apply a mode transform, saves the run, and pastes or copies the result.

**File transcription** imports finite audio or video and creates a durable, editable transcript with timed segments, optional speakers, reruns, and export artifacts.

**Meeting** is a durable session. Live text is provisional; the local master recording is finalized through the file-transcription path for stable speakers, timestamps, notes, and generated artifacts.

A meeting is an explicit app workflow, not a third ASR transport. It composes realtime and batch transcription without requiring a provider-specific `/meetings` API.

## Repository layout

```
TimberVox/       Mac application
TimberVoxTests/  Mac contract and persistence tests
old-app/         frozen reference implementation
docs/            roadmap, active TODO, architecture, and archived audits
project.yml      XcodeGen source of truth
```

Inside the Mac target:

```
TimberVox/
  App/       application entry points and shell
  Features/  visible product surfaces and their UI controllers
  Core/      shared workflows, domain models, storage, clients, and macOS services
```

Stateful types live with the domain they own. `Core/APIConnector` owns TimberVox
service connectivity, `Core/Delivery` owns clipboard and automatic-paste delivery,
`Core/Transcription/FluidAudio/ModelManagement` owns FluidAudio package downloads,
verification, progress, shared-asset deletion, and model-retention preferences, and
`Core/Database` owns durable History rows. There is no global Stores folder.

A folder is created when real files land, never as a placeholder. A sidebar tab exists only when its visible behavior and runtime path work.

## Current architecture

### Dictation

`DictationController` owns observable state, hotkey registration, and start/stop/cancel commands. `DictationWorkflow` resolves the active mode, owns a context-capture session for the lifetime of the recording, records audio, chooses batch or realtime transcription, optionally transforms text, saves raw/final metadata, and delivers the result.

Ordinary dictation records the microphone to a canonical 16 kHz mono WAV. A mode can additionally include system audio through one private Core Audio aggregate device containing the microphone and a mono process tap. The HAL synchronizes both sources; TimberVox resamples each stream, writes temporary microphone/system stems plus the canonical mixed recording, and sends the same live mixed PCM to realtime transcription when the selected route is realtime. Batch routes consume the mixed recording. Successful short dictation removes its temporary stems after finalization. The old app's misleading either-microphone-or-system behavior is not retained.

Batch transcription is finite request/response orchestration inside `CloudBatchTranscriber`: reserve upload, transfer directly to R2, complete, create a transcription job, and poll only when the Worker explicitly requeues that same job after a transient provider error.

Realtime transcription uses `CloudRealtimeTranscriptionClient` for the authenticated WebSocket and binary PCM/JSON wire contract. `CloudRealtimeTranscriptionSession` owns the app-side lifecycle, while `CloudRealtimeTranscriptAssembler` owns partial/final event composition. FluidAudio batch and realtime adapters remain separate implementations because they have different model lifecycles and APIs.

`TranscriptionRuntime` is the caller-facing speech-to-text boundary. It selects cloud or FluidAudio execution from `TranscriptionRouteSpec`, owns the active realtime session, and returns only `TranscriptionArtifact`. Dictation and History do not switch on the executor themselves.

### TimberVox service API

`Core/APIConnector` is the macOS adapter to Peacockery Voice. `APIConnector` owns common JSON requests, bearer authorization, signed uploads, and response validation. Debug builds select Voice Lab; release builds select Voice production. The generated Swift SDK is Git-importable from the private Peacockery Voice repository, while the specialized realtime WebSocket transport remains app-owned.

`ModelCatalog` contains the decoded service contract, `ModelCatalogAPIClient` fetches it, and `ModelCatalogStore` caches service state. `TranscriptionModelCatalogStore` merges those service-authoritative routes with the compiled local catalog for Modes and History without sending local audio through the Worker. The Mac never invents a cloud provider route, language list, or diarization capability absent from the service catalog.

### Text transforms and context

`TextTransformPreset` defines the built-in and custom instructions. `TextTransformPromptBuilder` produces real system/user messages from the transcript and enabled context. Dictation processing uses the versioned `POST /v1/text/stream` SSE contract so text arrives incrementally. The client validates sequence and provider/model identity and retains every event. `POST /v1/text` remains available for nonstreaming text and object operations.

The inherited Superwhisper response delimiter is no longer part of the prompt, Worker, or Mac contract. Streamed text and typed object output are explicit API paths rather than delimiter-parsed variants.

`SystemDictationContextProvider` supplies current application/window/document URL, focused element, selected text, visible accessibility text, language/time/locale/computer, and local user information. `DictationContextCaptureService` wraps it in a recording-scoped session, monitors clipboard and selection changes every 300 ms, retains a three-second pre-recording clipboard window, and records copied file/image metadata. Clipboard images remain local context attachments; the text prompt receives attachment metadata, not raw multimodal image input. Application and selection access depend on Accessibility permission. The former ScreenCaptureKit screenshot plus Vision OCR path was retired on 2026-07-18 after the Superwhisper context sweep showed no screenshot/OCR payload in the promoted request evidence. Historical `screenText` and screen-image attachment fields remain decodable so existing records and research evidence are not destroyed. Vocabulary remains unimplemented.

### Persistence

GRDB stores dictation records under `~/Library/Application Support/TimberVox/timbervox.sqlite`. A completed attempt uses one row with `succeeded`, `no_speech`, or `failed` status and structured error code/message. Whenever the transcription runtime produces a canonical `TranscriptionArtifact`, it is saved in `transcriptionArtifactJSON`; that includes no-speech inference, a failed realtime terminal event carrying an artifact, and successful transcription followed by failed text processing. Text processing saves one embedded `transformationJSON` capture containing the request, timings, every received stream event, and either its terminal outcome or failure. Context-aware processing saves the exact application/selection/clipboard/screen snapshot and attachment references in one `contextSnapshotJSON` payload on that same row; successful persistence transfers ownership of captured attachment files to History, and deleting the row removes those owned files. The row also keeps final text, raw text when transformed, mode/model/provider/language, transcription wall time, recording metadata, and the audio path as searchable product projections. Timed words, segments, tokens, scores, detailed metrics, provenance, warnings, and provider-native data live only in the canonical artifact rather than duplicated columns or JSON. ASR speed is explicitly RTFx—audio duration divided by processing duration—rather than the opposite real-time-factor convention. The migration retains previously stored scalar latency and segment payloads under explicit `legacyProviderLatencyMs` and `legacySegmentsJSON` names for inspection/export, but new rows never populate them. Historical external imports alone can lack an artifact because none existed at the source.

The remaining dictation persistence work is launched-app acceptance of the exact context snapshot and attachment lifecycle across success and failure paths. File and meeting persistence is designed when those concrete workflows are implemented; this roadmap does not pre-approve a second run object, one column per metric, or a table-per-collection schema.

## Later product slices

### Local models

The unified catalog and production dictation workflow now contain NVIDIA Parakeet batch and Nemotron realtime routes executed locally through FluidAudio. Model/provider presentation and artifact provenance identify NVIDIA as the model maker; FluidAudio is retained as implementation-library metadata. A package lifecycle discovers persistent FluidAudio assets, distinguishes downloaded files from models that successfully loaded, records FluidAudio-version-specific verification, prepares only unverified assets, and deletes shared assets safely. FluidAudio 0.15.5 fixes the former English Nemotron zero-shape load failure. On the Apple M1 test machine, every exposed Parakeet and Nemotron route now downloads, loads, and transcribes real speech; a complete offline system-audio record-to-delivery run also passed through persistence and clipboard delivery. The multilingual encoder still reports an Apple Neural Engine compiler failure before Core ML falls back and completes inference, so this is functional but not clean ANE execution. The remaining vertical slice is lifecycle UI, long/silent/cancel/timeout acceptance, broader Songbird language coverage, and measured storage/performance guidance. VAD, diarization, and keyword spotting remain later research until accepted as complete workflows.

### Sound feedback

Port start/stop/cancel sounds, resources, lifecycle, and Settings controls together.

### Hot mic and push-to-talk

Hot mic needs explicit buffer semantics and the realtime path. Push-to-talk needs the CGEvent tap and Accessibility UX. Do not add commands or settings before their runtimes exist.

### Dictionary and vocabulary

Resume after Modes and History are stable. Vocabulary must participate in actual context capture and transform acceptance rather than exist as dead settings data.

### File transcription

Reuse the direct R2 single/multipart upload and short-lived provider URL ingestion. Do not create a second long-media upload path. Build import, progress, cancellation, editable timed transcript, speaker renaming, playback seeking, rerun, and TXT/Markdown/JSON/SRT/WebVTT export.

Done means the AMI two-speaker fixture and a real long recording survive upload, provider processing, speaker editing, quit/relaunch, rerun, and export.

### Meetings

Capture microphone and system audio into a local master. Deepgram Nova-3 is the initial provisional live path because it supports streaming diarization. When the meeting ends, run the master through File Transcription and compare Deepgram batch with Mistral Voxtral Mini for the final diarized transcript. Summaries, minutes, and action items consume the final transcript, not the provisional stream.

FluidAudio streaming ASR plus LS-EEND/Sortformer diarization remains a research path. Separate adapters exist in the old app, but timestamp/speaker composition is not implemented or accepted in this rebuild.

## Billing and ship preparation

The intended accountless product split is `cloud_access` as a recurring managed-cloud purchase and `local_pro` as a one-time local purchase. Apple/RevenueCat remains an app concern. The Worker is intentionally decoupled from billing: configured static API keys authorize execution, while the deployed Cloudflare D1 records ownership, usage, and future key-scoped quotas.

App Store Connect contains the Cloud Access monthly subscription and Local Pro non-consumable for the universal app. RevenueCat contains the corresponding project, app, entitlements, products, packages, and offering, but the Debug Test Store mapping still needs repair and Apple's App Store Connect API key currently returns `401 NOT_AUTHORIZED` upstream. Do not generate more Apple keys merely to chase propagation.

Before shipping: complete Test Store and sandbox purchase/restore acceptance, verify universal purchase after the iOS app exists, enable the intended App Store signing/sandbox configuration, add the App Review screenshot, rotate the Cloudflare and R2 credentials supplied during setup, decide how release builds receive the static API key, and use build number 79 or later.

## Parts-bin map

- Hotkey tap and push-to-talk: `old-app/apps/mac/Sources/Services/KeyEventMonitorService.swift` plus the old core hotkey domain/logic.
- Paste behavior: `old-app/apps/mac/Sources/Services/PasteboardService.swift`.
- Rich transcript persistence: `old-app/packages/timbervox-core/Sources/TimberVoxCore/Transcripts/`.
- Local ASR: old Parakeet, FluidAudio, and streaming clients plus the old transcription core.
- Sound feedback: `old-app/apps/mac/Sources/Services/SoundEffectsService.swift`.
- Recording indicator behavior should be evaluated against the current passive, non-activating window implementation and live acceptance checks.
- Settings concepts: the old core settings model, mined selectively rather than ported wholesale.
- Caption/export primitives: old transcript/caption renderers, ported only with generated-artifact verification.

## Durable decisions

- Use stock SwiftUI/AppKit controls first and isolate custom interaction only when stock controls cannot satisfy it.
- Use Apple `swift format` plus strict curated SwiftLint; do not introduce a second formatter or a suppression baseline.
- Dictation means the whole record-to-delivery workflow. Transcription means only speech-to-text.
- Every exposed ASR route has an exact supported-language list. Unknown language support excludes the model.
- Transport support derives from route existence. Route-specific capabilities such as diarization are explicit fields.
- WAV is the current recording format: uncompressed PCM, native to produce, accepted by all current providers, and roughly 32 KB/s at 16 kHz mono 16-bit.
- There is no arbitrary TimberVox duration limit. Enforce known media types, exact byte size, R2 multipart constraints, provider maximums, credential quotas, and rate limits.
- Batch audio goes Mac → signed R2 upload → signed provider URL. It does not pass through Worker request memory.
- AI SDK remains the language-model transform framework. Provider-specific batch ASR URL adapters are owned by TimberVox because the generic transcription abstraction downloaded URL inputs into Worker memory.
- Carbon hotkeys remain the default until push-to-talk genuinely requires a CGEvent tap.
- Do not ship dead UI, speculative folders, silent fallbacks, or partially wired old-app subsystems.
