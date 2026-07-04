# Changelog

## Unreleased

### Patch Changes

- Moved agent rules, gates, and resource references into a root `AGENTS.md`; `docs/TODO.md` now lists only work items, and completed phase notes moved to `docs/archive/phase-log-2026-07-04.md`.
- Dropdown panels now cap at six visible rows and scroll, dropdown sizing lives inside the menu components instead of call sites (the Preset menu is the one documented exception), and the voice-model picker sizes to its content so model names and section headers no longer clip.
- Wired previously dead settings to real behavior: "Paste result text" gates pasting (off copies to clipboard only), clipboard restore behavior is honored (Default/Restore/Bypass), "lower volume" during recording now ducks to 25% instead of full-muting, and automatic microphone volume raise sets the default input device to max during recording and restores it after.
- Removed settings controls that had no backing feature, to be restored as each feature lands: silence removal, dynamic normalization, error logging, menubar-click recording, always-close, hold-shift auto-send, voice model active duration, app folder location, agent plugins, experimental models, and the Modes realtime/identify-speakers/autocapitalize toggles.
- The History detail playback bar gained a working scrubber with live elapsed time and seeking.
- Dictionary is reachable from the sidebar again, grouped with Modes.
- The Modes language dropdown now offers only the selected voice model's supported languages and resets to Automatic when a model switch drops the current language, with unit tests on the policy.
- Replaced the placeholder smoke test with bundle-integrity checks for the language catalog and all sound-effect assets.
- Renamed `TranscriptionStore+Workflow.swift` to `TranscriptionStore+TextTransform.swift` to match its content.
- Verified every TODO item against the codebase (build, both test suites, settings consumers, cloud worker routes, entitlements, live-driver suites) and rewrote `docs/TODO.md` as a flat evidence-backed list with no phases and no tables.
- ToyLocal is FluidAudio-only.
- The visible model catalog is limited to supported Parakeet models.
- Settings and history are stored under ToyLocal application support paths.
- Added a first-run setup flow for Microphone and Accessibility permissions.
- Normal ToyLocal windows now stay hidden until required permissions are granted.
- If a required permission is removed later, ToyLocal returns to setup instead of continuing with broken hotkey/paste behavior.
- Removed App Sandbox so Accessibility permission prompting and text insertion can work correctly.
- Added PermissionPilot as a pinned Swift Package dependency for permission status/request plumbing.
- Added `toylocal://` and `toylocal-debug://` app-control links plus a Swift live driver that launches ToyLocal, resets permissions, captures debug state, and drives onboarding through AX button presses.
- Fixed hotkey keycap display for the grave/backtick key and Sauce-supported non-letter keys.
- Added Xcode preview entry points for the App and Settings shells with preview-safe settings storage.
- Removed InjectionIII/Inject hot-reload wiring and disabled Hardened Runtime for Debug builds so Xcode SwiftUI previews can JIT-link and render.
- Improved local dictation diagnostics by logging the selected/default microphone and detecting all-zero captured audio before transcription.
- Fixed Parakeet model readiness checks to recognize FluidAudio's Application Support cache directories.
- Documented the next Settings split around Dictation, Models, Transforms, History, and About/Updates.
- Added a source-backed FluidAudio model metrics inventory plus codable local diagnostic result schema.
- Added Core cloud transcription and language-model catalogs plus cloud metric profiles that stay aligned with Toy Local Cloud route IDs.
- Removed unsupported SenseVoice and Paraformer from the backend prototype supported inventory after probe runs hung or failed shape validation.
- Added a backend prototype `diagnostics` command that writes per-machine model timing/output reports.
- Added a Core transcription workflow contract for ASR, native/local VAD, native/local diarization, vocabulary handling, cloud text transforms, and output formats.
- Wired the production dictation path through an app-facing transcription workflow service for local FluidAudio ASR, Toy Local Cloud batch ASR, and cloud text transforms.
- Added quiet startup prewarm for the selected already-downloaded local batch ASR model.
- Added a production model-library adapter that groups local dictation, cloud dictation, streaming preview, cloud text, and support models for the future Models UI.
- Added observable text-transform/post-processing state, including empty-result and failure reporting in debug snapshots plus a real `toylocal-debug://text-transform` trigger.
- Consolidated the UI prototype onto a shared component library (`Prototype/UI/`, one component per file): one `ProtoDivider` replaced eight per-pane separator forks, surface colors/radii moved into `ProtoTheme` tokens, and one provider-logo registry replaced the two divergent logo systems.
- Prototype panes reorganized into `Panes/`/`Recorders/`; the outdated General pane was deleted after Configuration V2 absorbed its Permissions and Updates sections; Dictionary/History were brought onto the current design language, including a History detail picker default fix.
- Shortcut recording in the prototype now shows a pulsing recording chip and cancels on click-away/Escape (Shortcuts V2 and Hot Mic share one `ProtoShortcutRecorder`).
- Provider logos and appearance thumbnails moved into the asset catalog (template SVGs where available), replacing runtime `#filePath` PNG loading.
- Ported the Home pane with a real stats strip (words, average WPM, apps used, time saved) and a Today section reading the newest transcripts, completing the prototype-to-app port.
- Ported the History pane onto the transcript store: live records with search, dynamic day groups, data-driven app filters, persisted titles, raw/processed views, and real audio playback.
- Added a GRDB-backed transcript store in Core (recording table, FTS5 transcript search, retention sweep, legacy-history import) pinned at GRDB 7.11.1.
- Ported the Hot Mic pane (always-on enable and hotkey display bound to real settings) and the License pane (visual mock pending the license transport).
- Ported the Model library pane onto the production adapter: real sections, downloads, progress, deletion, sizes, and source-backed metrics, with selection persisted per model kind.
- Ported the Modes pane with a settings-backed Default mode: preset, language, voice model (from the real transcription catalog), language model, playback behavior, system-audio input, and auto-paste read from and write back to persisted settings.
- Ported and wired the Sound pane: real input-device list with System Default mapping, persisted recording toggles, playback-when-recording behavior, and Default/Classic sound-effect sets played by the sound service with volume and off states.
- Ported and wired the Configuration pane: appearance, login item, dock icon, retention, updates (Sparkle), permissions pills, text-input behavior, voice-model duration, and experimental-models toggles now bind to persisted settings; added the corresponding ToyLocalCore settings fields and split the settings schema into its own file.
- Ported the prototype shell into the app: `AppShellView` with the custom sidebar (Home / Modes / Settings / History / Pro card) replaced the TabView container, the prototype UI kit was promoted to `ToyLocal/UI/` under `TL*` names, and the main window is now hidden-title/transparent-titlebar with a fixed 820pt width, vertical resize, and a minimize button that hides while the sidebar rail is collapsed.

