# ToyLocal TODO (Execution Board)

Last updated: 2026-02-25

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

### [ ] P0-3 Release Metadata Consistency

- Scope: ensure all changesets reference the real package name (`toy-local-app`).
- Done when: changeset tooling can resolve all pending entries without unknown package errors.
- Test Gate:
  - `bunx @changesets/cli status --verbose` (or project-local equivalent once deps are installed)

### [ ] P0-4 Build Config Consistency

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

### [ ] P2-5 Alternative ASR Backend Evaluation (Qwen/MLX)

- Compare quality/latency/resource use vs Parakeet/WhisperKit.

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
- `cd ToyLocalCore && swift test`
- `xcodebuild -project toy-local.xcodeproj -scheme "toy-local" -configuration Debug build`
- `xcodebuild -project toy-local.xcodeproj -scheme "toy-local" -configuration Release build`
- pending `.changeset` entries validated.
