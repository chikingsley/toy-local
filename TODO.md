# ToyLocal TODO (Execution Board)

Last updated: 2026-07-01

## Operating Rules

- Work from feature branches, not `main`.
- Every user-facing code change requires a `.changeset/*.md` entry.
- Each task below is complete only when its Test Gate passes.
- Prefer Red-Green-Refactor for bug fixes: reproduce bug in a failing test, then fix.
- End each session with either a commit or a short checkpoint note in this file.

## Priority Rubric

- `P0`: Shipping blocker, data loss, major reliability, permission flow breakage.
- `P1`: High-value UX/product improvements that are not blocking release.
- `P2`: Experiments and longer-horizon product ideas.

## P0 (Current)

### [ ] P0-0 Local Build + Signing Environment

- Scope: make the local release/debug environment match what the app target expects.
- Current evidence:
  - Xcode `26.6` on macOS `26.5.1` reports CoreSimulator `1051.54` while Xcode expects `1051.55`.
  - `softwareupdate --list` offers macOS `26.5.2`, likely carrying the newer CoreSimulator framework.
  - `security find-identity -v -p codesigning` reports `0 valid identities found`.
  - App target uses automatic signing, team `XM69J99HWP`, identity `Apple Development`.
- Done when: normal signed Debug builds work without `CODE_SIGNING_ALLOWED=NO`, and Xcode no longer emits the CoreSimulator mismatch warning.
- Test Gate:
  - Install the offered macOS update or otherwise align Xcode + CoreSimulator.
  - Add/download an Apple Development certificate for team `XM69J99HWP`.
  - `xcodebuild -project toy-local.xcodeproj -scheme "toy-local" -configuration Debug build`

### [ ] P0-1 Permission + Hotkey + Paste Reliability

- Scope: Complete and validate the current in-progress permission/paste/hotkey changes.
- Done when: Hotkeys work with Input Monitoring only; Accessibility is required only for cross-app paste/typing; denial flows are clear and non-spammy.
- Test Gate:
  - `xcodebuild -project toy-local.xcodeproj -scheme "toy-local" -configuration Debug build`
  - `cd ToyLocalCore && swift test`
  - Manual: fresh launch, deny Accessibility + allow Input Monitoring, confirm hotkeys still record.
  - Manual: allow Accessibility, confirm paste succeeds in TextEdit/Notes/Slack.
  - Manual: deny post-event access path and verify no repeated settings pop-open loops.

### [ ] P0-2 Always-On Hotkey Actions Are Deterministic

- Scope: Validate paste/dump hotkeys in always-on mode, including edge presses and held-key repeats.
- Done when: each physical press triggers at most one action; no duplicate paste/dump fire from key repeat.
- Test Gate:
  - Add/keep unit coverage for edge matching and latch behavior where practical.
  - Manual: hold paste hotkey does not spam multiple pastes.
  - Manual: hold dump hotkey does not spam multiple clears.

### [ ] P0-3 App Target Builds on Current Xcode

- Scope: keep the app target building on the active local Xcode and the CI Xcode toolchain.
- Done when: dependency pins and app code compile without package-level drift failures.
- Test Gate:
  - `bun run test:app`
  - `bun run test:release`

### [ ] P0-4 ASR Backend Product Direction

- Scope: decide whether ToyLocal is FluidAudio-only or keeps WhisperKit as an optional fallback.
- Current evidence:
  - WhisperKit is currently linked in `toy-local.xcodeproj`.
  - WhisperKit is imported by `ToyLocal/Services/TranscriptionService.swift` and `ToyLocal/Stores/TranscriptionStore.swift`.
  - `ToyLocal/Resources/Data/models.json` still exposes three Whisper models.
  - Non-Parakeet model names route through WhisperKit download/load/transcribe code.
- Proposed direction: FluidAudio-first, with WhisperKit removed unless there is a concrete public-app reason to keep it.
- Done when: model list, settings UI, package dependencies, storage paths, and transcription routing all match the chosen backend policy.
- Test Gate:
  - If removing WhisperKit: `rg -n "WhisperKit|whisperkit|Whisper" ToyLocal ToyLocalCore toy-local.xcodeproj` returns only intentional historical docs/changelog references.
  - `bun run test:app`
  - `bun run test:release`