## 0.6.9

### Patch Changes

- 74893ab: Support escape sequences (\n, \t, \\) in word remappings for newlines, tabs, and literal backslashes (#140)

## 0.6.8

### Patch Changes

- e2000d8: Fix Icon Composer app icon not displaying (#148)
- 75bc323: Update macOS Tahoe app icon (#145)

## 0.6.7

### Patch Changes

- cc99650: Prepare release metadata for 0.6.6

## 0.6.6

### Patch Changes

- 3b6c966: Improve transcript modifications layout and remove log export settings
- 3b6c966: Add opt-in regex word removals for transcripts (#121)

## 0.6.5

### Patch Changes

- 140c205: Fix Sparkle auto-update for sandboxed app by adding required XPC entitlements and SUEnableInstallerLauncherService. Users on 0.6.3 will need to manually download this update.

## 0.6.4

### Patch Changes

- c00f79e: Reduce code duplication: add ModelPatternMatcher, FileManager helpers, settingsCaption style, notification constants, and Core Audio helper
- 658a755: Fix silent recordings caused by device-level microphone mute - automatically detects and fixes muted input devices before recording

## 0.6.3

### Patch Changes

- b4c54ce: Fix microphone priming and media pause races
- 5217d3f: Add word remappings and remove LLM UI (#000)
- 4d38708: Add persistent MCP config editing for Claude Code modes
- bbd0b80: Show system default mic name in picker
- bbd0b80: Fix Parakeet polling cleanup and organize paste flow
- 3413d68: Rename Transformations tab to Modes
- 4d38708: Fix microphone freezing and speech cutoff when using custom microphone. Only switch input device when actually needed, re-prime recorder after device changes, and add cleanup on app termination.

## 0.6.2

### Patch Changes

- 7e325ad: Fix Sequoia hotkey deadlock by removing Input Monitoring guard that prevented CGEventTap creation. Tap creation triggers permission prompt naturally. Re-add 'force quit ToyLocal now' voice escape hatch from v0.5.8 (#122 #124)
- 7e325ad: Add missing-model callout and focus settings when transcription starts without a model

## 0.6.0

### Patch Changes

- 3bf2fb0: Fix voice prefix matching with punctuation - now strips punctuation (.,;:!?) when matching prefixes

## 0.5.13

### Patch Changes

- 083513c: Add comprehensive documentation to HotKeyProcessor and extract magic numbers into named constants (ToyLocalCoreConstants)

## 0.5.12

### Patch Changes

- 471310c: Fix Input Monitoring permission enforcement for hotkey reliability

## 0.5.11

### Patch Changes

- 1deda2a: Route Advanced → Export Logs through the new swift-log diagnostics file so Sequoia permission bugs (#122 #124) can be diagnosed locally without relying on macOS unified logs.

## 0.5.10

### Patch Changes

- 3560bdb: Keep hotkeys alive on Sequoia and add voice force-quit plus Advanced log export (#122 #124)

## 0.5.9

### Patch Changes

- 6c2f1bd: Add comprehensive permissions logging for improved debugging and log export support

## 0.5.8

### Patch Changes

- 03b81c7: Let the hotkey tap start even when Input Monitoring is missing so Sequoia users get prompts again, while keeping the accessibility watchdog (#122 #124). Add a spoken “force quit ToyLocal now” escape hatch in case permissions clobber input.

## 0.5.7

### Patch Changes

- 539b0a4: Pad sub-1.5s Parakeet recordings so FluidAudio accepts them

## 0.5.6

### Patch Changes

- a1eb1d0: Restore hotkeys when Input Monitoring permission is missing (#122, #124)
- 1ee452a: Add non-interactive changeset creation for AI agents
- 68475f5: Fix clipboard restore timing for slow apps – increased delay from 100ms to 500ms to prevent paste failures in apps that read clipboard asynchronously

## 0.5.5

### Patch Changes

- 0045f28: Fix recording chime latency by switching to AVAudioEngine with pre-loaded buffers
- 7f6c5db: Actually request macOS Input Monitoring permission when installing the key event tap so Sequoia users can record hotkeys again (#122, #124).

## 0.5.4

### Patch Changes

- Fix hotkey monitoring on macOS Sequoia 15.7.1 by properly handling Input Monitoring permissions (#122, #124)

## 0.5.3

### Patch Changes

- Fix Sparkle update delivery by regenerating appcast with correct bundle versions and updating release tooling to prevent duplicate CFBundleVersion issues

## 0.5.2

### Patch Changes

- Fix Sparkle update delivery by regenerating appcast with correct bundle versions and updating release tooling to prevent duplicate CFBundleVersion issues

## 0.5.1

### Patch Changes

- Fix Sparkle appcast generation by cleaning duplicate bundle versions and updating release pipeline to preserve last 3 DMGs for delta generation

## 0.5.0

### Minor Changes

- 049592c: Add support for multiple Parakeet model variants: choose between English-only (v2) or multilingual (v3) based on your transcription needs.

### Patch Changes

- aca9ad5: Fix microphone access retained when recording canceled with ESC (#117)
- 049592c: Polish paste-last-transcript hotkey UI with improved layout and clearer instructions.
- 049592c: Improve hotkey reliability with accessibility trust monitoring and automatic recovery from tap disabled events (#89, #81, #87).
- 049592c: Improve media pausing reliability by using MediaRemote API instead of simulated keyboard events.
- 049592c: Fix menu bar rendering issue where items appeared as single embedded view instead of separate clickable menu items.
- 1b9bd52: Optimize recorder startup by keeping AVAudioRecorder primed between sessions, eliminating ~500ms latency for successive recordings
- 55fb4f8: Add a sound effects volume slider beneath the toggle so users can fine-tune feedback relative to the existing 20% baseline, keeping 100% at the legacy loudness (#000).

## 0.4.0

### Minor Changes

- e50478d: Add Parakeet TDT v3 plus the first-run model bootstrap, faster recording pipeline, and solid Fn/modifier hotkeys so the next release captures all of the recent feature work (#71, #97, #113, #89, #81, #87).

### Patch Changes

- ea42b5b: Move `ToyLocalSettings` + `RecordingAudioBehavior` into ToyLocalCore and add fixtures/tests so we can migrate historic settings blobs safely before shipping new media-ducking options.
- e50478d: Adopt Changesets for SemVer + changelog management, wire release.ts to fail without pending fragments, and sync the aggregated release notes into the bundled changelog + GitHub releases.
- 2fbbe7a: Wait for NSPasteboard changeCount to advance before pasting so panel apps always receive the latest transcript (#69, #42).

All notable changes to ToyLocal are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Added NVIDIA Parakeet TDT v3 support with a redesigned model manager so you can swap between Parakeet and curated Whisper variants without juggling files (#71).
- Added first-run model bootstrap: ToyLocal now automatically downloads the recommended model, shows progress/cancel controls, and prevents transcription from starting until a model is ready (#97).
- Added a global hotkey to paste the last transcript plus contextual actions to cancel or delete model downloads directly from Settings, making recovery workflows faster.

### Improved

- Model downloads now surface the failing host/domain in their error message so DNS or network issues are easier to debug (#112).
- Recording starts ~200–700 ms faster: start sounds play immediately, media pausing runs off the main actor, and transcription errors skip the extra cancel chime for less audio clutter (#113).
- The transcription overlay tracks the active window so UI hints stay anchored to whichever app currently has focus.
- ToyLocalSettings now lives inside ToyLocalCore with fixture-based migration tests, giving us a single source of truth for future settings changes.

### Fixed

- Printable-key hotkeys (for example `⌘+'`) can now trigger short recordings just like modifier-only chords, so quick phrases aren’t discarded anymore (#113).
- Fn and other modifier-only hotkeys respect left/right side selection, ignore phantom arrow events, and stop firing when combined with other keys, resolving long-standing regressions (#89, #81, #87).
- Paste reliability: ToyLocal now waits for the clipboard write to commit before firing ⌘V, so panel apps like Alfred, Raycast, and IntelliBar always receive the latest transcript instead of the previous clipboard contents (#69, #42).

## 1.4

### Patch Changes

- Bump version for stable release

## 0.1.33

### Added

- Add copy to clipboard option
- Add support for complete keyboard shortcuts
- Add indication for model prewarming

### Fixed

- Fix issue with ToyLocal showing in Mission Control and Cmd+Tab
- Improve paste behavior when text input fails
- Rework audio pausing logic to make it more reliable

## 0.1.26

### Added

- Add changelog
- Add option to set minimum record time
