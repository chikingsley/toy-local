# Agent TODO — Claude's working file

NOTE (2026-07-04): the MASTER PLAN moved to docs/TODO.md — rules, gates,
port order, wiring matrix, testing program. This file is session scratch /
history only. Read docs/TODO.md first.

Operating rules: I (Claude) own this file and `docs/app-organization.md`.
This file tracks what I'm actively doing and what's queued, so Chi can see
state at a glance. The root `TODO.md` is the project's own roadmap — I read
it but don't write it. Decisions get logged here when made; specs live in
`app-organization.md`.

## Now

- **Recording surfaces: spec-first now.** `docs/recorders/recording-surfaces.md`
  holds the AGREED state model (off / red recording — streaming is still red /
  blue processing / green hot mic / orange flash for dump) + mini-pill
  hover-expand behavior (superwhisper reference screenshots in same folder).
  Captioning = separate top-of-screen surface, NOT a state. The recorder
  prototypes are currently on the OLD (wrong) state model — do not iterate
  them further until reworked against the spec, and ask Chi on anything the
  spec leaves open (its Open Questions list). Chi: stop inferring; examples
  over abstractions; get sign-off before building.

- **Next: Modes v0** (pulled forward 2026-07-03 — Chi: "there's no modes,
  which is an issue"). Shape per spec §Modes: Modes tab in sidebar (Library
  group), list view with the single Default mode (migrated view of today's
  globals), detail view = preset picker + custom-prompt editor + context
  toggles (relocated from Transforms' Text Transform group) + voice model +
  language. Per-mode hotkey dispatch and multi-mode CRUD come later.
- Polish round done 2026-07-03 (Chi's build feedback): mirrored pane titles
  removed (`.toolbar(removing: .title)` — header now free for per-pane
  search later), zoom/maximize button disabled, previews backfilled on ALL
  section views (every view file now has one). Verified via render.
- Chi saw two menu bar items, one with Copy Last Transcript grayed —
  diagnosis: two app instances running (old install + fresh debug build),
  not a bug. Flagged to Chi.

## Queue (from app-organization.md § Implementation order)

- [x] **Step 1 — Container swap + pane split** (done 2026-07-03; builds
      clean, AppView preview rendered and verified)
      TabView + sidebarAdaptable in AppFeature.swift; new panes: GeneralPane,
      ShortcutsPane (owns PasteLastTranscriptHotkeyRow), RecordingPane (owns
      moved behavior rows), ModelsPane, HistoryPane (gear popover — Step 3
      done early). SettingsView.swift deleted; shared preview mock world in
      Features/App/PreviewSupport.swift (AppPreviewState). ActiveTab: 7
      cases, default .general; model-missing flash routes to .models;
      History "enable" button now toggles the setting directly. Window:
      .resizable, contentMinSize 640×520, setFrameAutosaveName.
      NOTE: Inject/hot-reload was removed from the project in Chi's other
      session — previews are now the only live-viewing loop; pane previews
      come with Step 1.5.
      Still to verify: real-app pass (open window from menu bar, click all
      tabs with real data, resize, popover).
- [x] **Step 1.5 — Folder reorg + UI/ promotion** (done 2026-07-03; build
      green, ShortcutsPane + HistoryPane previews rendered and verified)
      UI/ holds HotKeyView, StarRatingView, AutoDownloadBannerView,
      SettingsStyles. Per-pane folders under Features/Settings/;
      Remappings → Transforms; HistorySectionView → Features/History/.
      All 7 page-level views have #Preview via AppPreviewState.makeStore()
      (now seeds 3 fake transcripts; preview saves go to temp dir by
      existing SettingsManager guard). Decision: skipped PreviewModifier —
      views take explicit store params, so a factory fn is simpler; revisit
      only if stores move into Environment. Section-level views don't have
      individual previews (covered by pane previews) — acceptable deviation
      from the every-file rule.
- [ ] **Step 2 — Quick wires**
      Language picker → Models pane; always-on paste/dump hotkey recorders →
      Shortcuts pane (fields exist: `alwaysOnPasteHotkey`/`alwaysOnDumpHotkey`);
      always-on streaming model picker → Models pane.
- [ ] **Step 3 — History gear popover** (save toggle + max entries move in;
      settings section deleted)
- [ ] **Step 4 — Permissions → onboarding** + General status row
- [ ] **Step 5 — Home v1** — stats strip from history data, typing-test
      sheet, quick actions, What's New from CHANGELOG.md
- [ ] **Modes v0 (pulled forward — next)** — Modes tab + list/detail UI over
      today's globals as the Default mode; Text Transform group relocates
      here from Transforms. No new persistence yet.
- [ ] **Step 6 — Modes v1** — `Mode` model in Core, multi-mode CRUD,
      per-mode hotkey dispatch, per-app activation
- [ ] **Step 7 — Dictionary reorg** — rename tab, Vocabulary section,
      entry provenance fields (prepares correction loop)

## Later projects (own specs when reached)

- Correction loop: alignment diff, recurrence counts, proposal inbox
  (blueprint: superwhisper-api/macwhisper — LLM-in-the-loop, human-gated)
- Auto context profiles (capture layer exists: DictationContextCaptureService)
- Voice commands via dormant FluidAudioKeywordSpottingClient
- Cloud auth: Keychain + license activation (server endpoints already exist)
- Omni ASR support (not in FluidAudio; upstream or own conversion)

## Prototype track (2026-07-03, active)

Sandbox: `TimberVox/Prototype/` (SwiftLint-excluded; also excluded Chi's
`TimberVoxBackendPrototype` package — sandboxes don't fight the linter).
Chrome research verdict (3-agent, sourced): Superwhisper = delegate-owned
NSWindow + NSHostingView + hand-rolled HStack sidebar + content-owned
TopBar; transparent titlebar, hidden title, no NSToolbar, no zoom button.
TabView.sidebarAdaptable CANNOT be made seamless (toggle unmovable) —
container will be replaced at port time with the custom split.

Locked design decisions from Chi's prototype review:
- Modes: list → separate DETAIL PAGE (not inline). "Activate" (one active
  mode at a time), not enable/disable or set-default. Mode Switcher HUD +
  "Change Mode" shortcut cycles modes. In mode detail: ONE voice-model
  picker; realtime/diarization etc. are per-mode option toggles gated by
  the chosen model's capabilities.
- Models: LIBRARY concept — capability chips (Local/Cloud · Batch/Realtime
  · Text · Diarization), one entry per model (Scribe v2 = one row, two
  capability chips), no Output Language here (per-mode), no lone text-model
  row. Selection happens in Modes; library shows "Used by" + disk state.
- Shortcuts: NO exposed knobs (modifier-side, double-tap, min-hold all cut —
  engine auto-detects exact key incl. left/right side; double-tap implicit).
  Three peer talk behaviors: Push to Talk / Toggle Recording / Hot Mic
  (+paste/dump keys), plus Change Mode + Paste Last Transcript + per-mode
  list. Chord sequences (⌘Z then D) = future engine work, UI unaffected.
- History: card → full DETAIL PAGE: Raw/Modified tabs, playback, metadata,
  ARCHIVED mode snapshot (survives mode deletion; includes prompt),
  captured-context section (app/screen/selection/clipboard incl. images).
  App filter: top-4 chips + "⋯" overflow menu (25-apps problem).
- Recording pane: input source/device/level meter, feedback sounds, media
  behavior, prevent sleep, hot-mic status. General: login/dock, output
  defaults (modes can override), permissions pills, updates.

Round 3 decisions (Chi review, 2026-07-03 afternoon):
- Headers are PAGE-OWNED (ProtoHeader component, hairline separator kept):
  no global mic/collapse row repeated everywhere; collapse floats top-left;
  mode-switch pill in Home header; mic picker moves to Recording header;
  search lives in each searchable pane's header (⌘F focuses at port time).
- De-stuffing idiom: one-line rows + ProtoInfoHint ⓘ popovers instead of
  subtitle captions; "Advanced" collapsed section on mode detail.
- Modes: name editable IN the header (Superwhisper-style), preset icon
  beside name changes with preset (Super=sparkles+Recommended tag in menu),
  language FIRST (Automatic default) and models filter by language;
  per-mode Audio section (playback-while-recording, system audio) moved
  from Recording; autocapitalize-insert in Advanced. Text models menu uses
  real API catalog (anthropic/openai/google/mistral/groq/cerebras/deepseek/
  zai — checked TimberVoxCloudflareApi/src/ai/model-routes.ts).
- Models: Voice/Text scope segments, Offline|Cloud badges, plain-language
  capability lines (no "Batch"), local vs cloud = separate entries
  (Scribe v2 and Scribe v2 Realtime split).
- History: search+date filter in header; ~2 days then "Show more history";
  detail = transcript first, one-line meta, Raw/Modified below transcript
  (hidden entirely for voice-to-text modes), context items collapsed by
  default, multi-item clipboard mock.
- Shortcuts: hot-mic paste/dump nested under Hot Mic row (no separate
  section).
- General additions: Show in Menu Bar; Text Insertion section (paste result,
  hold-⇧-to-send, clipboard behavior Default/Restore/Bypass incl. Maccy/
  Alfred/Raycast bypass, simulate-key-presses experimental); Performance
  (keep-model-loaded duration menu); Storage (app folder + Change).
- Recording slims: mic picker in header, level meter, feedback, prevent
  sleep; hot-mic status card removed; audio behavior gone (per-mode).

Recording-window research findings (all three agents done, 2026-07-03):
- Superwhisper teardown: recorder HUD = DynamicRecorderPanel, draggable with
  spring physics (vendored CocoaSprings, display-link → destinationPoint),
  SNAP-POINT docking (SnapIndicatorWindow shows targets while dragging,
  snapPointID persisted), "mini recorder" pinned mode. Streaming text =
  ChatSurfacePanel, a separate panel KVO-GLUED TO THE FOCUSED APP WINDOW
  (measures off-screen, fades in, follows move/resize, high-water height).
  Waveform rendered as HTML in WKWebView(!). ZERO notch handling. Their
  caret-AX code exists only for AgentInlineDictation (inline re-anchoring).
- Notch: VoiceInk (MIT, open source) is the exact reference — wings +90pt
  recording / +110pt streaming, 57pt transcript panel below, NotchShape
  (top corners curve outward; closed 8/16, open 12/22), springs .42/.80 in,
  .45/1.0 out, 15-bar center-weighted waveform. NSScreen safeAreaInsets +
  auxiliaryTop*Area APIs; standard panel recipe documented. Source excerpts
  in session scratchpad (vi-*, bn-*, dnk-*, notchdrop-*).
- Caret anchoring: AX recipe confirmed (focused element → selectedTextRange
  → AXBoundsForRange); Chrome needs text-marker variant, Electron needs
  AXManualAccessibility poke, fallback chain = caret → field frame → mouse.
  Best reference: xkey FloatingToolbarPositioning (center-x, 4-8pt above,
  flip at screen top). Apple Dictation is the only caret-anchored recorder
  precedent; Wispr Flow (fixed pill) is disliked → differentiation room.
- Sandbox build DONE (builds green, 7.8s incremental): 
  PrototypeRecordingStage.swift (fake desktop stage, variant + state
  pickers) + fleshed variants: NotchRecorderMock (VoiceInk fidelity,
  ProtoNotchShape), CaretPillMock (ghost-text ticker + caret tail),
  WindowSurfaceMock (high-water streaming surface), SnapCapsuleMock
  (capsule idiom + grip, snap notes), CursorTagMock. Port-time notes live
  in each file's header comments. Awaiting Chi's review in canvas.

Recording-window track (started 2026-07-03 evening):
- Goal: design the live dictation feedback surface(s). Candidate anchors,
  per Chi: (a) caret-anchored — pill directly ABOVE the text cursor in the
  focused input (not a separate input UI); (b) cursor-follower — element
  attached to / transforming the pointer; (c) notch — waveform beside the
  notch, streaming text below it; (d) larger floating window (Superwhisper
  classic). Streaming-text rendering is a related-but-separate question.
- 3 research agents out: notch HUD ecosystem (boring.notch etc. + NSScreen
  auxiliary APIs), caret-position-via-AX + cursor-follower recipes, and
  superwhisper binary teardown of recorder windows (DynamicRecorderPanel,
  ChatSurfacePanel, CocoaSprings SpringMotion* — classes found earlier).
- Next: prototype all variants as reactive mock surfaces in the sandbox.
- NOTE: other sessions added parallel prototype tabs (Configuration V2,
  Modes V2, History V2, Shortcuts V2, Hot Mic, Sound) + refactored
  ProtoHeader (control enum + environment sidebar toggle). Don't clobber;
  V2-vs-V3 pane reconciliation is Chi's call later.
- Build-speed fixes: SWIFT_EMIT_LOC_STRINGS=NO (Debug),
  STRING_CATALOG_GENERATE_SYMBOLS=NO (Debug — the "generating comments"
  step; symbols unused in code). App Intents metadata scan has no off
  switch but is cached per package.

Prototype consolidation pass (2026-07-04, done — Claude + Chi in parallel):
- Structure: Prototype/{UI, Panes, Recorders} + Shell/ModeSwitcher at root.
  UI/ = ONE COMPONENT PER FILE (Chi's rule; the old monolithic
  PrototypeComponents.swift is deleted). Tokens in UI/ProtoTheme.swift now
  include surfaces (cardSurface/chipSurface/fieldSurface/hairline/
  selectionFill/hoverFill/borderStroke + radii) — no new .white.opacity
  literals in panes.
- One ProtoDivider (inset both sides, leadingInset param) replaced 8 forks;
  Dictionary/Models full-bleed separators fixed; Sound's missing
  sound-effects divider added.
- ProtoToggleRow now takes @Binding + hint + showsAI (was dead code);
  ProtoSearchField extracted (6 copies); ProtoSection gained hint slot
  (Dictionary's HintedSection fork deleted). ProtoKeycap +
  ProtoShortcutRecorder (pulsing chip, click-away/Escape cancel) shared by
  Shortcuts V2 + Hot Mic + Modes detail; Chi's ProtoShortcutRecorderControl
  merged into it. ProtoSettingsRow family (Chi's extraction) kept for
  settings-style detail rows.
- One ProtoProvider registry + ProtoProviderLogo (Models' tinted-mask
  rendering won; the two divergent color tables unified). Logos are
  template SVGs in Assets.xcassets (provider-*; Cohere original-color,
  Superwhisper PNG, Mistral drawn bars); appearance-* thumbnails also moved
  to the catalog. All #filePath runtime loading deleted.
- General pane DELETED — Config V2 absorbed Permissions + Updates sections.
  Models pane: LibraryModelRow/SupportModelRow merged (shared
  ModelDownloadControl, reused by Modes' model picker). History: dead
  TranscriptionDetailV2 removed, Raw/Processed picker default fixed, routes
  by ID. Home: tuples → Identifiable, URL intake on ProtoSearchField.
- Verified: swift format lint clean, Debug xcodebuild green (SwiftLint
  build phase passes), app unit tests green. Conventions documented in
  Prototype/README.md. Not committed.
- Open: recorders keep local PulsingRecordDot/word-reveal duplicates
  (candidates for ProtoPulsingDot adoption at port time);
  historyAccentGreenV2 == activeGreenV2 duplicate constant.

Repair round (2026-07-04, after Chi's review — the consolidation pass had
standardized on the WRONG reference):
- Canonical settings design = Chi's ProtoSettingsRow + ProtoOptionMenu +
  superwhisper-ui-clone (~/GitHub/superwhisper-api/superwhisper-ui-clone,
  src/components/primitives/settings.tsx): rows 16pt insets / 44-52pt
  min-height / trailing right-justified; separators inset 16; dropdowns are
  ProtoOptionMenu popover pills, NOT system Menu/Picker. Home-style compact
  rows (12pt) are for list content only, never settings panes.
- Config/Sound/HotMic rebuilt on ProtoSettingsRow + new shared
  ProtoSettingsToggleRow; all system Menu/Picker dropdowns → ProtoOptionMenu.
  Compact ProtoToggleRow deleted (orphaned).
- Shortcuts pane merged INTO Configuration (interactive ProtoShortcutRecorder
  rows + click-away/Escape cancel; per-mode shortcut rows dropped — they
  live on the mode detail page). "V2" removed from all sidebar labels.
- Agent Plugins rows now use the real agent logos (agent-claudecode/
  opencode/codex imagesets copied from the ui-clone), logo + Install button
  right-justified, matching the clone's AgentRow.
- ProtoKbd renamed ProtoKeyChip (Kbd was opaque). Mode Switcher HUD restyled
  to Superwhisper's: dark panel, bar rows, checkmark on active mode, number
  chips, footer ↑↓ / Select ⏎ / Back ^.
- ROOT CAUSE of "popovers gone" (two layers, both needed):
  1. Popovers render through ProtoFloatingHost, which only the Shell
     provided — standalone pane previews had no floating layer. All pane
     #Previews now wrap in ProtoFloatingHost. Keep doing this for new panes.
  2. THE REAL KILLER: the anchor plumbing used GeometryReader + preference
     key + onPreferenceChange, whose delivery is unreliable under Swift 6 /
     current SDK — anchors stayed .zero, so present() silently bailed on its
     `anchorFrame != .zero` guard and NO popover opened anywhere (clicks
     "did nothing"). Fix: `protoFloatingAnchor` and the host's panel-size
     measurement now use `onGeometryChange` (same API family as the working
     scroll pill). Verified by the "Floating layer smoke test" #Preview in
     UI/ProtoFloatingLayer.swift, which renders with a popover ALREADY OPEN
     plus ✅ diagnostics — if that snapshot shows the panel, popovers work.
     RULE: never use GeometryReader+preference for new geometry plumbing in
     the prototype; use onGeometryChange / onScrollGeometryChange.
  Also: ProtoMenuOption/ProtoOptionMenu are Sendable (static option tables
  in panes compile under strict concurrency); shortcut recorder contract =
  keycaps are the record hitbox, rewind resets to default, click-away/Esc
  cancels; clone hint texts + dropdown options ported verbatim from
  superwhisper-ui-clone (Sound playback = Pause/Lower volume/Do nothing).

## Decisions log

- 2026-07-03 · Demoted StarRatingView + AutoDownloadBannerView back to
  ModelDownload/ — each has exactly one consumer; the 2+ rule is enforced by
  grep, not intention. UI/ holds only HotKeyView + SettingsStyles for now.
- 2026-07-03 · Rejected sindresorhus/KeyboardShortcuts as hotkey engine:
  built around key+modifier shortcuts; modifier-only support was disabled in
  the lib after macOS 15.0/15.1 broke Option-only hotkeys, and it can't do
  left/right-side modifiers or double-tap. TimberVox's push-to-talk (hold ⌥,
  sides, double-tap-lock, min-hold) needs the existing event-tap engine.
  HotKeyView stays the single shared recorder/renderer UI.

- 2026-07-03 · Container = `TabView` + `.sidebarAdaptable`, not
  NavigationSplitView. System-owned sidebar, less code; NSV is the fallback
  if 15.x glitches. (Chi: "boring, newest, just works.")
- 2026-07-03 · Keep delegate-owned NSWindow — correct for MenuBarExtra apps
  on Tahoe (openSettings/scene routes are fragile there); fix styleMask
  in place.
- 2026-07-03 · No more overview artifacts; specs live in docs/, discussion
  in chat, promote to spec when agreed.
- 2026-07-03 · Hex audit done: repo clean; upstream git remote + MIT
  copyright line are the only (intentional) traces.

## Open questions (Chi's call, non-blocking)

- History context retention: keep captured context per entry? (lean:
  30 days then auto-delete)
- Correction-loop ground truth: own Workers API only, or also a local
  big-model option?
- Background-loop aggressiveness: proposed conservative defaults (recent-N,
  mains power, daily cap, human-gated) — tune after v1
