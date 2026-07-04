# ToyLocal TODO

Work items only. Rules and resources live in `AGENTS.md`; landed changes in `CHANGELOG.md`; history in `docs/archive/`. Every item below was verified against the code on 2026-07-04 (fresh build: zero errors; 78 Core + 18 app tests green). Nothing goes on this list without file:line evidence.

## Broken UI

- [x] 2026-07-04: The popover system was fixed in one pass. `TLOptionMenu` now caps at six rows then scrolls (`TLOptionMenuMetrics`; the bound lives inside the component), every call site lost its width/panelWidth overrides (the Preset menu keeps `panelWidth: 204` + `showsAllRows: true` as the ONE documented exception), the voice-model picker sizes to its content (`minWidth` 300, fixed frame removed), and both presentation paths (`TLFloatingHost` in-window and `TLFloatingWindowBridge` child panels) propose content its ideal size via `.fixedSize()`. Verification previews added in TLOptionMenu.swift and ModesModelPicker.swift; build and lint green.
- [ ] Chi's popover pass in the REAL app (child panels cannot render in previews) — every dropdown in Configuration, Sound, Modes, Hot Mic, History filters: size, position, clipping, hover, click-away, screen edges. [C]

---

## Dead controls — resolved 2026-07-04 (each was wired for real or removed from the UI)

Wired to real behavior (settings defaults preserve prior behavior; Chi verifies feel):
- [x] "Paste result text" now gates the paste: off = transcript copied to clipboard only (`TranscriptionStore.finishTranscription`). [C to feel]
- [x] Clipboard restore behavior consumed: Default = restore unless copy-to-clipboard is on (previous behavior), Restore = always, Bypass = never (`PasteboardService.shouldRestoreClipboard`).
- [x] "Lower volume" playback now actually ducks to 25% instead of full-muting (`RecordingClientLive+MediaControl.swift`, `RecordingAudioHardware+Volume.swift`), restore path unchanged.
- [x] Auto increase microphone volume: raises the system-default input device to max at record start and restores it after (`raiseInputVolumeToMax`/`restoreInputVolume`); skipped when a specific mic is selected, matching the control's hint.

