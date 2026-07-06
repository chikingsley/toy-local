# TimberVox Cloud Stack

This package is the TimberVox cloud boundary. The macOS app talks to this API for cloud language-model transforms, ASR, realtime ASR, licensing, usage logging, uploads, and jobs.

## Agreed Stack

- Runtime: Cloudflare Workers.
- Language: TypeScript.
- Package manager: pnpm.
- Web framework: Hono.
- Validation: Zod.
- Route contracts and OpenAPI: `@hono/zod-openapi`.
- Docs UI later: `@scalar/hono-api-reference`.
- Formatting and linting: Biome through Ultracite.
- Tests: Vitest.
- Worker runtime tests: `@cloudflare/vitest-pool-workers`.
- Deploy and local Worker runtime: Wrangler.
- Worker types: `@cloudflare/workers-types`.

The initialized package has pnpm, Ultracite, and Biome. This is a Worker API package, so the Biome config uses the Ultracite core and Vitest presets.

## API Shape

- Hono owns routing, middleware, and route composition.
- Zod owns every external input and output boundary.
- `@hono/zod-openapi` owns route contracts that become public API.
- Provider code receives typed values from route handlers.
- Public model IDs are TimberVox IDs.
- Provider model IDs stay behind the API boundary.
- Direct HTTP handles language-model transforms and batch ASR provider calls.
- WebSockets handle realtime ASR through Durable Objects.
- Public AI routes use TimberVox product workflows under the TimberVox domain.

Source layout:

```text
src/
  index.ts
  bindings.ts
  ai/
    batch-transcribe.ts
    text-transform.ts
    model-routes.ts
    registry.ts
    deepgram/
      realtime/
    mistral/
      realtime/
      transcription/
  http/
    json.ts
  durable-objects/
    realtime-session.ts
  jobs/
    consumer.ts
    db.ts
    enqueue.ts
    transcriptions.ts
  lib/
  routes/
    uploads.ts
    transcriptions.ts
    jobs.ts
    text-transforms.ts
    realtime.ts
  uploads/
    service.ts
```

File roles:

- `index.ts`: creates the Hono app, mounts routes, and exports the Worker `fetch` and Queue handlers.
- `bindings.ts`: central TypeScript type for Cloudflare bindings: D1, R2, Queues, provider secrets, and job rows.
- `ai/batch-transcribe.ts`: AI SDK batch ASR execution for job workers.
- `ai/text-transform.ts`: language-model transform execution. The app/Core renders prompt messages; the cloud route executes them.
- `ai/model-routes.ts`: TimberVox model IDs mapped to upstream provider model IDs.
- `ai/*/realtime/`: provider-specific realtime websocket bridges.
- `http/`: shared HTTP response helpers.
- `durable-objects/`: long-lived Cloudflare Durable Object classes such as realtime WebSocket sessions.
- `routes/`: HTTP contracts. Route files parse input, call services/providers, and return TimberVox responses.
- `jobs/`: D1-backed queue job creation, idempotency, queue consumer, status, and transcription job orchestration.
- `uploads/`: D1 upload metadata plus R2 source media writes.

Local references:

- `cloudflare-sw-compat`: small Hono app factory, Zod parsing, provider request builders, and live request-shape tests.
- `cloudflare-api`: full Cloudflare API reference with OpenAPI, Scalar docs, auth, client metadata, D1, R2, Queues, Durable Objects, jobs, uploads, captions, and deployed live tests.

## Cloudflare Primitives

D1:

- durable relational metadata
- users, API keys, license activations, provider credentials, requests, jobs, usage, and model routes
- upload metadata, job status, canonical result JSON, usage, auth, and routing state

R2:

- source audio and video
- optional debug captures

Queues:

- batch/file transcription
- transcription plus language-model transform
- provider retry/backoff
- webhook and billing fanout

Durable Objects:

- realtime WebSocket coordination
- provider WebSocket proxying
- session duration metering
- transcript event normalization
- final realtime result persistence

## Route Families

Request/response:

```text
GET  /health
POST /v1/text-transforms
```

Uploads and jobs:

```text
POST /v1/uploads
PUT  /v1/uploads/{upload_id}
POST /v1/transcriptions
GET  /v1/jobs/{job_id}
```

Realtime:

```text
GET /v1/realtime
```

Licensing and credentials:

```text
POST /v1/licenses/activate
POST /v1/licenses/validate
POST /v1/licenses/deactivate
POST /v1/api-keys/rotate
```

## First Build Step

1. Add dependencies and TypeScript/Wrangler config.
2. Add `src/index.ts` with `/health`.
3. Add a Zod/OpenAPI route skeleton.
4. Add model registries for ASR models and language models.
5. Add one live Vitest test against the local Worker runtime.
6. Add Mistral-backed text transform as the first real language-model route.
