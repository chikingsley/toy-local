# TimberVox mobile architecture and rebuild plan

Status: source of truth for rebuilding `apps/ios`. This document separates implemented source and simulator builds from physical-device acceptance. The durable Record workflow, normalized History, versioned keyboard bridge, and foreground-opening App Shortcut are implemented in source; non-silent physical recording, the keyboard round trip, Live Activity/two-invocation Shortcut behavior, mobile authentication, and the next TestFlight acceptance remain open.

The target is an iPhone-first Expo application with a native iOS keyboard and native system integrations. Web is a fast UI-development surface and Android remains a later platform; neither is allowed to distort the initial iPhone interaction model. iPad is not a target for this build.

## Product contract

TimberVox mobile has four first-class areas:

1. **Record** — select the active mode, start or stop dictation, see truthful live state, and use the same recording workflow the keyboard and Shortcut use.
2. **Modes** — create and edit named, icon-bearing modes that determine transcription and optional text processing.
3. **History** — browse saved dictations and open every item on its own detail route.
4. **Settings** — configure keyboard behavior, storage/privacy, Shortcut integration, access status, and account/license state.

The keyboard is a product surface, not a React Native screen. The Shortcut and Action button are system entry points into the same dictation workflow, not separate recorders.

## What the shared Shortcut actually does

The supplied iCloud Shortcut is named **Toggle Superwhisper Dictation**. Its decoded workflow is:

1. Run `com.superduper.superwhisper-ios.ToggleRecordingIntent`.
2. Test the intent's output.
3. When the output is empty, end the shortcut. This is the start-recording invocation.
4. When the output contains text, copy it to the clipboard, combine it as text, show a notification containing it, and vibrate. This is the stop-recording invocation.

TimberVox should reproduce the useful contract, not the Superwhisper identifier:

```text
ToggleTimberVoxRecordingIntent
  idle      -> start recording + Live Activity -> no transcript output
  recording -> stop/finalize                   -> transcript string output
```

The native App Intent should also be published as an App Shortcut so it is discoverable in Shortcuts, Spotlight, Siri, and the Action button. An optional installable TimberVox shortcut can wrap that intent with copy/notification/vibration behavior. The app's onboarding action should open TimberVox's App Shortcuts page or its own published iCloud shortcut; it must not link to the Superwhisper shortcut.

Apple's `AudioRecordingIntent` is the appropriate system contract. On iOS it requires a Live Activity for the full recording lifetime, otherwise the system stops recording. A `LiveActivityIntent` can launch the app process without presenting the app. This makes a no-foreground-launch flow plausible, but the exact Expo/JavaScript lifecycle still requires a physical-iPhone spike before ownership of capture and realtime transport is finalized.

## Verified current state

The repository contains working material that must not be erased by a starter reset:

- Expo Router, Expo Audio, Expo SQLite, Expo FileSystem, and an App Group bridge.
- A mode-aware realtime `DictationWorkflow` used by app, keyboard, and Shortcut request plans.
- Migrated SQLite Dictation/Artifact persistence, durable WAV files, searchable History, artifact detail tabs, real playback status/seeking, and retention controls.
- A Swift keyboard target with tap input, visible swipe trail, geometric decoder, predictions, preference mirroring, a dictation control, and request-owned final insertion.
- App Group schema v2 and generated keyboard/App Intent targets through `@bacons/apple-targets`.
- `AudioRecordingIntent`/`AppShortcutsProvider` source that opens the app and starts a Shortcut-owned request. This is not yet the accepted two-invocation background contract.

The Worker currently authenticates configured static API keys. Local development, internal preview, and the `testflight-dev` profile may embed one disposable, scoped test credential; it is intentionally extractable and must be revocable and rate-limited. The `production` profile explicitly omits it. Public release still requires a revocable mobile-session flow, and a user-facing API-key field remains out of scope.

## Source tree