### [ ] P0-5 Streaming Preview + Batch Finalization Architecture

- Scope: make always-on/live transcription reliable by separating low-latency preview from final paste quality.
- Intended pattern:
  - Streaming model supplies live partial text and indicator feedback.
  - Final paste/commit can reprocess the relevant buffered audio through a stronger batch model.
  - The batch model should default to a strong FluidAudio ASR model, not the streaming preview model, when latency is acceptable.
- Done when: paste/dump semantics, rolling audio buffer ownership, model selection, and fallback behavior are explicit and tested.
- Test Gate:
  - Unit coverage for paste/dump state transitions and buffer reset.
  - Manual: live partials continue updating while final paste waits for batch result.
  - Manual: final pasted text comes from the selected final model, with clear fallback if finalization fails.

### [ ] P0-6 Upstream Hex Audio Reliability Audit

- Scope: review upstream `kitlangton/Hex` changes without merging the full tree.
- Current evidence:
  - Fresh `upstream/main` is 32 commits ahead and 27 commits diverged from local `main`.
  - Full upstream merge would rename back to `Hex`, remove current `ToyLocal`/Observation files, and reintroduce TCA-era structure.
  - Relevant commits to mine manually: `c5d5162`, `53b4d40`, `d9e40cc`, `55249a6`, `c00a91d`, `71878b7`.
  - Highest-value files upstream: `Hex/Clients/RecordingClient.swift`, `Hex/Clients/SuperFastCaptureController.swift`, recording race/history tests, route-change handling.
- Done when: each relevant upstream audio/mic fix is classified as port, skip, or already covered, with a ToyLocal-native implementation plan.
- Test Gate:
  - Add regression tests matching any ported behavior before implementation.
  - Manual: wake, route change, call-audio-device, fast-recording, and microphone-switch flows.

### [ ] P0-7 Public Release Pipeline

- Scope: restore a real signing, notarization, Sparkle, GitHub release, and Homebrew cask workflow.
- Done when: one documented local or CI path can produce signed/notarized DMG + ZIP + appcast artifacts.
- Test Gate:
  - Dry-run or staging release produces artifacts without uploading to production.
  - Changesets apply cleanly and produce release notes.
  - Sparkle appcast has strictly increasing `CFBundleVersion`.

### [ ] P0-8 Build Config Consistency

- Scope: keep Debug/Release sandbox posture intentional and explicit.
- Done when: Debug and Release settings match intended entitlement behavior for permission testing.
- Test Gate:
  - Project builds in Debug and Release.
  - Permission prompts observed in real app runtime (not bypassed by accidental local config drift).

## P1 (Next)

### [ ] P1-1 Word Remappings UX Pass

- Scope: surface remappings earlier; simplify create/edit flow.
- Done when: adding/editing/removing remappings is fast for large lists.
- Acceptance:
  - Add action is visible without scrolling.
  - Edit mode has explicit confirm/dismiss behavior.
  - Keyboard-first flow works (Enter/Escape/tab order).
- Test Gate:
  - Unit tests for remapping/removal logic remain green.
  - Manual pass on long list (>100 entries) and normal list.

### [ ] P1-2 Hotkey + Mode Settings Redesign

- Scope: unify Push-to-Talk + Always-On hotkeys and mode controls in one coherent screen.
- Done when: users can configure all primary shortcuts in one place.
- Acceptance:
  - Push-to-Talk shortcut editable.
  - Always-On paste and dump shortcuts editable.
  - Paste-last-transcript shortcut discoverable in same workflow.
- Test Gate:
  - Settings capture tests pass.
  - Manual validation for modifier-only and key+modifier hotkeys.

### [ ] P1-3 Dump Action Feedback

- Scope: visible UI feedback when always-on buffer is dumped.
- Done when: users can immediately tell dump succeeded.
- Acceptance:
  - Indicator state change lasts long enough to perceive (~300-800ms).
  - No ambiguous “did it run?” state.
- Test Gate:
  - Manual UX pass in noisy and quiet speaking conditions.

