# ToyLocal TODO — master plan

Last updated: 2026-07-04. This file is the single source of truth for every
agent working on this repo. Read it fully before touching anything. The old
root `TODO.md` was merged into this file, and the root file is now a pointer.

## Rules

- No commits until explicitly requested.
- Every item needs a verification gate, and the gate is named next to the item.
- Prefer real end-to-end tests over mocks; previews are for visual review.
- Keep tasks small enough that the next action is obvious.
- UI code follows the prototype conventions (see "UI ground rules" below).
- Files stay under 500 lines, and splits must be authentic: split along real
  reuse or responsibility boundaries, never mechanically by line count.
- Numbers are named constants; never repeat a magic number in two places.
- No code comments in prototype-derived UI code.
- Markdown in docs/ uses complete sentences and checkbox lists.

## How agents work here (Chi's operating preferences)

- Take UI direction literally. The prototype is very close to the final
  product; copy it physically into place and refine, do not reinterpret it.
- Prefer real tests. Reuse recorded provider responses before making live
  calls, and keep live API usage modest even when rate limits are generous.
- When behavior is uncertain or something fails, go back to the latest
  official documentation instead of guessing from memory.
- Choose the mainstream, widely-used approach first. If a more modern
  alternative exists, ship the mainstream one and note the alternative as a
  caveat in this file.
- Strict linting and strict formatting always; the point is best practices.
- Chat history is a resource (`chat-sync` skill). Past sessions across
  agents hold decisions and reverse-engineering work; search before re-deriving.
- After finishing a major section, run a Codex audit as an easy check:
  `codex` CLI, model gpt-5.5 at xhigh effort, prompt it to review the section.
- Reference apps installed on this machine: Superwhisper (primary design
  reference) and MacWhisper (secondary; also the competitive target after
  these phases). The superwhisper-api repo holds the reverse-engineering.

## Gates

### Fast Gate

- `swift format lint --recursive --configuration .swift-format ToyLocal ToyLocalCore ToyLocalLiveDriver/Sources`
- `swiftlint lint --quiet`
- `cd ToyLocalCore && swift test --parallel`
- `cd ToyLocalLiveDriver && swift build`
- `just test-app`

### Live Gate

- `just live-suite permission-onboarding debug`
- `just live-suite permission-regression debug`

### Release Gate

- Release xcodebuild, signed Debug build from Terminal, notarized artifacts,
  and a Sparkle appcast with strictly increasing `CFBundleVersion`.

## Docs map

- `docs/TODO.md` — this file: the plan and its order.
- `docs/app-organization.md` — the UI/IA spec. Parts are superseded by the
  prototype: a custom window split replaces TabView.sidebarAdaptable, History
  sits alone at the bottom of the sidebar, and License is the sidebar Pro card.
- `docs/hotkey-semantics.md` — the hotkey engine behavior spec (the 0.3s
  modifier-only threshold rules). Key-recorder wiring must obey it.
- `docs/recorders/recording-surfaces.md` — the recorder HUD state model.
  PARKED: the shipped recording UI keeps the app's existing pill indicator;
  the prototype recorder variants stay in the prototype until redesigned.
- `docs/hot-mic-voice-commands-plan.md` — a LATER feature plan.
- `docs/archive/` — historical working logs, kept for reference only.

## Testing resources (what an agent can drive without Chi)

- Debug deep links (`toylocal-debug://`): `state`, `check-permissions`,
  `show-onboarding`, `download-model`, `transcribe-file?model=…&path=…`,
  `text-transform?text=…&mode=…`, `quit`. These drive REAL transcription and
  REAL text transforms from the command line.
- Live driver (`ToyLocalLiveDriver`): launch, open-url, state assertions,
  AX tree, TCC reset, and the `just live-suite <name>` suites.
- Recorded provider responses: `ToyLocalBackendPrototype/Runs/` holds 69
  persisted runs including real Deepgram nova-3 responses (`raw.json`,
  `result.json`) and local model outputs — replay these before any live call.
- Local audio on this machine: MacWhisper/Superwhisper recordings and the
  backend-prototype fixture audio. Usable for smoke coverage; none has
  ground-truth transcripts, so no WER claims from them.
- Free/cheap live APIs: Mistral (free tier) for text transforms and Voxtral;
  Deepgram responses mostly replayed from Runs/. Live-call budget per
  feature: aim for 3–5 calls to prove the wire, then replay for regression.