```text
apps/ios/
  src/
    app/                         Expo Router route files only
      _layout.tsx
      (onboarding)/
        welcome.tsx
        permissions.tsx
        shortcut.tsx
      (tabs)/
        _layout.tsx
        record/
          _layout.tsx
          index.tsx
        modes/
          _layout.tsx
          index.tsx
          new.tsx
          [modeId].tsx
        history/
          _layout.tsx
          index.tsx
          [dictationId].tsx
        settings/
          _layout.tsx
          index.tsx
      account.tsx
      sheets/
        mode-picker.tsx
        preset-picker.tsx
        icon-picker.tsx
        model-picker.tsx
        language-picker.tsx
        retention-picker.tsx
    components/
      ui/                         React Native Reusables source owned by this app
      app/                        Small TimberVox compositions
        app-screen.tsx
        app-section.tsx
        settings-row.tsx
        mode-identity.tsx
        mode-row.tsx
        history-row.tsx
        recording-control.tsx
    features/
      account/
      dictation/
      history/
      modes/
      onboarding/
      settings/
    lib/
      api/
      db/
      files/
      app-group/
      auth/
      platform/
      utils.ts
  targets/
    keyboard/                     Swift keyboard extension
    recording-activity/           Live Activity / widget target
    _shared/                      Swift compiled into the required Apple targets
  tests/                           Tests stay outside `src/app`
```

Route files compose features and contain no persistence, recording, or API implementation. Feature modules own state and use cases. `lib` owns reusable infrastructure. Native target files remain declarative inputs to Continuous Native Generation; generated `ios/` is disposable.

## Component system

React Native Reusables is the primary screen component system. It is source code copied into this app, not a black-box package, and can be used directly in the existing Expo project. We will configure it manually rather than run a new-project initializer, because initialization must not replace the keyboard target or current native configuration.

Use the documented NativeWind path first. The setup requires `components.json`, NativeWind/Tailwind configuration, `inlineRem: 16`, semantic theme tokens, `PortalHost`, `cn`, and the required primitive dependencies. Run the RNR `doctor` command after setup. Do not add every component preemptively.

Initial RNR primitives:

- `text`, `button`, `card`, `separator`, `badge`
- `input`, `textarea`, `label`, `select`, `switch`
- `tabs`, `dialog`, `alert-dialog`, `popover`
- `progress`, `skeleton`, `collapsible`

RNR currently does not provide the exact iOS settings-list item or an app drawer. One thin `SettingsRow` composition is justified and must be built only from the primitives above. Expo Router's native `formSheet` presentation is the first choice for mobile pickers; do not add a second bottom-sheet framework unless an accepted interaction cannot be expressed with a route-backed form sheet.

Use semantic color and spacing tokens. Do not hand-style every screen with raw hex values and one-off `StyleSheet` blocks. Do not create fake controls, fake waveforms, or placeholder charts that imply data the runtime does not produce.

## Approved dependency map

This is the exact library boundary for the rebuild. A dependency is added only for the responsibility listed here.

