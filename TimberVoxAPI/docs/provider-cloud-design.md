# Provider and Cloud Design Notes

TimberVox Cloud is the API boundary for cloud ASR models, realtime ASR models, language models, licensing, request logging, usage tracking, and provider routing.

The cloud API uses direct HTTP for request/response provider calls and WebSockets for realtime provider sessions. The app talks to TimberVox Cloud. TimberVox Cloud talks to Mistral, Deepgram, ElevenLabs, and later providers.

TimberVox exposes product routes under the TimberVox domain. Provider selection happens through model IDs, credentials, and routing configuration behind those routes.

## Provider Paths

### Mistral

Mistral is the first integration target because it covers all three starting paths:

- Language models: `POST /v1/text`.
- Batch/offline ASR: request-based audio transcription with Voxtral Mini Transcribe.
- Realtime ASR: realtime audio transcription with Voxtral Realtime.

TimberVox implementation:

- `POST /v1/text` routes to a configured language model.
- `POST /v1/transcriptions` can route batch jobs to Mistral ASR.
- `GET /v1/realtime` upgrades to a TimberVox WebSocket, then the Durable Object opens the Mistral realtime session.

### Deepgram

Deepgram is an ASR provider.

TimberVox implementation:

- Batch/pre-recorded ASR uses direct HTTP to Deepgram listen.
- Realtime ASR uses a TimberVox WebSocket through the Durable Object if enabled.
- Deepgram callback mode maps to TimberVox jobs: Deepgram returns a request ID quickly, later POSTs the result to TimberVox, and TimberVox stores the canonical job result.

### ElevenLabs

ElevenLabs is a batch ASR provider in the current catalog.

TimberVox implementation:

- Batch ASR uses direct HTTP.
- Webhook-based transcription results map to TimberVox jobs.

## API Product Shape

TimberVox Cloud has three transcription/language-model paths.

### 1. Dictation and Language-Model Request/Response

Request/response means one TimberVox HTTP request returns the result directly.

Routes:

```text
POST /v1/text
```

Use this path for:

- language-model transforms
- provider health and smoke tests
- fast dictation where the user expects record, transcribe, optional language-model transform, paste
- BYOK provider-key smoke tests

Every request records D1 metadata: user, API key, provider, model, latency, status, audio seconds or token counts, estimated cost, and error shape.

The request/response ceiling is based on live limits:

- Cloudflare Workers paid plan: 128 MB memory, 10,000 subrequests per request, 6 simultaneous outgoing connections, default 30 seconds CPU time, configurable to 5 minutes CPU time.
- CPU time excludes waiting on provider network calls, database calls, and object storage calls.
- Incoming HTTP request wall time has no hard cap while the client remains connected.
- Request body size depends on the Cloudflare account plan: 100 MB on Free/Pro, 200 MB on Business, and 500 MB default on Enterprise.
- Response body has no Worker-enforced size limit.

The practical sync boundary is:

- provider latency and timeout behavior
- client connection reliability
- Worker memory if we buffer audio or provider JSON
- request body size if audio is sent through the Worker
- retry/resume requirements
- whether the UX needs progress updates

Initial sync ASR policy:

- Use sync ASR for dictation tests and fast product flows.
- Stream bodies where possible.
- Store large source audio in R2.
- Return a job path when the request needs retries, progress, resumability, webhooks, or multiple provider calls.
- Live-test Mistral sync ASR latency before making it the default dictation route.

### 2. Upload Plus Queued Job

File, meeting, media, and multi-step work use jobs.

Routes:

```text
POST /v1/uploads
POST /v1/uploads/{upload_id}/complete
POST /v1/transcriptions
GET  /v1/jobs/{job_id}
```

Flow:

1. App asks TimberVox Cloud for an upload reservation.
2. Worker creates D1 upload metadata and returns signed R2 single-PUT or multipart URLs.
3. App uploads audio/video directly to R2 and completes the authenticated reservation.
4. Worker verifies the exact object size; the app creates a transcription job using the returned `input_key`.
5. Queue consumer runs ASR, optional language-model transform, usage updates, and retry/backoff.
6. App polls or subscribes to job status.

Cloudflare Queue limits that shape this path:

- Message size: 128 KB.
- Maximum consumer batch size: 100 messages.
- Per-queue throughput: 5,000 messages per second.
- Consumer wall-clock duration: 15 minutes per invocation.
- Consumer CPU time can be configured up to 5 minutes.

Queue messages carry IDs and small parameters. D1 stores status, metadata, and canonical result JSON. R2 stores uploaded source media and optional debug captures. Caption, text, and document outputs are synthesized later from the canonical result.

Meeting-agent ingestion belongs to this job family. Zoom, Microsoft Teams, and Google Meet integrations should have their own integration layer for calendar permissions, bot identity, consent, meeting metadata, recording/webhook receipt, and participant context. After media is captured or received, it enters the same upload/job/transcription pipeline.

### 3. Realtime Session

Live dictation uses a TimberVox WebSocket.

Route:

```text
GET /v1/realtime
```

Flow:

1. App opens a WebSocket to TimberVox Cloud.
2. Worker routes the session to a Durable Object.
3. Durable Object accepts the TimberVox realtime session and normalizes TimberVox control/audio events.
4. A provider bridge owns upstream connect/send/parse/close differences. The Durable
   Object owns usage metering, normalized transcript persistence, and session lifecycle.

`/v1/realtime` is the route name. The WebSocket upgrade communicates the stream semantics. Add realtime subresources later when the API needs them.

## Upload Strategy

`POST /v1/uploads` authenticates the static API key, reserves metadata, and returns signed
R2 transfer URLs. `POST /v1/uploads/{upload_id}/complete` verifies ownership and exact
completed object size before the media may be used by a job.

Cloudflare R2 supports single PUT upload for small to medium objects under about 100 MB, with a 5 GiB maximum object size for single upload. Multipart upload supports large objects up to 5 TiB, parts from 5 MiB to 5 GiB, parallelism, and resumability.

TimberVox uses one path for dictation and long media:

- signed single PUT through 100 MiB
- automatically sized multipart transfer above 100 MiB
- short-lived signed R2 GET URLs for batch provider ingestion

There is no arbitrary TimberVox duration limit. Grounded media-type, declared-size,
R2/provider, key-scoped quota, and key-scoped rate-limit controls define the boundary.

D1 stores upload metadata. Raw media bytes live in R2.

## BYOK and Managed Cloud

TimberVox supports three provider credential modes.

```text
managed:
  provider key/account owned by TimberVox Cloud
  user never sees upstream provider credential

local_byok:
  provider key stored in app Keychain
  app sends key to TimberVox Cloud only for a request/session
  TimberVox Cloud treats the provider key as request/session scoped

server_byok:
  provider key stored encrypted by TimberVox Cloud
  TimberVox Cloud selects it by provider_credential_id
  useful for automation, multiple devices, and web clients
```

V1 uses `managed` and `local_byok`. `server_byok` is a later paid/convenience feature.

TimberVox Cloud stays in the path for BYOK so the app keeps one API contract, realtime sessions still use our Durable Object, and request logging/usage normalization stays consistent.

## Static API-key authorization

TimberVox API keys are independent of provider credentials and purchases.

- API request auth: `Authorization: Bearer <timbervox-api-key>`.
- Authority: the `TIMBERVOX_API_KEYS` Worker secret, encoded as a JSON array or comma/newline-delimited list.
- Accounting: the Worker hashes an accepted key and ensures one stable owner/key record in the deployed Cloudflare D1 on first use.
- Rotation: add the replacement key to the Worker secret and app, verify it live, then remove the old key from the secret.
- Billing: StoreKit/RevenueCat may drive app purchase UI but does not call, provision, authorize, or mutate this API.

