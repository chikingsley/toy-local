# Hot Mic Voice Commands Plan

Research and planning snapshot: July 2026.

This is a product and architecture note for Hot Mic voice commands. It is not
an implementation claim. The current TimberVox app already has an always-on
streaming path; this plan describes how voice commands should sit on top of it.

## Direction

Hot Mic should stay owned by TimberVox.

The first implementation should be a local command layer that watches TimberVox's own streaming transcript output. A wake word can be added later, but it
should not be the core command system.

Target mental model:

```text
Hot Mic audio
  -> streaming ASR
  -> transcript buffer
  -> voice command service
  -> command registry
  -> command executor
```

The command system should work with whichever ASR backend is active. Apple
SpeechAnalyzer, FluidAudio streaming models, or another engine can produce
text, but command matching and action dispatch should belong to TimberVox.

## Research Summary

### Apple SpeechAnalyzer

Apple SpeechAnalyzer is an Apple Speech framework API, not a generic command
watcher and not a place where TimberVox plugs in its own ASR model. It can be
an optional Apple-native ASR backend: TimberVox feeds audio buffers into
SpeechAnalyzer modules such as SpeechTranscriber and receives live/final
transcription results. Under the hood, this uses Apple's speech stack and model
assets.

Use it, if at all, as an ASR backend option. Do not make it the voice command
architecture.

Reference:
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/videos/play/wwdc2025/277/

### Transcript Watcher

This is the preferred v1.

TimberVox watches its own transcript events and matches configured command
phrases against finalized or near-final utterances. This requires no retraining
when the user adds an alias such as "clear it" for Dump. The command registry
changes, and the matcher immediately sees the new phrase.

This approach fits Hot Mic because Hot Mic is already listening. The product is
not primarily "wake up, then listen"; it is "listen continuously, then let me
Paste, Dump, Cancel, switch modes, or run commands."

### Wake Word

Wake word is useful later for activating Hot Mic or entering a short command
attention window. It is not the same as command parsing.

Porcupine is the leading candidate to test for wake word. It is an on-device
wake word engine and supports custom wake words through Picovoice Console. A
future Hot Mic design could use Porcupine for:

- Turn Hot Mic on.
- Enter a short "command attention" window.
- Gate risky commands behind an explicit prefix.

Reference:
- https://picovoice.ai/docs/porcupine/

### Narrow Grammar / Intent Recognizer

This is an optional second command path if transcript watching is too fragile.

Options:

- FluidAudio keyword spotting: already present as a dormant client in TimberVox.
- Picovoice Rhino: realtime speech-to-intent for commands inside a fixed
  context.
- Vosk: older offline ASR toolkit with streaming and configurable vocabulary.

These are not first-choice dictation engines. They are candidates for a small,
local, low-latency command recognizer that only cares about a small vocabulary.

References:
- https://picovoice.ai/docs/rhino/
- https://alphacephei.com/vosk/

### Cloud Voice Understanding

OpenAI Realtime, Voxtral Realtime, and similar systems can understand spoken
intent, but they are not the TimberVox v1 direction for Hot Mic commands. The
local command layer should not depend on a cloud realtime API.

## Current TimberVox State

The app already has much of the Hot Mic substrate, currently named
"Always-On" in code.

Relevant current pieces:

- `AlwaysOnStore` owns always-on listening state.
- `AlwaysOnStore.confirmedText` stores finalized text.
- `AlwaysOnStore.currentPartial` stores in-progress partial text.
- `AlwaysOnStore.accumulatedText` exposes the pasteable buffer view.
- `AlwaysOnStore.pasteBuffer()` waits briefly, finalizes, transforms, saves,
  clears, resets streaming, and pastes.
- `AlwaysOnStore.dumpBuffer()` clears the current text and resets streaming.
- `StreamingAudioClientLive` captures 16 kHz mono audio chunks.
- `TranscriptionClientLive` routes streaming buffers to streaming Parakeet or
  streaming Nemotron.
- `TimberVoxSettings` already has `alwaysOnEnabled`,
  `alwaysOnPasteHotkey`, `alwaysOnDumpHotkey`, and
  `alwaysOnStreamingModel`.
- `FluidAudioKeywordSpottingClient` exists but is not wired into Hot Mic voice
  commands.
- `ForceQuitCommandDetector` is a one-off batch-transcript command detector.
  It proves the app already has the idea of speech-as-control, but it should
  not become the general command architecture.

## Proposed Components

### HotMicService