| Responsibility                                                       | Library and current version                                                                                                   | Status and implementation rule                                                                                                                                                                                                                                                                                                                                                                                |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App routes, native bottom tabs, nested stacks, form sheets           | [`expo-router`](https://docs.expo.dev/versions/v57.0.0/sdk/router/) `~57.0.4`                                                 | Installed. The accepted product choice is `NativeTabs` from `expo-router/unstable-native-tabs` for Record, Modes, History, and Settings, with one nested `Stack` per tab so each tab preserves its own detail navigation. Picker routes use `presentation: 'formSheet'`. The API is explicitly unstable, so Expo Router upgrades require a focused tab-shell regression pass.                                 |
| Screen component source                                              | [React Native Reusables](https://reactnativereusables.com/docs) CLI-generated source                                          | Configured. RNR is the source-owned component system, not a runtime package. Add a component only when a named screen needs it. `text`, `button`, `icon`, and the History `tabs` composition are installed now.                                                                                                                                                                                               |
| Utility styling and semantic theme tokens                            | [NativeWind](https://www.nativewind.dev/docs/getting-started/installation) `^4.2.6` + Tailwind `^3.4.19`                      | Installed and verified by RNR doctor. Layout uses `className`; colors come from semantic tokens in `global.css` and `theme.ts`.                                                                                                                                                                                                                                                                               |
| RNR primitive internals and overlays                                 | `@rn-primitives/portal` `~1.4.0`, `@rn-primitives/slot` `^1.5.2`                                                              | Installed. `PortalHost` is mounted once at the root.                                                                                                                                                                                                                                                                                                                                                          |
| Structured product data                                              | [`expo-sqlite`](https://docs.expo.dev/versions/v57.0.0/sdk/sqlite/) `~57.0.0`                                                 | Installed. One migrated database owns modes, dictations, artifacts, and app settings.                                                                                                                                                                                                                                                                                                                         |
| Persistent recordings and generated artifacts                        | [`expo-file-system`](https://docs.expo.dev/versions/v57.0.0/sdk/filesystem/) `~57.0.0`                                        | Installed. Durable files live beneath `Paths.document`; transient upload/export work may use cache.                                                                                                                                                                                                                                                                                                           |
| PCM streaming, recording session, and history playback               | [`expo-audio`](https://docs.expo.dev/versions/v57.0.0/sdk/audio/) `~57.0.0`                                                   | Installed. `AudioStream` supplies real PCM to the Worker; `useAudioPlayer`/status supplies real playback time. Final native ownership remains gated by the App Intent device experiment.                                                                                                                                                                                                                      |
| Local batch and realtime speech recognition                          | [FluidAudio](https://github.com/FluidInference/FluidAudio) `v0.15.5` through the source-owned `TimberVoxLocalAsr` Expo module | Installed and pinned by tag. The module owns the paired Parakeet TDT-CTC 110M batch and Parakeet EOU 120M/320 ms realtime package, download/progress/delete state, model loading, PCM conversion, partial events, and final text. TypeScript selects batch or realtime from the saved mode and adapts both to the shared dictation workflow. Physical-iPhone performance remains an explicit acceptance gate. |
| Canonical app and Shortcut text delivery                             | [`expo-clipboard`](https://docs.expo.dev/versions/v57.0.0/sdk/clipboard/) `~57.0.0`                                           | Installed. Delivery occurs after durable persistence. App and Shortcut entry points copy the canonical result; the keyboard entry point publishes the request-matched result through the App Group bridge.                                                                                                                                                                                                    |
| Keyboard, App Intent, Live Activity, and App Group target generation | [`@bacons/apple-targets`](https://github.com/EvanBacon/expo-apple-targets) `^4.0.7`                                           | Installed. Target source stays in `targets/`; generated `ios/` remains disposable. `ExtensionStorage` bridges only small App Group values.                                                                                                                                                                                                                                                                    |
| Mobile session credential                                            | [`expo-secure-store`](https://docs.expo.dev/versions/v57.0.0/sdk/securestore/) `~57.0.0`                                      | Planned, not installed. Add it only with the server-issued mobile-session flow; store the refresh/device secret in the iOS Keychain.                                                                                                                                                                                                                                                                          |
| Accepted in-screen motion                                            | [`react-native-reanimated`](https://docs.expo.dev/versions/v57.0.0/sdk/reanimated/) `4.5.0`                                   | Installed. Use for recording-state and small layout transitions with Reduced Motion support.                                                                                                                                                                                                                                                                                                                  |
| App icons                                                            | `lucide-react-native` `^1.24.0` through the RNR `Icon` adapter                                                                | Installed. Swift keyboard icons remain SF Symbols.                                                                                                                                                                                                                                                                                                                                                            |

Pipecat and ElevenLabs are not part of this dependency map. Both offer React Native conversational-agent SDKs, but their polished UI kits are web React/Tailwind or web shadcn components. TimberVox has a one-way provider-neutral dictation protocol and needs only a single streaming-text state surface. Reconsider either SDK only if a separately accepted two-way conversational-agent product is added.

## Visual contract

The app uses the iOS system typeface and a disciplined graphite surface hierarchy. The identity comes from the workflow, not a copied Superwhisper logo.

- Background: `background`
- Grouped surface: `card`
- Pressed/selected surface: `accent`
- Primary action: `primary`
- Recording/destructive: `destructive`
- Verified/ready: `success`
- Primary, secondary, and muted text use semantic foreground tokens.

The signature element is the **mode identity in the navigation header** paired with the recording control. The active mode's icon and name sit at the center top and open the mode picker. The app name does not occupy that premium position. Motion is limited to route transitions, sheet presentation, recording-state changes, and the swipe trail. Reduced Motion must be respected. There is no cross-fade that leaves a ghost of the prior screen.

## Navigation and page contracts

### Onboarding

Onboarding is a short, resumable checklist:

1. Microphone permission.
2. TimberVox keyboard installed.
3. Full Access enabled.
4. Shortcut/App Shortcut available.
5. One real test dictation completed.

Each row shows observed state, not an optimistic checkmark. The keyboard and Full Access states come from the extension's App Group evidence. The app can open its Settings page, but it cannot enable the keyboard or Full Access for the user.

### Record

- Active mode icon/name is the centered header control.
- The body shows one transcript surface and one current workflow state.
- The primary recording control stays reachable at the bottom of the working area.
- Partial text is shown only when the provider sends real partial text.
- No fake waveform. A level meter may be introduced only from real audio-metering values.
- The app recorder and external entry points use the same workflow service.

The state machine and visible contract are:

| State        | Meaning                                                                                              | Visible result                                                                                                                       | Next transitions                           |
| ------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| `idle`       | No background dictation session is running.                                                          | Start session/record control and any permission error.                                                                               | `ready`, `error`                           |
| `ready`      | Microphone permission and recording session are available; no executor is active.                    | Active mode and an empty live transcript surface.                                                                                    | `connecting`, `listening`, `idle`, `error` |
| `connecting` | A realtime request ID exists, its transport is handshaking, and initial PCM may be queued in memory. | The shared recording control shows amber `Connecting`; no invented transcript appears.                                               | `listening`, `finalizing`, `error`         |
| `listening`  | PCM is being captured for the selected batch or realtime executor.                                   | The shared control shows red `Stop`; genuine realtime partials render top-left when the selected route produces them.                | `finalizing`, `error`                      |
| `finalizing` | Capture has stopped and the selected executor is producing its canonical artifact.                   | The last genuine partial remains visible and the shared control shows purple `Processing`.                                           | `result`, `error`                          |
| `result`     | The canonical result was persisted and delivered for its entry point.                                | The shared control briefly shows green `Copied`; live text is cleared, History owns the durable text, then state returns to `ready`. | `ready`                                    |
| `error`      | Permission, authentication, transport, provider, or persistence failed.                              | Keep any recoverable text and show one concrete retry/recovery action.                                                               | Prior safe state or `idle`                 |

Partial text is never represented as chat bubbles and is not a durable artifact. Batch routes therefore show no simulated live text. Only the selected executor's canonical final response creates the Raw artifact. Segmented and Processed artifacts are saved only when those real outputs exist. Persistence precedes delivery; save and delivery failures retain recoverable state and have independent retry paths.

### Modes

- Modes is its own tab and list.
- A fresh install contains one active `Voice to Text` mode. Presets are templates offered during creation, not several pretend active modes.
- A sticky bottom action opens `modes/new`.
- Ten or more modes scroll normally beneath the action without fading into it.
- Selecting a mode opens its editor. A separate control marks it active.

The editor includes:

- Editable icon and name in the header.
- Short in-card description.
- Preset/template.
- Language derived from the selected transcription route's supported-language list.
- Transcription model from the Worker catalog.
- Realtime only when the selected route supports realtime.
- Identify speakers only when the selected route exposes that capability.
- Processing prompt/options when the preset uses AI post-processing.
- A bottom `Use mode` action.

There is no media-playback setting. TimberVox must not expose unsupported or automatic behavior as a choice.

Initial preset semantics:

- **Voice to Text** — Turn your voice into punctuated text with no AI post-processing.
- **Message** — Turn speech into a concise conversational message.
- **Mail** — Turn speech into a structured email while preserving the speaker's intent.
- **Note** — Organize dictated ideas into a readable note.
- **Meeting** — Reserved until meeting capture and final-transcript processing exist.
- **Custom** — User-supplied processing instructions.

Copy is editable product content, not provider terminology. Vocabulary and text replacements are omitted until those runtime features exist.

### History

- History is a list. Every item navigates to `history/[dictationId]`; list rows never expand inline.
- A row shows a real text excerpt and one metadata line: date/time, word count, and duration.
- Do not display `default keyboard`, destination-app identity, provider internals, or synthetic source labels.
- Public iOS keyboard APIs do not give the extension the destination app's bundle identifier. We can truthfully record `app`, `keyboard`, or `shortcut` as the TimberVox entry point, but not claim which app received the text.
- Search operates on stored transcript/artifact text.

The detail route:

- Puts transcript text directly on the screen instead of inside a decorative transcript card.
- Uses bottom artifact tabs only for artifacts that actually exist: `Raw`, `Segmented`, and `Processed`.
- Omits `Segmented` when timed segments are unavailable and `Processed` when the mode does no post-processing.
- Uses a real Expo Audio player state. Do not draw a fake waveform. Add a waveform only after real samples or precomputed peaks are persisted.
- Supports play/pause, elapsed/duration, share, delete, info, and reprocess when the required source audio still exists.
- Has no invented AI-summary panel. A generated title can be considered later as a separate accepted feature.

### Settings

Sections:

1. **Keyboard** — language, haptics, sound, predictive text, autocorrection, auto-capitalization, swipe trail, and a link to iPhone Settings.
2. **Dictation** — default/fallback behavior that is not mode-specific.
3. **Shortcuts** — open TimberVox App Shortcuts and optionally install the wrapper shortcut.
4. **Storage & privacy** — keep recordings, delete audio after a selected period, storage used, and clear recordings/history with confirmation.
5. **Account** — tappable TimberVox Pro/license row. Active is green only when a real entitlement is verified.
6. **Access status** — microphone, keyboard installed, Full Access, App Group/extension seen, and Shortcut readiness. This diagnostic section stays near the bottom after setup.
7. **About** — version/build and support/legal links.

### Account/license

The account row opens a real detail route with entitlement state, account identity when one exists, restore/manage subscription, and support/legal actions. No license key or API key is shown to the user. A green `Active` state must come from verified entitlement data, never a hard-coded prototype value.

## Data model and storage

### Storage in the current mobile spike

The current implementation already uses three distinct stores:

| Store                | Library and exact location                                                                                        | Data stored today                                                                                                                                                                  | Current limitation                                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| App database         | `expo-sqlite`, `timbervox-mobile.db`                                                                              | Versioned WAL-mode `modes`, `app_settings`, `dictations`, and `artifacts` tables. Legacy `dictation_history` rows migrate once into normalized Dictation and Raw Artifact records. | Migration and repository tests pass; a non-silent physical-device recording still needs acceptance.             |
| Persistent files     | `expo-file-system`, `Paths.document/recordings/*.wav`                                                             | Final 16 kHz mono linear-PCM WAV assembled from captured realtime chunks, plus file size/format on the Dictation. Deleting History or audio retention removes the referenced file. | Audio chunks remain in memory until a terminal outcome; crash-resumable in-progress capture is not implemented. |
| Cross-process bridge | `@bacons/apple-targets` `ExtensionStorage` and Swift `UserDefaults(suiteName: "group.com.chiejimofor.timbervox")` | Schema v2 keyboard/access facts, active mode and preferences, request ownership, partial text, durable result ID, and consumed result ID.                                          | Source and contract tests pass; a signed physical-device keyboard round trip still needs acceptance.            |

The realtime WebSocket, queued PCM, captured PCM, and partial accumulator are memory-only. The current static Worker credential comes from Expo config and is embedded in the build; it is not protected storage.

### Target storage contract

SQLite remains authoritative for structured product data. Audio and generated files live in the document directory. App Group `UserDefaults` contains only small cross-process facts and handoff identifiers. The server-issued mobile credential lives separately in `expo-secure-store`/iOS Keychain.

Core records:

```text
Mode
  id, name, iconKey, description, presetKind, language
  asrModelId, realtimeEnabled, identifySpeakers
  processingModelId?, processingInstructions?, isActive
  createdAt, updatedAt

Dictation
  id, createdAt, startedAt, endedAt, durationMs, wordCount
  modeId, entryPoint(app|keyboard|shortcut)
  status, asrModelId, language, audioUri?, error?

Artifact
  id, dictationId, kind(raw|segmented|processed)
  text, timingJson?, modelId?, createdAt

AppSetting
  key, valueJson, updatedAt
```

The database also has an explicit schema-migrations table, WAL mode, foreign keys, and repository-level transactions. `Raw` means the canonical final ASR transcript. `Segmented` means a real timed-segment/word representation from a route that returns timing. `Processed` means the optional post-processing result created by the selected mode.

App Group bridge facts are versioned and namespaced. At minimum: schema version, keyboard seen, Full Access observed, active mode ID, recording state, request ID/revision, partial text, final result ID, transcript revision, and the keyboard-specific preferences that the extension consumes. Large audio, durable history, and credentials do not belong in `UserDefaults`.

Retention is enforced by one storage service used after recording, on app launch, and after settings changes. Deleting audio does not silently delete transcript artifacts unless the user chooses to clear history.

## Runtime ownership

| Responsibility                                                        | Owner                                                         |
| --------------------------------------------------------------------- | ------------------------------------------------------------- |
| Routes, screen UI, mode editing, history browsing, settings           | Expo Router + React Native                                    |
| Reusable app primitives                                               | React Native Reusables owned in `src/components/ui`           |
| Modes/history metadata                                                | Expo SQLite repositories                                      |
| Persistent audio/artifacts                                            | Expo FileSystem document storage                              |
| Voice catalog and capability truth                                    | Peacockery Voice                                              |
| Keyboard rendering, swipe trace/decoding, predictions, text insertion | Swift keyboard target                                         |
| Cross-process state                                                   | Versioned App Group bridge                                    |
| Shortcut/Action button entry                                          | Swift App Intent                                              |
| Recording indicator and system lifetime                               | ActivityKit Live Activity                                     |
| Credentials                                                           | Server-issued session + iOS secure storage; never Expo config |

### Native recording decision gate

The current Expo `AudioStream` can capture realtime PCM and Expo supports background recording after the proper config/runtime flags. That proves the in-app path, not cold App Intent execution.

Before building the final recorder, make a minimal signed physical-iPhone spike that records:

- Which bundle/process executes `perform()`.
- Whether the host Expo process and JavaScript runtime initialize without opening UI.
- Whether `AudioStream` starts and continues while the Live Activity is active.
- Whether a second intent invocation can finalize the same session and return text.
- Behavior with the app force-quit, suspended, screen locked, and network interrupted.

If the JavaScript runtime is reliably alive, keep capture and the Worker client in TypeScript behind a native intent bridge. If it is not, move only capture/realtime transport into a native Expo module/Swift coordinator and keep product state, screens, modes, history, and settings in Expo. Do not duplicate both implementations before this gate is answered.

## API and authentication

The Worker model catalog remains authoritative. The mobile app does not hard-code a model/language matrix.

Before TestFlight:

- Remove `peacockeryVoiceApiKey` from Expo config and delete the build-embedded credential path.
- Add an app-to-Worker authentication flow that mints a revocable, scoped session for an installation/account.
- Store the mobile session in iOS secure storage and refresh it through the API client.
- Authorize realtime, transcription, transforms, catalog, history/usage, and upload routes consistently.
- Rate-limit and account usage by authenticated user/installation.

The current static bearer path may be used only for local development while this is implemented. It is not TestFlight-ready.

## Build and validation lanes

### Web development lane

Use Expo web for fast work on RNR primitives, spacing, route composition, empty/loading/error/populated states, and responsive width. Web approval never proves keyboard, microphone, App Group, native navigation, permissions, Shortcut, or background behavior.

### iPhone Simulator lane

Use an iPhone simulator, never an iPad simulator, for:

- Navigation and form-sheet behavior.
- SQLite migrations and persistence.
- Mode CRUD and active-mode behavior.
- History list/detail/artifact tabs.
- Light/dark appearance, Dynamic Type, VoiceOver labels, and reduced motion.
- Regenerated native project build after configuration changes.

The simulator is insufficient for the end-to-end recording/keyboard/system-entry contract.

### Physical iPhone lane

A signed development/TestFlight build must prove:

- Microphone permission, denial, revocation, interruption, and input changes.
- Keyboard installation and observed Full Access.
- Tap typing, swipe trail, decoder quality, predictions, globe key, secure-field fallback, and text insertion.
- App Group handoff while the host app is foreground, background, suspended, and relaunched.
- App Intent start/stop, Live Activity lifetime, Action button/Shortcuts invocation, returned transcript, clipboard wrapper, and no unwanted foreground switch.
- Realtime partial/final text and recovery after network interruption.
- Audio retention and deletion on a real device.

### Per-slice acceptance loop

Every feature slice follows the same sequence:

1. Define the visible states and real data source.
2. Build the RNR/route composition against fixtures on web.
3. Connect the repository/service path.
4. Add route/component/repository tests outside `src/app`.
5. Verify on an iPhone simulator.
6. Run the physical-iPhone lane when the slice crosses a native boundary.
7. Update `docs/TODO.md` with literal state: designed, implemented, simulator-verified, physical-device-verified, or TestFlight-uploaded.

## Rebuild order

1. **Safe foundation reset** — preserve native/runtime experiments, remove starter/demo files, set `supportsTablet: false`, install/configure RNR manually, establish tokens, tabs, route groups, error boundary, and test harness.
2. **Mode domain** — SQLite schema/repository, default Voice to Text mode, preset templates, list/new/editor, active mode, catalog/capability integration.
3. **History domain** — normalized dictation/artifact schema, list/detail routes, search, actual playback, retention and deletion.
4. **Record screen** — one workflow interface, real states, mode-aware request construction, in-app realtime recording.
5. **Keyboard contract** — versioned App Group bridge, mode-aware requests, swipe quality baseline, settings synchronization, insertion acceptance.
6. **Native intent spike** — `AudioRecordingIntent`, Live Activity target, exact shared Shortcut contract, physical-device decision gate.
7. **Final recorder ownership** — keep TypeScript or move the minimal necessary capture/transport code to Swift based on evidence.
8. **Mobile authentication** — server-issued session, secure storage, remove embedded credential.
9. **Onboarding/settings/account** — observed permissions, Shortcut link, storage/privacy, real entitlement display.
10. **TestFlight** — regenerate native project, signing/entitlements, release build, upload, install, and complete the physical-iPhone matrix.

## Safe cleanup boundary

Delete or replace:

- Expo/React starter images, tutorial assets, demo components, CSS-module demo animation, and the generic `reset-project.js`.
- The discarded `ui-prototype` after its accepted product decisions are represented here.
- Generated `.expo`, `ios`, Pods, Metro, and build caches when resetting the native build.
- Current one-off screen styling as each route is rebuilt with RNR.

Preserve until deliberately superseded and accepted:

- `targets/keyboard` and its signing/App Group configuration.
- The App Group bridge keys long enough to migrate them to a versioned contract.
- The realtime Worker protocol parser/client behavior.
- SQLite/WAV persistence behavior and real recorded fixtures.
- User or agent changes outside the mobile rebuild.

Never run the current generic reset script. It deletes the entire source directory and then creates a blank starter without understanding the keyboard, App Group, history database, or realtime workflow.

## References

- [Apple AudioRecordingIntent](https://developer.apple.com/documentation/appintents/audiorecordingintent)
- [Apple LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent)
- [Apple App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts)
- [React Native Reusables installation](https://reactnativereusables.com/docs/installation)
- [Expo Router SDK 57](https://docs.expo.dev/versions/v57.0.0/sdk/router/)
- [Expo Router testing](https://docs.expo.dev/router/reference/testing/)
- [Expo Audio SDK 57](https://docs.expo.dev/versions/v57.0.0/sdk/audio/)
- [Pipecat React Native SDK](https://docs.pipecat.ai/client/react-native/api-reference)
- [Pipecat Voice UI Kit](https://github.com/pipecat-ai/voice-ui-kit)
- [ElevenLabs React Native SDK](https://elevenlabs.io/docs/eleven-agents/libraries/react-native)
- [ElevenLabs Expo React Native guide](https://elevenlabs.io/docs/eleven-agents/guides/integrations/expo-react-native)