Removed from the UI until their feature exists (settings fields kept; restore each row when wiring lands):
- [x] Silence removal and Dynamic normalization rows (SoundPane) — restore with the VAD/normalization work in the wiring matrix.
- [x] Error logging row — restore with the sink decision.
- [x] Start Recording on Menubar Click and Always close rows — menubar click needs an NSStatusItem rewrite (SwiftUI MenuBarExtra menu-style can't intercept left-click); always-close needs defined semantics.
- [x] Hold shift to auto-send row — restore with the auto-send feature.
- [x] Voice model active duration section — restore with the model keep-alive/unload timer.
- [x] App folder location section — the "Change folder..." button did nothing and the shown path (~/Documents/ToyLocal) was not where data lives.
- [x] Agent Plugins section — "Install" buttons did nothing; restore with the agent-plugins feature.
- [x] Show experimental models section — restore when the library adapter exposes an experimental flag.
- [x] Modes rows: Realtime (restore with the app-side realtime client), Identify Speakers (restore with diarization), Autocapitalize Insert (restore with the insert post-step); the backing `ModeDraft` fields were removed with them.

Wired and confirmed working, for the record: playback-pause-on-record, system-audio capture (`SystemAudioTapRecorder.swift`), model prewarm (`AppStore.swift:326`), show Dock icon (`ToyLocalAppDelegate.swift:326-330`).

- [ ] Unit tests for the newly wired branches (paste gate, restore decision, duck factor, input-volume raise) as part of the settings-persistence audit. [A]

---

## Distribution blockers (App Store target in ~2 days)

- [ ] DECISION FIRST: Mac App Store vs direct notarized download. Verified state: App Sandbox is OFF (`ENABLE_APP_SANDBOX = NO` in both configs, project.pbxproj:463,517; no sandbox key in ToyLocal.entitlements) and Sparkle self-update is fully wired (SUFeedURL appcast, Info.plist:55). MAS REQUIRES sandbox and FORBIDS Sparkle — and the app's core features (CGEvent-tap hotkeys, Accessibility text insertion, system-audio tap) do not work inside the sandbox. This is an architecture-level conflict, not a checkbox; it decides everything else in this section. [decision: Chi]
- [ ] Cloud base URL defaults to `http://127.0.0.1:8787` (`ServiceContainer.swift:70-77`); only an env var overrides it. Production cloud URL must be baked for release. [A]
- [ ] Cloud calls send NO auth: `ToyLocalCloudClient` supports a bearer token (:6,:109-111) but `ServiceContainer.swift:42` constructs it without one. Worker-side license/auth endpoints ALL exist (mint/revoke/activate/validate in `ToyLocalCloudflareApi/src/routes/licenses.ts`); the app has ZERO license code — LicensePane is a local @State mock. Build the app-side activate/validate + credential storage + bearer wiring. [A]
- [ ] Sparkle updater starts eagerly at launch (`CheckForUpdatesView.swift:11-16`), not gated on onboarding completion. [A]
- [ ] Release pipeline: signing environment, notarization, appcast with strictly increasing CFBundleVersion (direct-distribution path). [B]

---

## Half-built or orphaned

- [x] 2026-07-04: History playback scrubber is real — `HistoryStore` tracks live position (100ms ticker) and duration, `seek(to:)` moves the player, and the detail bar's slider scrubs while playing with a live elapsed label. Chi verifies feel. [C]
- [x] 2026-07-04: Dictionary is back in the sidebar (`ActiveTab.libraryTop = [.modes, .dictionary]`, matching Chi's stated grouping). The pane itself is still `PrototypeDictionaryPaneV2` pending Chi's design pass.
- [ ] `WordRemappingsView` (Features/Transforms) is orphaned — the only word-remapping editor, referenced solely by its own #Preview. Re-home it (Dictionary work). Note: the remap/removal APPLIERS are live in the pipeline and tested (WordRemappingTests, WordRemovalTests); only the editor is unreachable. [B]
- [x] 2026-07-04: Language dropdown derives from the selected voice model's `supportedLanguages` (empty set = unrestricted, which covers the cloud specs that don't declare languages), and switching to a model that lacks the current language resets it to Automatic in the mode-binding setter. Logic lives in `ModeLanguagePolicy` with six unit tests (ModeLanguagePolicyTests, all passing).
- [ ] Extra modes are mock — only the settings-backed Default mode is real. `Mode` model in Core with per-mode overrides resolving against global defaults; global paste-off forces per-mode Auto-paste off. [A]
- [x] 2026-07-04 VERIFIED WIRED: context capture sessions start at recording start (`TranscriptionStore.swift:144`), finish or cancel at stop (:390-392), and the snapshot flows into transcript persistence.

---

## Cloud gaps (worker vs app, verified both sides)

- [ ] App-side realtime client: the worker already has a full `GET /v1/realtime` WebSocket route with Deepgram AND Mistral realtime clients behind a Durable Object (`routes/realtime.ts:65-162`); the app has NO WebSocket client at all — it only uses the batch REST path (upload→job→poll, working, `TranscriptionWorkflowService.swift:126-178`). [A]
- [ ] Flux: no route exists for it in the worker (zero matches). Add `flux-general-en`/`flux-general-multi` to model-routes, then to the catalog. [A]
- [ ] Batch vocabulary: the worker's batch path sends NEITHER `keywords` nor `keyterm`; the realtime path already supports both (`routes/realtime.ts:40-41,134-135`). Add per-model vocabulary params to batch (Nova-2 `keywords`, Nova-3 `keyterm`). [A]

---

## Reliability ports (verified: from the original Hex repo, NOT on main)

- [ ] Cherry-pick the six recording-reliability commits preserved under the local tag `hex-upstream-2026-07-04` (the Hex upstream remote was removed 2026-07-04; the commits stay reachable via this tag, confirmed absent from main): `c5d5162` warm mic, `53b4d40` wake/route recovery, `d9e40cc` capture startup + mic selection, `55249a6` clipped fast recordings, `c00a91d` mic/recording hardening, `71878b7` route-change capture rebuilds. [A]
- [ ] Microphone failure state made visible and testable. [B]
- [ ] Always-on paste/dump determinism (edge/latch tests). [A]
- [ ] Streaming preview + batch finalization pattern (Nemotron preview, Parakeet final, observable fallback). [B]

---

## Testing gaps (verified: only 2 live suites exist — permission-onboarding, permission-regression)

- [ ] Write the missing live-driver suites (none of these exist today): hotkey-capture, model-download, recording-start-stop, textedit-paste, always-on-lifecycle, post-processing-state, settings-gate. [A]
- [x] 2026-07-04: `SmokeTests` now asserts bundle integrity — languages.json ships and decodes (with the Auto entry), and all six sound-effect assets resolve; this catches the flattened-assets regression class.
- [ ] Unit tests for each dead control as it gets wired (see the dead-controls section). [A]
- [ ] Vocabulary v1 persistence + apply-step tests once the editor is re-homed. [A]

---

## Cleanups

- [ ] Rename `TranscriptionStore+HotKeyInput.swift` (85 lines — the hotkey/push-to-talk input loop) to a self-describing controller. [A]
- [x] 2026-07-04: `TranscriptionStore+Workflow.swift` renamed to `TranscriptionStore+TextTransform.swift` to match its content (the post-transcription text-transform pipeline).
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
