# Transcription contract and product paths

Status: descriptive architecture, updated 2026-07-18. The code and generated OpenAPI
document are canonical. This document explains the boundaries and must not duplicate
provider/model lists that can be read from the Worker.

## Canonical sources

- Public cloud catalog: `GET /v1/models`
- OpenAPI contract: `GET /openapi.json`
- Service contract and provider routing: private `chikingsley/peacockery-voice` repository
- Generated clients: `peacockery-voice/clients/typescript` and the root Swift package
- Batch execution: `peacockery-voice/src/jobs/transcriptions.ts`
- Realtime execution: `peacockery-voice/src/routes/realtime.ts` and durable objects
- Mac orchestration: `TimberVox/Core/Dictation/DictationWorkflow.swift`
- Mac transcription execution: `TimberVox/Core/Transcription/TranscriptionRuntime.swift`
- Local history: `TimberVox/Core/Database/TranscriptStore.swift`

Peacockery Voice owns provider routing, credentials, configured-provider availability,
supported languages, and route capabilities. The Mac consumes the normalized catalog;
it does not maintain a parallel cloud model list.

## Product paths

| Path | Input | Execution | Durable result |
| --- | --- | --- | --- |
| Dictation | Microphone, short form | Batch or realtime | Canonical transcription artifact, delivered text, and history projections |
| File transcription | Imported audio/video | Async batch | Editable transcript, runs, speakers, timestamps, artifacts |
| Meeting | Microphone + system audio | Realtime preview, then batch finalization | Meeting, master audio, final transcript, notes/minutes |

“Batch” and “realtime” are ASR transports. “Meeting” is a product workflow that composes
both. Dictation means the complete record-to-delivery workflow; transcription means only
speech-to-text.

## Shared batch data path

```text
Mac declares filename, media type, and exact byte size
  -> authenticated POST /v1/uploads
  -> Worker returns signed R2 single-PUT or multipart transfer
  -> Mac uploads bytes directly to R2
  -> authenticated POST /v1/uploads/{upload_id}/complete
  -> Worker verifies ownership and exact R2 object size
  -> transcription job signs a short-lived R2 GET URL
  -> provider-specific URL adapter
  -> normalized TranscriptionArtifact plus lossless provider capture
  -> typed job result
  -> Mac transform/persist/paste
```

Transfers use a single PUT through 100 MiB and an automatically sized multipart upload
above it. This threshold chooses the simpler R2 operation; it is not a product duration
limit. TimberVox does not proxy media bytes through Worker request memory and does not
load the R2 object into an `ArrayBuffer` for provider dispatch.

AI SDK remains the language-model transform framework. Batch ASR uses owned provider
adapters because the SDK transcription abstraction downloads URL input into bytes before
provider dispatch. Deepgram, Mistral, and ElevenLabs all receive the short-lived R2 URL.

Realtime keeps the same artifact schema, but not the same transport implementation. A
realtime provider bridge owns connect, audio/control writes, event parsing, and close
behavior; the Durable Object owns session lifecycle, artifact persistence, and usage. The
terminal WebSocket event and recovery endpoint return the artifact as `result`; they do
not duplicate transcript/model/provider fields beside it.

## Canonical transcription artifact

`TranscriptionArtifact` is the only successful transcription result contract across
Worker batch jobs, Worker realtime terminal events, cloud Swift adapters, and local
FluidAudio adapters. There is no legacy result union or client fallback.

The artifact retains exact transcript text; explicitly reports whether tokens, words,
segments, speaker turns, and audio events are available, omitted, not requested, or
unsupported; keeps provider-native scores beside normalized scores; records language,
timing, throughput, memory/GPU, usage, provenance, and warnings when available; and
captures the original provider response/events as JSON. UI and clipboard text are
projections from the artifact rather than alternate result contracts.

Provider adapters validate a typed normalization view without using that parsed view as
the raw capture. The artifact stores the untouched successful JSON response so fields
unknown to the current adapter schema are not stripped by validation.

## Workload authentication and ownership

Peacockery Voice authenticates an environment-scoped bearer credential by its D1 hash and derives a stable internal identity:

- `user_id`: API-key accounting owner
- `credential_id`: stable API-key record
- resource ownership for uploads, jobs, and realtime sessions
- idempotency scope and usage attribution

Client-provided ownership headers are observational and are not trusted for authorization. Missing, revoked, expired, wrong-environment, or wrong-scope credentials and cross-owner resource access fail closed. A trusted backend credential may mint short-lived managed client tokens; its parent secret is never embedded in a distributed app. RevenueCat and StoreKit remain outside the service authorization boundary.

## Provider direction

- Deepgram Nova-3: initial meeting realtime route; streaming diarization and batch
  finalization are both available.
- Mistral Voxtral Mini Transcribe: primary final/batch candidate for diarization,
  timestamps, and context biasing.
- Mistral Voxtral Realtime: live captions where diarization is not required; the provider
  does not combine realtime with its `diarize` option.
- Groq Whisper: intentionally not a TimberVox transcription route. Groq can remain a
  language-model provider when its credential is configured.

The public catalog exposes only configured providers. Provider availability and exact
language lists stay in code and `GET /v1/models`, not in this document.

## Local meeting research

FluidAudio upstream provides streaming ASR plus online diarization through LS-EEND and
Sortformer. The old TimberVox app contains separate streaming-ASR and diarization
adapters, including incremental timelines and finalization. It also explicitly blocks
their composition in the production workflow. A local meeting path is therefore
plausible, but it is not landed until one audio stream produces correctly aligned words,
speaker segments, and stable final output in the rebuilt app.

## Transcript library direction

The current rebuilt GRDB store writes one row for each completed local or cloud attempt,
including success, no speech, and failure. Its columns hold status/error facts, searchable
product facts, and recording metadata. Whenever the runtime produced an artifact—including
no-speech inference or a failed realtime terminal event—timed words, segments, tokens,
scores, detailed metrics, provenance, warnings, and provider-native data stay inside its
complete JSON. Text transformation is an embedded capture on the
same dictation record rather than a second artifact or run; it retains its request,
timings, every received SSE event, and its terminal outcome or failure. Historical imports
can have no artifact because their source application never supplied one.

File and meeting transcription will need additional persistence when those product paths
are implemented, but this document does not pre-approve a second run model or a table-per-
metric schema. Their storage must be designed from the concrete workflow and inspection/
export requirements at that time. Proven old-app caption renderers are ports to evaluate,
not architecture to bulk-copy.

## Live acceptance

Unit and contract gates support the proof; they do not replace it. The long-media path
is accepted only after real authenticated provider calls using the existing AMI
two-speaker fixture, a real multipart-sized file, and a 10–15 minute live
meeting with network interruption, local-audio survival, final batch reconciliation,
speaker editing, export, and quit/relaunch persistence.

## External references

- Cloudflare R2 uploads: https://developers.cloudflare.com/r2/objects/upload-objects/
- Cloudflare Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- Deepgram diarization: https://developers.deepgram.com/docs/diarization
- Mistral transcription: https://docs.mistral.ai/studio-api/audio/speech_to_text
- FluidAudio: https://github.com/FluidInference/FluidAudio