Certificate/public-key pinning:

- Pin TimberVox Cloud public keys in the macOS app.
- Ship current and backup pins.
- Use URLSession server trust evaluation.
- Keep a rotation path through app updates.
- Pinning raises the cost of casual local MITM.

Client metadata headers:

```text
X-App-Id
X-App-Version
X-Platform
X-OS-Version
X-Client-Session-Id
X-Device-Model
X-Locale
X-Conversation-Id
```

## Payment boundary

Payment and App Store entitlement experiments remain in the clients. The Worker deliberately has no payment vendor module, webhook, license activation, installation table, or entitlement verification. Revisit this boundary only if the product later needs server-enforced per-user subscriptions; do not let that future decision block current app and API work.

## Model Registry

TimberVox public model IDs are product contracts. Provider model IDs are implementation details behind the API.

Registry layers:

```text
code registry:
  committed TypeScript list of public model IDs, providers, capabilities, default params, and display metadata

D1 model_routes:
  runtime overrides for provider routing, rollout, disable switches, pricing, BYOK routing, and migrations

provider model APIs:
  upstream discovery/reference
```

Use code registry first:

- version controlled
- reviewable in PRs
- covered by live tests
- deterministic local and deployed behavior
- enough for the first Mistral/Deepgram/ElevenLabs paths

Add D1 `model_routes` when we need:

- disable or reroute a model without deploy
- gradual rollout
- per-plan or per-user availability
- BYOK-specific routing
- pricing changes
- provider outage failover

OpenAI-style model list endpoints are curated public availability surfaces. TimberVox can expose an internal model registry route from the code registry plus active D1 route overrides when the app needs runtime discovery.

## Test Policy

Tests exercise live behavior:

- deployed tests hit the deployed Worker through HTTP/WebSocket
- provider tests call the real provider with real credentials
- upload tests write real R2 objects in a test namespace
- D1 integration tests execute against the deployed Cloudflare D1 through authenticated Worker routes

Mocked tests are not retained as verification. Provider, route, storage, queue, realtime, and usage behavior must be exercised against the real boundary it claims to verify.

## First D1 Schema Draft

D1 stores metadata, static-key ownership records, status, usage, costs, upload paths, and canonical job result JSON. R2 stores raw media and optional debug captures.

External precedents:

- LiteLLM: API keys, spend logs, budgets, provider credentials, model routing, daily usage.
- Helicone: user-facing gateway keys, provider keys, router config, soft deletion.
- Langfuse: traces/observations, usage/cost, blob/file logs.
- OpenAI public objects: upload/file boundaries.
- Local Superwhisper Cloudflare API: `api_clients`, `jobs`, `idempotency_keys`, `requests`, R2 bytes, Queue consumer, Durable Object realtime proxy.

Core tables:

```text
users
api_credentials
uploads
jobs
realtime_sessions
request_logs
usage_daily
model_prices
```

`usage_daily` is the daily aggregate for cost dashboards, rate summaries, abuse checks, and monthly billing. It tracks user/client, day, provider, model, request count, audio seconds, input tokens, output tokens, and estimated cost.

## Initial Implementation Order

1. Install Hono, Zod, `@hono/zod-openapi`, Wrangler, Workers types, Vitest, and Worker test support.
2. Add `/health`.
3. Add code registries for ASR models and language models.
4. Add Mistral-backed text transform route.
5. Add Mistral text-transform live test.
6. Add Mistral batch/offline ASR route contract and live test.
7. Add D1 request logging for language-model and ASR calls.
8. Add upload reservation plus Worker-mediated R2 upload.
9. Add queued transcription job.
10. Add `/v1/realtime` Durable Object WebSocket.
11. Add Deepgram and ElevenLabs adapters after the Mistral path is green.

## Open Decisions

- Transcription-plus-LLM shape: one job with ordered steps or two linked jobs.
