# Provider and Cloud Design Notes

TimberVox Cloud is the API boundary for cloud ASR models, realtime ASR models, language models, licensing, request logging, usage tracking, and provider routing.

The cloud API uses direct HTTP for request/response provider calls and WebSockets for realtime provider sessions. The app talks to TimberVox Cloud. TimberVox Cloud talks to Mistral, Deepgram, ElevenLabs, and later providers.

TimberVox exposes product routes under the TimberVox domain. Provider selection happens through model IDs, credentials, and routing configuration behind those routes.

## Provider Paths

### Mistral

Mistral is the first integration target because it covers all three starting paths:

- Language models: `POST /v1/text-transforms`.
- Batch/offline ASR: request-based audio transcription with Voxtral Mini Transcribe.
- Realtime ASR: realtime audio transcription with Voxtral Realtime.

TimberVox implementation:

- `POST /v1/text-transforms` routes to a configured language model.
- `POST /v1/transcriptions` can route batch jobs to Mistral ASR.
- `GET /v1/realtime` upgrades to a TimberVox WebSocket, then the Durable Object opens the Mistral realtime session.

### Deepgram

Deepgram is an ASR provider.

TimberVox implementation:

- Batch/pre-recorded ASR uses direct HTTP to Deepgram listen.
- Realtime ASR uses a TimberVox WebSocket through the Durable Object if enabled.
- Deepgram callback mode maps to TimberVox jobs: Deepgram returns a request ID quickly, later POSTs the result to TimberVox, and TimberVox stores the canonical job result.

### ElevenLabs

ElevenLabs is an ASR and realtime ASR provider.

TimberVox implementation:

- Batch ASR uses direct HTTP.
- Realtime ASR uses the TimberVox WebSocket and Durable Object proxy.
- Webhook-based transcription results map to TimberVox jobs.

## API Product Shape

TimberVox Cloud has three transcription/language-model paths.

### 1. Dictation and Language-Model Request/Response

Request/response means one TimberVox HTTP request returns the result directly.

Routes:

```text
POST /v1/text-transforms
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
PUT  /v1/uploads/{upload_id}
POST /v1/transcriptions
GET  /v1/jobs/{job_id}
```

Flow:

1. App asks TimberVox Cloud for an upload reservation.
2. Worker creates D1 upload metadata and returns a TimberVox upload URL.
3. App uploads audio/video through the TimberVox upload route, which stores the source media in R2.
4. App creates a transcription job using the returned `input_key`.
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
4. Provider realtime WebSocket bridging, usage metering, transcript normalization, and final result persistence plug into that Durable Object next.

`/v1/realtime` is the route name. The WebSocket upgrade communicates the stream semantics. Add realtime subresources later when the API needs them.

## Upload Strategy

The current upload path is Worker-mediated: `POST /v1/uploads` reserves metadata and `PUT /v1/uploads/{upload_id}` stores source media in R2.

Cloudflare R2 supports single PUT upload for small to medium objects under about 100 MB, with a 5 GiB maximum object size for single upload. Multipart upload supports large objects up to 5 TiB, parts from 5 MiB to 5 GiB, parallelism, and resumability.

TimberVox uses:

- Worker-mediated upload for the first app and live-test path
- direct R2 upload later when the app needs lower Worker bandwidth usage
- multipart upload later for very large media, meeting recordings, video, or unreliable networks

The Worker upload route enforces the Cloudflare request body limit for the account plan and TimberVox product limits.

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

## Auth, Licensing, and App Credentials

TimberVox API credentials are independent of provider credentials.

Credential shape:

- License key: emailed after purchase, pasted into the app.
- Activation: license key plus machine/device fingerprint plus client metadata.
- App credential: returned after activation and stored in Keychain.
- API request auth: `Authorization: Bearer <timbervox-credential>`.
- Server storage: hash TimberVox secrets before storing in D1.

Activation flow:

```text
1. User buys TimberVox Cloud.
2. User receives a license key by email.
3. App sends license key, machine fingerprint, and client metadata to TimberVox Cloud.
4. Server validates license status and activation limits.
5. Server creates or updates license_activation and api_key rows.
6. Server returns a TimberVox API credential or short-lived bootstrap token.
7. App stores the credential in Keychain.
8. Server can revoke the license, revoke the activation, or rotate the credential.
```

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

## Payment and Licensing Vendors

Payment and licensing are separate modules internally. TimberVox keeps its own `license_activations` and `api_keys` tables no matter which checkout provider is used.

Current vendor pricing and fit:

| Option | Current public pricing | Fit |
| --- | --- | --- |
| Lemon Squeezy | 5% + 50 cents per transaction, no monthly fee, merchant of record | Fastest direct-sold desktop/web checkout with license-key management. |
| Polar | Starter 5% + 50 cents; paid plans lower rates: Pro $20/mo at 3.8% + 40 cents, Growth $100/mo at 3.6% + 35 cents, Scale $400/mo at 3.4% + 30 cents | Strong modern MoR option; good if its license-key and webhook flow fits. |
| Paddle | Pay-as-you-go 5% + 50 cents per checkout transaction; custom pricing for under-$10 products or invoicing | Mature MoR billing/subscription platform; validate current licensing story before choosing it for desktop license activation. |
| RevenueCat | Entitlement/subscription platform for app-store and mobile-first products | Use when App Store/mobile subscriptions become central. |
| Keygen | Flat licensing platform; free dev tier, paid production tiers, device activations, node-locked/user-locked/offline licenses, no percentage of revenue | Use when license policy, machine activations, device limits, or offline validation need more depth than checkout-provider license keys. |
| Custom TimberVox licensing | Cloudflare D1 plus email/payment webhooks | Full control over activations and API credentials; more support and fraud surface. |

Starting choice:

- Use Lemon Squeezy or Polar for checkout and webhook flow.
- Keep TimberVox as the license/API authority.
- Add Keygen only if the in-house activation/device-limit implementation becomes too expensive or brittle.

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

- local Worker runtime tests hit the running Worker through HTTP
- deployed tests hit the deployed Worker through HTTP/WebSocket
- provider tests call the real provider with real credentials
- upload tests write real R2 objects in a test namespace
- D1 tests run against local or test D1 databases

Pure mocked tests can exist as helper checks while developing a parser or formatter, but they are not the acceptance gate for provider, route, storage, queue, realtime, licensing, or usage behavior.

## First D1 Schema Draft

D1 stores metadata, auth state, status, usage, costs, upload paths, and canonical job result JSON. R2 stores raw media and optional debug captures.

External precedents:

- LiteLLM: API keys, spend logs, budgets, provider credentials, model routing, daily usage.
- Helicone: user-facing gateway keys, provider keys, router config, soft deletion.
- Langfuse: traces/observations, usage/cost, blob/file logs.
- OpenAI public objects: upload/file boundaries.
- AssemblyAI transcript API: transcript status, error, webhook, words, utterances, chapters, audio ranges.
- Local Superwhisper Cloudflare API: `api_clients`, `jobs`, `idempotency_keys`, `requests`, R2 bytes, Queue consumer, Durable Object realtime proxy.

Core tables:

```text
users
license_activations
api_keys
provider_credentials
model_routes
uploads
transcription_jobs
transcripts
request_logs
usage_daily
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

- Payment provider: Lemon Squeezy vs Polar first.
- Licensing depth: TimberVox activation tables first vs Keygen earlier.
- Transcription-plus-LLM shape: one job with ordered steps or two linked jobs.