### [ ] P1-4 Model Picker Clarity

- Scope: clearly communicate streaming vs batch, language strengths, and practical tradeoffs.
- Done when: users can choose a model without guessing.
- Acceptance:
  - Label Parakeet as streaming/multilingual.
  - Avoid meaningless always-maxed “accuracy/speed” bars.
  - Show concrete differentiators (latency, size, language support).
- Test Gate:
  - Manual verification for new users on first launch.

### [ ] P1-5 FluidAudio Model Catalog Refresh

- Scope: update ToyLocal's curated model catalog to current FluidAudio capabilities.
- Candidate model families:
  - Batch ASR: Parakeet TDT v3, Parakeet TDT v2, Cohere Transcribe.
  - Streaming ASR: Nemotron Speech Streaming tiers (`560ms`, `1120ms`, `2240ms`) plus existing Parakeet EOU only if still useful.
  - Diarization: Sortformer as recommended default, plus LS-EEND and the classic diarizer if they are viable in-app.
- Done when: each supported model has a typed enum/capability record, cache location policy, download progress, delete/show-in-Finder support, and clear UI copy.
- Test Gate:
  - Model list renders without Whisper-era assumptions.
  - Download availability detection works after restart.
  - Manual: select/download/delete each curated model family.

### [ ] P1-6 Diarization Product Spike

- Scope: decide where speaker diarization belongs in ToyLocal's workflows.
- Proposed default: Sortformer first, because FluidAudio exposes it as streaming diarization with fixed speaker slots.
- Questions:
  - Should diarization be always-on only, recording-only, or both?
  - Should output paste as speaker labels, rich history metadata, or both?
  - How should diarization interact with final batch transcription timestamps?
- Done when: one narrow user-facing workflow is chosen and prototyped behind a setting.
- Test Gate:
  - Manual: two-speaker recording produces stable speaker attribution.
  - Output format is readable when pasted into plain text fields.

## P2 (Exploration)

### [ ] P2-1 Transcript Post-Processing via LLM

- Modes: raw, clean prose, notes, custom prompt.
- Needs: provider config, key management, per-mode output handling.

### [ ] P2-2 Always-On Trigger Phrases

- Phrase-to-action mappings (paste/dump/submit/cancel/system actions).
- Keep safety boundaries explicit for system command execution.

### [ ] P2-3 Send-to-Server Mode

- Route selected transcripts to webhook/API endpoints by trigger phrase.
- Requires auth/header config and visible mode indicator.

### [ ] P2-4 Q&A + Optional TTS Response

- Voice query -> LLM response -> spoken or pasted output.

### [ ] P2-5 Alternative ASR Backend Evaluation

- Compare quality/latency/resource use for non-FluidAudio backends only after FluidAudio-first support is stable.

## Test Strategy (Swift)

### Unit Tests

- `ToyLocalCore` for pure logic (hotkey semantics, text transforms, migration behavior).
- `ToyLocalTests` for store/service helpers with fakes and deterministic inputs.

### Integration Tests (App Logic)

- Prefer dependency-injected store tests for behavior chains (permission -> monitor -> action).
- Add focused tests for bugs before fixes when possible.

### UI Automation

- Add/expand `XCUITest` flows for critical paths:
  - first-launch permissions guidance
  - settings hotkey capture
  - model selection + download status

### Performance Tests

- Use `XCTestCase.measure` and `XCTMetric` for:
  - remapping pipeline on long transcripts
  - always-on meter update path
  - model list refresh / settings load

## Bug Fix Workflow (TDD-Friendly)

1. Capture repro: one-sentence bug summary + exact steps + expected vs actual.
2. Add failing test closest to the broken logic.
3. Implement minimal fix.
4. Run focused tests, then full gate.
5. Add changeset summary referencing issue/PR number.
6. Commit with a user-facing subject and technical context in body.

## Release Gate (Before Merge)

- `git status --short` reviewed.
- `bun install`
- `bun run format:check`
- `bun run lint`
- `bun run test:core`
- `bun run test:app`
- `bun run test:release`
- Signed Debug/Release builds once P0-0 is complete.
- pending `.changeset` entries validated.