- Xcode preview rendering (MCP RenderPreview) for visual verification in
  both color schemes.
- The cloud worker's admin endpoint can mint a real dev license for header
  and activation testing (Phase 4).

Testability classes used in the matrix below:

- **[A]** — agent-testable end to end (unit test, debug URL, live driver,
  or replayed fixture). The agent tests it and checks the box alone.
- **[B]** — agent tests the backend path and hooks up the UI; Chi does the
  final visual/interactive pass when he returns.
- **[C]** — requires human perception or hardware (hearing volume, watching
  media pause, physical mic behavior). Agent wires it and stages the test;
  Chi verifies.

# The plan, in order

## Phase 1 — Port the prototype into the app

Move `ToyLocal/Prototype/` UI into `Features/`, replacing the current
Features/Settings panes. The prototype is the design; the app is the truth
for behavior. Copy the prototype code physically, then wire it — do not
rewrite it from memory.

- [ ] Window chrome: custom NSWindow split (delegate-owned, transparent
      titlebar, no zoom button) replaces TabView.sidebarAdaptable. Traffic
      lights behave per the prototype: yellow hidden when the sidebar
      collapses, red fixed at the rail center. Vertical resize is allowed;
      horizontal stays constrained.
- [ ] Recording indicator: keep the app's EXISTING pill/capsule indicator.
      The prototype recorder variants (notch, caret, snap, window-surface)
      stay in the prototype until the recording UI gets its own design pass.
- [ ] Port slices, one pane per slice, each ending green and preview-verified:
  - [ ] 1. Shell + sidebar + navigation environment
  - [ ] 2. Configuration (largest wiring surface)
  - [ ] 3. Sound
  - [ ] 4. Modes (list + detail + create/delete)
  - [ ] 5. Model library (consumes `ModelDownloadStore.modelLibrarySections`)
  - [ ] 6. History (depends on the Phase 2 store)
  - [ ] 7. Home (depends on history stats)
  - [ ] 8. Hot Mic, License
- [ ] Naming cleanups during the move:
  - [ ] `TranscriptionStore+HotKeyInput` becomes `HotKeyInputStore` or an
        equivalently self-describing input controller.
  - [ ] `TranscriptionStore+Workflow` gets named for what it holds (request
        builders), not "workflow".
  - [ ] Decide the `Proto*` prefix question once at port time and apply it
        everywhere (proposal: drop the prefix on promotion).
- [ ] Delete superseded panes/files as each slice lands; no dual UIs.
- [ ] Run a Periphery dead-code pass after the port and delete what it finds.
- [ ] Codex audit of the ported UI layer when the slices are done.

## Phase 2 — Data + persistence

- [ ] GRDB transcript store: history rows, context snapshots, audio
      references, and (Screen Recording permitting) screenshots. Migrate the
      current file-based history into it. **[A]** (unit + migration tests)
      Decision is settled: GRDB over Core Data (inspectable schema, exact
      migrations, FTS5, live DB assertions), and Superwhisper's own storage
      validates the architecture — SQLite with GRDB migration tables, a
      `recording` table, an FTS5 table for raw/final transcript search, and
      per-recording folders holding audio plus `meta.json` (raw/final text,
      segments, model keys, prompt, context, timings). Model ours the same
      way: searchable metadata and text in SQLite, file-backed artifacts in
      per-recording folders.
- [ ] Retention: "Keep recordings for" is enforced by a sweep against the
      store. **[A]** (unit test with seeded old rows)
- [ ] History pane runs on the real store: real day groups, real app
      filters, detail page, playback wiring. **[B]** (agent seeds the store
      and asserts filters via debug state; Chi confirms feel)
- [ ] Home Today section and stats strip compute from the store. **[A]**
- [ ] Vocabulary v1: simple replacements and plain words persisted and
      applied in the existing word-remapping step. The Dictionary UI itself
      stays prototype-only (see LATER). **[A]** (unit tests on the apply step)
- [ ] Settings persistence for every new control: modes list, per-mode
      settings, appearance, retention, sound choices, shortcuts. **[A]**
- [ ] `Mode` model moves into Core with per-mode overrides resolving against
      global defaults; global "Paste result text" off forces per-mode Auto
      paste off and grays it. **[A]** (resolution unit tests)

