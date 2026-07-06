# TimberVox Cloudflare API TODO

## Local Contract + D1 Gates

- [x] Add local D1 upload/job/idempotency schema.
- [x] Add local D1 users, API credentials, model prices, request logs, and daily usage schema.
- [x] Record ASR seconds, language-model tokens, provider latency, and estimated cost when a model price exists.
- [x] Add transient provider-error classification for Queue retry decisions.
- [x] Add auth/license activation, validation, revocation, and app credential issuance.
- [x] Add auth-linked usage query/admin routes over D1 request logs and daily usage.
- [x] Add route contract tests for successful upload reservation, upload completion, transcription enqueue, idempotency hit, and job polling.
- [x] Add local D1 tests for ASR pricing, LLM token pricing, daily usage rollups, and credential storage.
- [x] Add route-owned `@hono/zod-openapi` definitions for the current handlers.

## Realtime + Captions

- [x] Bridge realtime Durable Object sessions to Mistral and Deepgram realtime WebSockets.
- [x] Persist final realtime result JSON.
- [x] Expose Swift cloud job result segments for client-side caption rendering.
- [x] Add Swift-side TXT, Markdown, HTML, JSON, PDF, DOCX, SRT, and WebVTT rendering from canonical job result JSON.

## Deployed Cloudflare Gates

- [x] Create and bind deployed D1, R2, main Queue, DLQ, Durable Object, Workers Logs, and Analytics Engine resources.
- [x] Apply deployed D1 migrations.
- [x] Deploy Worker with D1, R2, main Queue, DLQ, Durable Object, Analytics Engine, account id, usage dataset, admin token, Mistral key, and Deepgram key.
- [x] Validate deployed D1, R2, main Queue, DLQ, Durable Object, Workers Logs, and Analytics Engine resources.
- [x] Run deployed license create, activation, credential validation, revocation, and revoked-credential validation smoke.
- [x] Add Analytics Engine query/admin route with contract and local route tests.
- [x] Run deployed `/v1/admin/usage/analytics` against written Analytics Engine datapoints with a Cloudflare Analytics bearer token.

## Provider Live Gates

- [x] Run live Mistral text-transform smoke with the real `.env` key.
- [x] Run live ASR smoke with a real audio fixture path.

## Remaining App Wiring

### Local Transcript Library

- [ ] Add GRDB/SQLite and create the app DB under TimberVox Application Support.
- [ ] Add migrations for `audio_items`, `transcription_runs`, `transcription_segments`, `transcription_words`, `context_snapshots`, `context_attachments`, `transcription_artifacts`, and transcript FTS.
- [ ] Store source audio files under Application Support and keep relative path, file size, duration, hash, folder name, source app bundle ID/name, source window/title when available, and capture timestamps in `audio_items`.
- [ ] Store every ASR or text-transform attempt in `transcription_runs`: runtime (`local` or `cloud`), provider, model, upstream model name, preset ID, prompt ID, status, no-speech/error message, raw transcript, final transcript, raw/final word counts, provider latency, cloud upload ID, cloud job ID, canonical result JSON artifact ID, and timestamps.
- [ ] Store timed segments, words, confidence, and speaker IDs in `transcription_segments` and `transcription_words` when the provider returns them.
- [ ] Store exact context values used for a run in `context_snapshots`; store copied images, screenshots, and other binary context in `context_attachments` as files with DB metadata.
- [ ] Treat failed and no-speech attempts as visible history rows with their own status/message instead of dropping them.
- [ ] Treat manual rerun as a new `transcription_run` linked to the same `audio_item`; do not add app-side automatic retry rows to transcript history.
- [ ] Migrate existing `transcription_history.json` rows into the GRDB library and keep old audio paths resolvable.

### Credentials

- [ ] Add an app-owned Keychain store for TimberVox cloud credentials, license/session metadata, and optional BYOK provider keys.
- [ ] Store only Keychain item references or non-secret labels in SQLite.
- [ ] Store server-issued app credential expiration and refresh/validation timestamps so monthly subscriptions can expire while lifetime licenses remain valid unless revoked.
- [ ] Keep the emailed license key separate from the short-lived app credential/session token issued after activation.
- [ ] Keep `.env` or process-environment credentials only for local development and live test drivers.

### Context Capture + Prompt Assembly

- [ ] Add a `DictationContextCollector` that fills the existing `DictationContext` shape instead of relying on fixture-only context.
- [ ] Capture frontmost app, bundle ID, active window/title, focused accessibility element, selected text, system time, locale, time zone, computer name, user name when available, and vocabulary.
- [ ] Capture clipboard text immediately before recording starts.
- [ ] Track clipboard text changes during recording and append deduped text snippets to the clipboard context.
- [ ] Detect image clipboard items and copied files; store attachments locally and include them only in LLM requests that support image/file input.
- [ ] Add a screen/window screenshot context path behind the macOS Screen Recording permission check.
- [ ] Store the exact rendered prompt messages sent to a local or cloud language model.
- [ ] Add no-UI tests for selected text, active app/window, focused element content, pre-recording clipboard text, clipboard changes during recording, and image clipboard attachment metadata.

### Cloud Transcription Loop

- [ ] Add a Swift cloud client for credential validation, upload reservation, file upload, upload completion, transcription job creation, and job polling.
- [ ] Route runtime selection through one pipeline that supports local ASR, cloud ASR, and cloud text transform.
- [ ] Map cloud job results into the same local `audio_items` and `transcription_runs` storage used by local models.
- [ ] Support ASR-only and ASR-plus-text-transform flows where the app renders prompt messages and the cloud only executes the requested provider/model.
- [ ] Preserve raw transcript and final transformed transcript separately.
- [ ] Handle no-speech cloud results as completed/empty runs with a user-visible message and rerun affordance.
- [ ] Add no-UI live tests gated by environment credentials for Mistral ASR, Deepgram ASR with diarization, and one cloud text transform.

### Output Rendering

- [x] Port the reference caption artifact matrix from `superwhisper-api`: TXT, Markdown, HTML, JSON, PDF, DOCX, SRT, and WebVTT.
- [x] Generate artifacts from the canonical `CaptionDocument` instead of storing every export by default.
- [x] Support `transcript.plain.*`, `transcript.speakers.*`, `transcript.timestamps.*`, and `transcript.timestamps-speakers.*` for TXT, Markdown, HTML, JSON, PDF, and DOCX.
- [x] Support `transcript.plain.srt`, `transcript.speakers.srt`, `transcript.plain.vtt`, and `transcript.speakers.vtt`; timestamps are inherent to those formats.
- [x] Verify default cue settings for SRT/WebVTT: 42 characters per line, 2 lines per cue, and 7 seconds per cue.
- [ ] Add Deepgram diarization fixtures/live gates to verify speaker-aware TXT, SRT, WebVTT, Markdown, HTML, PDF, and DOCX output.