This may initially be `AlwaysOnStore` plus extracted helpers. Later, it can be
renamed or wrapped so the product language is Hot Mic while old settings can
migrate safely.

Responsibilities:

- Start and stop background listening.
- Own the active streaming ASR backend.
- Publish transcript events.
- Expose user actions such as Paste, Dump, Cancel, Toggle Hot Mic, and Switch
  Mode.

### TranscriptBuffer

Extract the buffer behavior from `AlwaysOnStore`.

Responsibilities:

- Keep finalized utterances.
- Keep the current partial.
- Track timestamps and source ranges when available.
- Produce the current paste snapshot.
- Clear the heard/queued state for Dump.
- Remove or mark consumed command phrases so command words do not get pasted as
  dictated content.

Dump should remain deliberately simple at this stage: it clears what Hot Mic
has heard/queued so the user can start fresh.

### VoiceCommandService

The watcher.

Responsibilities:

- Subscribe to transcript events from Hot Mic.
- Match commands against finalized utterances by default.
- Optionally watch partials only for safe/urgent commands later.
- Normalize text for case, punctuation, and whitespace.
- Enforce boundary rules, cooldowns, and confidence thresholds when available.
- Emit command intents to the executor.

The v1 matcher should be intentionally boring:

- Match short standalone phrases.
- Require word boundaries.
- Prefer finalized ASR text.
- Avoid matching a command buried inside a long sentence.
- Add a short cooldown after a command fires.

### CommandRegistry

Data-driven command definitions.

The user should be able to add phrases and aliases without rebuilding or
retraining. Adding a new action requires TimberVox to support that action type
or an external action provider such as Shortcuts or AppleScript.

Sketch:

```swift
struct VoiceCommandDefinition: Codable, Identifiable {
  var id: UUID
  var name: String
  var isEnabled: Bool
  var phrases: [String]
  var action: VoiceCommandAction
  var matchPolicy: VoiceCommandMatchPolicy
  var riskLevel: VoiceCommandRiskLevel
}
```

Built-in examples:

- Paste: `paste`, `paste that`, `insert that`
- Dump: `dump`, `clear it`, `forget that`
- Cancel: `cancel`, `stop`, `abort`
- Toggle Hot Mic: `start listening`, `stop listening`
- Change Mode: `change mode`, `next mode`

### CommandExecutor

Runs the action after the command matcher produces an intent.

Action families:

- Hot Mic: paste, dump, cancel, start, stop, toggle.
- Modes: change mode, switch to named mode.
- App control: open app, quit app, focus app, hide app.
- Window control: close window, minimize window, new window, switch window,
  cascade/rearrange windows.
- System/media: lock screen, mute, next track, pause/play.
- Developer workflows: restart server, restart dev server, run Codex, open
  Codex, run Claude, open Claude, scrape this, submit this, send this.
- Shortcuts: run a named macOS Shortcut.
- AppleScript/osascript: run a user-approved script.

The executor should have risk gates. Opening Warp is low risk. Quitting an app,
submitting a form, running a script, or sending content is higher risk and
needs explicit user opt-in, visible configuration, and probably confirmation
rules.

## User-Created Commands

There are two levels:

1. User adds a new phrase or alias for an existing action.
2. User creates a new action using a supported action provider.

Phrase aliases should be immediate and local:

```text
Action: Dump
Phrases: dump, clear it, forget that
```

New actions should be constrained by provider:

- Built-in action: TimberVox code owns the behavior.
- Shortcut action: TimberVox runs a named Shortcut.
- AppleScript action: TimberVox runs a stored script through osascript or
  NSAppleScript.
- App/window/system action: TimberVox uses existing macOS APIs, AppleScript,
  Accessibility, MediaRemote, or keyboard events where appropriate.

## False Positive Controls

Voice commands must be conservative by default. The nightmare case is normal
conversation triggering Paste, Dump, Submit, or Quit.

Default rules:

- Voice commands are disabled separately from Hot Mic.
- Match finalized utterances, not every partial.
- Require standalone phrase shape for short commands.
- Use word boundaries and normalized text.
- Do not fire if the command phrase appears inside a long dictated sentence.
- Cool down briefly after a command fires.
- Strip or consume the command phrase so it does not enter the paste buffer.
- Show visible/audible feedback after an action fires.
- Log command detections locally for debugging.

Riskier commands should add one or more gates:

- Require a command prefix.
- Require a wake word or command attention window.
- Require confirmation.
- Disable by default.
- Limit to specific apps or modes.