## Phase 3 — Wiring + capability matrix

Every control in the UI gets wired and gated. The catalog already carries
capabilities (`TranscriptionCapabilities`) — the UI derives, never hardcodes.
The production model-library adapter now exists as `ModelLibraryCatalog` plus
`ModelDownloadStore.modelLibrarySections`; the visible Models pane still needs
to consume it during the prototype port.

| Control | Wire to | Test | Gate/notes |
|---|---|---|---|
| Voice model picker | `ModelDownloadStore.modelLibrarySections` / `ModelLibraryCatalog` | [A] | The adapter groups local dictation, cloud dictation, streaming preview, cloud text, and support assets; no fake models remain. Unit-assert grouping; debug-state assert selection. |
| Local model prewarm | `localModelPrewarmEnabled` + startup prewarm | [A] | Already-downloaded selected local batch ASR only; no auto-download. Debug state shows prewarm result. |
| Realtime toggle | `capabilities.realtime` | [A] | Hidden/grayed for batch-only models (Parakeet TDT). Unit-test the gating rule. |
| Language picker | `supportedLanguages` per model | [A] | Switching to a model that lacks the current language resets to Automatic and shows only its languages. Import per-provider language lists (Scribe/Deepgram) from superwhisper-api research + FluidAudio docs. Unit-test the reset rule. |
| Identify speakers | Core workflow diarization selection | [B] | One toggle; resolves native (`capabilities.diarization`) else local Sortformer. Agent verifies via `transcribe-file` on the two-speaker fixture; Chi confirms labels read sensibly. Explicit local-model picker is LATER. |
| Silence removal | local VAD (silero) via workflow service | [A] | Prototype-proven; promote the composition into `TranscriptionWorkflowService`. Replay Runs/ VAD fixtures; assert segment trimming. |
| Dynamic normalization | RESEARCH first: loudness normalization/AGC mainstream practice | [B] | Spike: what Superwhisper does + the standard approach (e.g. AVAudioEngine gain/compressor). Wire the mainstream option; note alternatives here. |
| Auto increase mic volume | CoreAudio input volume | [C] | Agent wires and asserts the volume value changed via CoreAudio query; Chi confirms with a real mic. |
| Playback when recording | pause/lower/nothing for system audio | [C] | RESEARCH: media-key pause vs output ducking. Agent wires; Chi verifies with music playing. |
| Record from system audio | existing capture path | [B] | Agent asserts captured buffers exist while a test tone plays; Chi sanity-checks quality. |
| Autocapitalize insert | text post-step | [A] | Unit test with lowercase fixture transcripts. |
| Paste result text / auto-send / clipboard behavior | existing pasteboard client | [A] | Live suite `textedit-paste` covers on/off; per-mode auto-paste respects the global switch. |
| Simulate keypresses | typing tracker path | [B] | Experimental; QWERTY-only warning stays. Agent drives a keypress-typing run into TextEdit via live driver. |
| Shortcut recorders | real key capture via `HotKeyProcessor`/KeyEventMonitor per `hotkey-semantics.md` | [A] | Live suite `hotkey-capture` + unit tests; capture actually records keys. Per-mode dispatch is Modes v1. |
| Launch at login | `SMAppService` | [B] | Agent asserts registration status after toggle; Chi confirms once after reboot/login. |
| Show in Dock / menubar click / always close | existing app-lifecycle settings | [B] | Agent asserts activation policy and window state via AX/debug state. |
| Keep recordings for | retention sweep (Phase 2) | [A] | Unit test the sweep. |
| Auto check/download updates | Sparkle (`SUEnableAutomaticChecks`) | [B] | Never before onboarding; missing-permission path pops the grant window. Agent asserts defaults wiring; real update check is release-gate manual. |
| Permissions pills | PermissionClient live state | [A] | Reuse onboarding status; permission live suites already exist. |
| Sound effects (Default/Classic/Off) + volume | `SoundEffectsClient` | [C] | Assets are in `ToyLocal/Resources/Audio/SoundEffects/` (`Default/` full set incl. start/stop/pre-stop/notification/error/no-result; `Classic/` start/stop). Rename the UI segment "Simple" to match the sets. Agent wires selection/volume plumbing; Chi listens. |
| Model download/delete/progress | `TranscriptionService` routing | [A] | Live suite `model-download` plus one real download run. |
| Presets | `TextTransformPreset` library | [A] | Prompt-builder unit tests exist; `text-transform` debug link proves the wire. |
| Text post-processing state | `TranscriptionStore.textTransformState` + debug snapshots | [A] | running/succeeded/empty_result/failed observable; real debug trigger exists; live suite still pending. |
| Error logging | LAST on the list | [B] | Decide the sink (local log vs tracker) before wiring. |

