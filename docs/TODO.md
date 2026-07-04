# ToyLocal TODO

Work items only. Rules and resources live in `AGENTS.md`; landed changes in `CHANGELOG.md`; history in `docs/archive/`. Every item below was verified against the code on 2026-07-04 (fresh build: zero errors; 78 Core + 18 app tests green). Nothing goes on this list without file:line evidence.

## Broken UI

- [ ] The Voice Model picker popover clips its content: logos flush to the edge, "Popular" header loses its first letter. The rows demand more width than the fixed 300pt frame (`ModesModelPicker.swift` PickerMetrics.panelWidth) while `TLFloatingWindowBridge.swift:72` sizes the child panel from `hosting.fittingSize` — two competing size authorities. Give the panel one size authority and make the content fit it. [B]
- [ ] The Modes language dropdown is double/triple the size of every other dropdown: `TLOptionMenuPanel` (TLOptionMenu.swift:122-156) stacks ALL options in a plain VStack — no row cap, no ScrollView — and the language list is the full bundled `languages.json`. Put the bounded-rows-then-scroll behavior INSIDE `TLOptionMenu`. Documented exception: the Preset dropdown may stay full height. [B]
- [ ] Dropdown sizing is set per call site — the banned pattern. Verified spread: TLOptionMenu default 152; ModesPane preset 152/204 (ModesPane.swift:167); stringOptionMenu threads width per call (ModesPane.swift:358); History filters 112/150 and 110/156 (HistoryPane.swift:157,163); ModesModelMenu 190/300 (ModesModelPicker.swift:7-8). Delete the parameters; components own their sizing. [B]
- [ ] After those three fixes: full popover pass in the REAL app (child panels cannot render in previews) — every dropdown in Configuration, Sound, Modes, Hot Mic, History filters: size, position, clipping, hover, click-away, screen edges. [C]

---

## Dead controls — settings that render and persist but change NOTHING (verified consumer-by-consumer)

Each needs a decision: wire it for real or delete the control before ship. Sorted worst first.

- [ ] "Paste result text" (autoPasteResult) — the paste path pastes UNCONDITIONALLY (`TranscriptionStore.swift:359` never reads the flag). Turning it off does nothing; this is a live behavior bug, not just a dead toggle. [A]
- [ ] Clipboard restore behavior — `PasteboardService.swift:141-150` uses a hardcoded delay and never reads `clipboardRestoreBehavior`. [A]
- [ ] Hold Shift to auto-send — `holdShiftToAutoSend` has zero references outside its toggle and schema. [A]
- [ ] Silence removal — production workflow omits VAD entirely (`TranscriptionStore+Workflow.swift:79-84` defaults `.disabled`) and `TranscriptionWorkflowService.swift:188-191` actively rejects local VAD. [A]
- [ ] Dynamic normalization — no consumer anywhere; recorder uses fixed PCM settings (`RecordingService.swift:29-37`). [A]
- [ ] Auto increase microphone volume — `RecordingAudioHardware.swift:154-171` only UNMUTES; no CoreAudio input-volume setter exists. [A]
- [ ] Error logging toggle — no log sink reads `errorLoggingEnabled`. [A]
- [ ] Voice model active duration — no keep-alive/unload timer reads `voiceModelActiveDurationMinutes`. [A]
- [ ] Show experimental models — nothing filters the catalog by `showExperimentalModels`. [A]
- [ ] Start recording on menubar click — no runtime consumer. [A]
- [ ] Always close recording window — no runtime consumer. [A]
- [ ] Autocapitalize insert (Modes) — not even persisted: lives only on `ModeDraft` (ModeDraft.swift:15), `applyDefaultMode` never saves it, and `insertTextAtCursor` inserts verbatim. [A]
- [ ] Identify speakers (Modes) — not persisted; production workflow omits diarization (defaults `.disabled`); a real FluidAudio diarization client exists but production rejects it (`TranscriptionWorkflowService.swift:193-197`). [B]
- [ ] Realtime toggle (Modes) — the capability gate works (`ModesPane.swift:191` checks supportsRealtime) but the toggle's value is never persisted or consumed. [A]

Wired and confirmed working, for the record: playback-pause-on-record (`RecordingService.swift:130-186`), system-audio capture (`SystemAudioTapRecorder.swift`), model prewarm (`AppStore.swift:326`), show Dock icon (`ToyLocalAppDelegate.swift:326-330`).

- [ ] "Lower volume" playback option actually FULL-MUTES — `.lowerVolume` falls into the same branch as `.mute` (`RecordingService.swift:149`). Implement real ducking or remove the option. [A]

---

## Distribution blockers (App Store target in ~2 days)

- [ ] DECISION FIRST: Mac App Store vs direct notarized download. Verified state: App Sandbox is OFF (`ENABLE_APP_SANDBOX = NO` in both configs, project.pbxproj:463,517; no sandbox key in ToyLocal.entitlements) and Sparkle self-update is fully wired (SUFeedURL appcast, Info.plist:55). MAS REQUIRES sandbox and FORBIDS Sparkle — and the app's core features (CGEvent-tap hotkeys, Accessibility text insertion, system-audio tap) do not work inside the sandbox. This is an architecture-level conflict, not a checkbox; it decides everything else in this section. [decision: Chi]
- [ ] Cloud base URL defaults to `http://127.0.0.1:8787` (`ServiceContainer.swift:70-77`); only an env var overrides it. Production cloud URL must be baked for release. [A]
- [ ] Cloud calls send NO auth: `ToyLocalCloudClient` supports a bearer token (:6,:109-111) but `ServiceContainer.swift:42` constructs it without one. Worker-side license/auth endpoints ALL exist (mint/revoke/activate/validate in `ToyLocalCloudflareApi/src/routes/licenses.ts`); the app has ZERO license code — LicensePane is a local @State mock. Build the app-side activate/validate + credential storage + bearer wiring. [A]
- [ ] Sparkle updater starts eagerly at launch (`CheckForUpdatesView.swift:11-16`), not gated on onboarding completion. [A]
- [ ] Release pipeline: signing environment, notarization, appcast with strictly increasing CFBundleVersion (direct-distribution path). [B]

