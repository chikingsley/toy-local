# TimberVox

TimberVox is a native macOS dictation and transcription application. The current rebuild combines short-form dictation, optional text transformation and context, local transcript history, and authenticated cloud transcription through the standalone Peacockery Voice service.

## Repository

- `TimberVox/` — macOS application
- `TimberVoxTests/` — real persistence integration and gated live acceptance tests
- `old-app/` — frozen reference implementation; evidence to port deliberately, not an architecture to copy
- `docs/TODO.md` — canonical active work
- `docs/REBUILD.md` — product and architecture roadmap
- `CHANGELOG.md` — completed rebuild work and verification

## Development

The Xcode project is generated from `project.yml`.

```sh
just check
just run-app
```

The private [`peacockery-voice`](https://github.com/chikingsley/peacockery-voice) repository owns the cloud API, OpenAPI contract, generated Swift/TypeScript clients, provider routing, and deployment gates. Debug/internal clients use `voice-lab.peacockery.studio`; production clients use `voice.peacockery.studio`.

The repository intentionally has no mocked unit-test suite. `just test` runs the real temporary-GRDB integration and compiles the gated acceptance harnesses. The gated macOS checks are exposed as `just test-live`, `just test-transform-live`, `just test-pause`, `just test-dual-speech`, `just test-endurance`, `just test-local-matrix-live`, and `just test-local-workflow-live`. They use real devices, permissions, model assets, databases, deployed providers, or human interaction.

The sample-backed connected UI prototype is available only in Debug with `just run-prototype`. It is design evidence, not shipped behavior.