## Phase 4 — Cloud + license

- [ ] Mint a dev license against LOCAL `wrangler dev` (decided): use the dev
      `TOY_LOCAL_ADMIN_TOKEN` in `ToyLocalCloudflareApi/.env`, `POST
      /v1/admin/licenses` on localhost, then run activate/validate from the
      app and send auth headers on cloud calls. The app already supports a
      base-URL override (`TOY_LOCAL_CLOUD_API_URL`). The license UI stays
      mostly mock; the transport becomes real. **[A]**
- [ ] Cloud models appear in the library from the registry; the batch ASR
      path (upload → job → poll) already works and gets surfaced end to end.
      Replay saved Deepgram responses for regression; budget 3–5 live cloud
      runs to prove the wire. **[A]**

## Phase 5 — Testing program

- [ ] Live-driver suites carried from the original TODO: settings-gate,
      hotkey-capture, model-download, recording-start-stop, textedit-paste,
      always-on-lifecycle, post-processing-state, and the permission flows.
- [ ] Standard test modes, exercised against every applicable matrix row:
      local batch (Parakeet v3), local fast (110M), local streaming
      (Nemotron), cloud batch (Deepgram), voice-to-text (no LLM), message
      (LLM), and custom prompt.
- [ ] Model × language matrix from the imported language lists.
- [ ] Fixture policy: existing recordings are smoke coverage only (no ground
      truth); a ground-truth fixture set is a later investment.

## Resolved questions (2026-07-04)

- [x] Sound assets: Chi supplied them at
      `ToyLocal/Resources/Audio/SoundEffects/` (`Default/` and `Classic/`).
- [x] License minting: run against local `wrangler dev` with the dev admin
      token in `ToyLocalCloudflareApi/.env`; the deployed worker's admin token
      is not retrievable from local env/Cloudflare secrets. Do not also create
      `.dev.vars`, because Wrangler excludes `.env` values when `.dev.vars`
      exists.
- [x] API keys: `ToyLocalCloudflareApi/.env` holds `MISTRAL_API_KEY` and
      `DEEPGRAM_API_KEY` for the worker's live calls.
- [x] GRDB: approved and settled — the pin gets added in Phase 2; schema
      modeled on Superwhisper's proven layout (see Phase 2).

## LATER (parked features, in rough order)

- Dictionary/Vocabulary UI: stays purely in the prototype pending Chi's own
  design pass. The data layer (replacements applied to transcripts) ships in
  Phase 2; the pane does not.
- Captions/exports front end: the caption rendering layer exists in Core with
  no UI; exporting SRT/VTT is a next-level feature alongside the dictionary.
- Enhanced dictionary / correction loop (alignment diff, recurrence counts,
  proposal inbox; blueprint in superwhisper-api/macwhisper).
- Hot mic voice commands (see plan doc).
- Diarization model picker (explicit local-model choice).
- Recording HUD redesign (recorders spec + prototype variants).
- Error logging sink decision and wiring.
- Monorepo decision; trigger phrases; License/account product decision.

## Carried backlog (from the original TODO, still valid)

- [ ] Permissions: grant drive-through and failure diagnostics suites.
- [ ] Recording reliability ports from upstream commits (`c5d5162`,
      `53b4d40`, `d9e40cc`, `55249a6`, `c00a91d`, `71878b7`): cancellable
      start/cleanup, sleep release on short discard, captured duration at
      stop, delete audio on empty transcription, stop-sound ordering, wake/
      route-change observers with debounce, persistent device UIDs, stale
      playback guard.
- [ ] Microphone failure state made visible and testable.
- [ ] Always-on paste/dump determinism (edge/latch tests).
- [ ] Streaming preview + batch finalization pattern (Nemotron preview,
      Parakeet final, observable fallback).
- [ ] Diarization product spike (Sortformer default; open questions stand).
- [ ] Context capture: Screen Recording-aware screen/window snapshot path.
- [ ] Release: signing environment, Sparkle UX, public release pipeline.