Example:

```text
Low risk:
  "dump"
  "paste that"

Medium risk:
  "open Codex"
  "switch to Email mode"

High risk:
  "send this"
  "submit this"
  "quit app"
  "run script"
```

## Wake Word Plan

Wake word should be a later layer, not the first voice command implementation.

Candidate: Porcupine.

Potential behaviors:

- "TimberVox" wakes Hot Mic from off to on.
- "TimberVox" opens a short command attention window, for example 3 seconds.
- A command prefix mode requires phrases like "TimberVox, dump" for risky
  actions.

Open questions:

- Should wake word be required only when Hot Mic is off?
- Should it gate every command or only risky commands?
- What is the product phrase?
- Does a custom wake word require an account, cloud training step, or shipped
  model file that conflicts with TimberVox packaging?

## UI Shape

Prototype direction:

- Hot Mic gets its own settings page.
- The top section controls Enable Hot Mic and Status.
- The Hot Mic command tiles are Start / Stop, Paste, and Dump.
- Voice Commands remains a separate section.
- Phrase aliases belong under each command.
- Later, add a command list for advanced commands.

Possible Voice Commands UI:

```text
Voice Commands
  Enable Voice Commands

  Built in
    Paste
      phrases: paste, paste that, insert that
    Dump
      phrases: dump, clear it, forget that
    Cancel
      phrases: cancel, stop, abort

  App Commands
    Open app
      prefixes: open, launch
    Quit app
      prefixes: quit, close

  Custom
    Run Shortcut...
    Run AppleScript...
```

## Integration Plan

### Phase 1: Extract Events and Buffer

- Keep `AlwaysOnStore` behavior working.
- Introduce transcript event types:
  - partial changed
  - utterance finalized
  - stream flushed
  - buffer pasted
  - buffer dumped
- Move `confirmedText`, `currentPartial`, `accumulatedText`, paste snapshot,
  and clear logic toward a `TranscriptBuffer` helper.

### Phase 2: Built-In Voice Commands

- Add `VoiceCommandService`.
- Feed finalized Hot Mic utterances into it.
- Implement built-in commands:
  - Paste
  - Dump
  - Cancel
  - Stop Hot Mic
  - Change Mode, once Modes exists
- Consume matched command text so it is not pasted.
- Add tests for normalization, boundaries, cooldowns, and long-sentence
  false positives.

### Phase 3: Command Registry and Aliases

- Add settings storage for voice command definitions.
- Let users edit phrases for built-in actions.
- Add enable/disable per command.
- Add command-level risk labels.

### Phase 4: External Action Providers

- Add "Run Shortcut" actions.
- Add AppleScript/osascript actions.
- Add app/window/system command providers.
- Permission-gate Accessibility, Automation, and Apple Events behavior.
- Add confirmations for risky actions.

### Phase 5: Wake Word Experiment

- Spike Porcupine as an optional wake word layer.
- Decide whether it turns Hot Mic on or only opens command attention.
- Measure CPU, latency, false positives, packaging, and user setup burden.

### Phase 6: Narrow Grammar Experiment

- Test FluidAudio keyword spotting against a tiny command vocabulary.
- Compare against transcript watcher for:
  - latency
  - false positives
  - false negatives
  - CPU
  - setup complexity
- Only add Rhino or Vosk if the built-in/local options are not enough.

## Testing Plan

Unit tests:

- Phrase normalization.
- Word-boundary matching.
- Standalone phrase matching.
- Alias updates.
- Cooldown behavior.
- Consuming command text from the buffer.
- Risk gates.

Integration tests:

- Fake Hot Mic transcript stream.
- Paste command fires once.
- Dump command clears buffer and resets streaming.
- Normal dictated text containing a command word does not trigger.
- Voice commands disabled means no command fires.

Manual probes:

- Say only "dump".
- Say "I need to dump this data later" and verify no command fires.
- Say "paste that" after real dictation.
- Say "open Codex" with app command provider enabled.
- Say "send this" and verify confirmation behavior.

## Open Questions

- Should commands match only a full finalized utterance, or the last short
  phrase after a pause?
- Should destructive commands require a prefix by default?
- Should phrase aliases be global or per mode?
- Should command actions be available only in Hot Mic, or also after normal
  push-to-talk recordings?
- How should command detections show in History, if at all?
- When command text is consumed, should the raw transcript still be available
  for debugging?
- What should the product wake phrase be?