---

## Half-built or orphaned

- [ ] History playback scrubber is a decorative fake: `Slider(value: .constant(0)).disabled(true)` with a static "0:00" (`HistoryDetail.swift:247-255`). Wire it to real playback position or remove the bar's slider. [B]
- [ ] Dictionary is mounted but unreachable: `PrototypeDictionaryPaneV2` renders for the `.dictionary` tab (`AppShellView.swift:73`) but `.dictionary` is in NO sidebar array — reachable only programmatically. Either add the sidebar entry or unmount it until the design pass. [B]
- [ ] `WordRemappingsView` (Features/Transforms) is orphaned — the only word-remapping editor, referenced solely by its own #Preview. Re-home it (Dictionary work). Note: the remap/removal APPLIERS are live in the pipeline and tested (WordRemappingTests, WordRemovalTests); only the editor is unreachable. [B]
- [ ] Language dropdown uses one global list (`["Automatic"] + store.languages` from bundled languages.json, ModesPane.swift:297, SettingsStore.swift:127-136) instead of per-model `supportedLanguages` (exists on specs, unused). Derive per model; reset to Automatic when unsupported. [A]
- [ ] Extra modes are mock — only the settings-backed Default mode is real. `Mode` model in Core with per-mode overrides resolving against global defaults; global paste-off forces per-mode Auto-paste off. [A]
- [ ] Verify whether `DictationContextCaptureBuilder` (Core, fully tested) is actually invoked in the production dictation path — unverified. [A]

---

## Cloud gaps (worker vs app, verified both sides)

- [ ] App-side realtime client: the worker already has a full `GET /v1/realtime` WebSocket route with Deepgram AND Mistral realtime clients behind a Durable Object (`routes/realtime.ts:65-162`); the app has NO WebSocket client at all — it only uses the batch REST path (upload→job→poll, working, `TranscriptionWorkflowService.swift:126-178`). [A]
- [ ] Flux: no route exists for it in the worker (zero matches). Add `flux-general-en`/`flux-general-multi` to model-routes, then to the catalog. [A]
- [ ] Batch vocabulary: the worker's batch path sends NEITHER `keywords` nor `keyterm`; the realtime path already supports both (`routes/realtime.ts:40-41,134-135`). Add per-model vocabulary params to batch (Nova-2 `keywords`, Nova-3 `keyterm`). [A]

---

## Reliability ports (verified: on upstream/main, NOT on this branch)

- [ ] Cherry-pick the six recording-reliability commits from `upstream/main` (fetched locally, confirmed absent from HEAD): `c5d5162` warm mic, `53b4d40` wake/route recovery, `d9e40cc` capture startup + mic selection, `55249a6` clipped fast recordings, `c00a91d` mic/recording hardening, `71878b7` route-change capture rebuilds. [A]
- [ ] Microphone failure state made visible and testable. [B]
- [ ] Always-on paste/dump determinism (edge/latch tests). [A]
- [ ] Streaming preview + batch finalization pattern (Nemotron preview, Parakeet final, observable fallback). [B]

---

## Testing gaps (verified: only 2 live suites exist — permission-onboarding, permission-regression)

- [ ] Write the missing live-driver suites (none of these exist today): hotkey-capture, model-download, recording-start-stop, textedit-paste, always-on-lifecycle, post-processing-state, settings-gate. [A]
- [ ] Replace `SmokeTests.testSanity` (literally `XCTAssertTrue(true)`) with a real launch smoke test. [A]
- [ ] Unit tests for each dead control as it gets wired (see the dead-controls section). [A]
- [ ] Vocabulary v1 persistence + apply-step tests once the editor is re-homed. [A]

---

## Cleanups

- [ ] Rename `TranscriptionStore+HotKeyInput.swift` (85 lines — the hotkey/push-to-talk input loop) to a self-describing controller. [A]
- [ ] Rename `TranscriptionStore+Workflow.swift` (114 lines — it is the post-transcription TEXT-TRANSFORM pipeline, not "workflow") accordingly. [A]
- [ ] Delete preview-only Prototype leftovers when their redesigns land: PrototypeShell.swift (defines preview-only `PrototypeWindow`), PrototypeModeSwitcher, the five recorder variants, PrototypeDictionaryPane v1. [A]
- [ ] Codex audit of the ported UI layer. [A]
- [ ] Periphery dead-code run before release. [A]

---

## Awaiting Chi's hands-on pass (agent-verified code-side, human feel unverified)

- [ ] Shortcut recording in real use (engine + 7 unit tests green).
- [ ] Sound effects audibility/style/volume (wired; labels verified as Default/Classic/Off — the old "rename Simple" item was based on a false premise and is dropped).
- [ ] History and Home on the real store (data wiring tested; look and feel not signed off).

---

## Later (parked)

- Dictionary/Vocabulary UI design pass (Chi). Captions/exports front end (SRT/VTT rendering exists in Core, tested, no UI). Correction loop / enhanced dictionary. Hot mic voice commands (plan doc). Diarization model picker. Recording HUD redesign (docs/recorders/). Error-logging sink decision. Monorepo decision; trigger phrases; license product decision.
