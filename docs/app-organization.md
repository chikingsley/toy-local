# TimberVox — App Organization Spec

The concrete layout: every page, what's on it, and where every existing control moves.
Status: agreed direction, not yet implemented. Implementation order at the bottom.

## Window structure

One main window. The container is a `TabView` — four layers, outermost in:

1. **`TabView(selection:)`** owns "which page is the user on" and holds one
   `Tab` per destination. Each tab keeps its own state when switched away.
2. **`.tabViewStyle(.sidebarAdaptable)`** renders the tab picker as a
   system-styled macOS sidebar (that's all it does here; "adaptable" refers
   to per-platform rendering, not resizing). We never hand-build the sidebar.
3. **`TabSection("Settings")`** groups the settings panes under a sidebar
   header. Top-level tabs above it stay ungrouped.
4. **`NavigationStack` inside each tab** provides drill-in navigation
   (Modes list → detail) and hosts that pane's toolbar items (History's
   search + Delete All appear in the window toolbar only while History is
   active). Panes without drill-in still get a stack for title/toolbar.

The sidebar replaces today's 4 flat tabs (Settings / Transforms / History /
About) with:

```
Home
Modes
Dictionary
History
─ Settings ─────────
General
Shortcuts
Recording
Models
About
```

The floating capsule indicator and menu bar item stay as they are, with one
menu bar addition: a "Start Recording" item above "Copy Last Transcript".

Permissions leave the settings form entirely: first-run onboarding flow +
a status row at the bottom of General (with Grant buttons when something is
missing, collapsed to one green line when not).

---

## Home

Top to bottom:

1. **Stats strip** — four tiles computed from the history store:
   - Words (total words across transcripts)
   - Dictation speed (words ÷ recorded duration, WPM)
   - Apps used (distinct `sourceAppBundleID`s)
   - Time saved (words ÷ typing WPM − dictation time); gear icon opens the
     typing-test sheet that measures typing WPM (stored in settings,
     re-testable anytime)
2. **Proposal inbox** — hidden until the correction loop exists (Phase 2).
   Then: pending dictionary corrections with approve/dismiss.
3. **Quick actions** — Start recording (shows current hotkey), Create a mode,
   Open dictionary, Set shortcuts. Each navigates or acts.
4. **What's New** — feed parsed from `CHANGELOG.md` (already bundled; reuses
   the ChangelogView markdown rendering, presented as a dated list).

## Modes

List → detail, like Superwhisper. Absorbs the "Text Transform" GroupBox that
currently lives in the Transforms tab.

**List:** one row per mode (name, preset icon, voice model, active dot),
"+ Create Mode". Ships with one default mode migrated from current global
settings.

**Detail (one mode):**
- Name
- Preset: Voice to Text / Super / Message / Mail / Note / Meeting Summary / Custom
  (these are the existing `TextTransformMode` cases — already implemented)
- Custom instructions `TextEditor` (Custom preset only — exists today)
- Voice model (from the model catalog; today's global `selectedModel`)
- Text model (cloud model string — today's global `textTransformModel`)
- Language (today's orphaned `LanguageSectionView` picker, per-mode)
- Context toggles: App + screen / Selection / Clipboard (exist today as
  globals in Transforms)
- Mode hotkey (optional, `HotKeyView` recorder): pressing it records in this mode
- Activate for apps (later phase — per-app auto-activation)
- Output: auto-paste vs clipboard-insert (today's two clipboard toggles in
  General move here, per-mode with global default)

**Data model:** a `Mode` struct in TimberVoxCore holding what are currently
globals; `TimberVoxSettings` keeps `modes: [Mode]` + `defaultModeID`.

## Dictionary

Renames/absorbs the rest of the Transforms tab. One library, three sections:

- **Replacements** — today's Word Remappings table (match → replace, enable, delete)
- **Removals** — today's Word Removals regex table (incl. filler-word defaults)
- **Vocabulary** — new: plain list of terms/proper nouns; sent as `vocabulary[]`
  bias to cloud models; used as spelling context in transform prompts for
  local models
- **Scratchpad tester** stays (top of page): type a phrase, see the result
  after removals + replacements

Later (Phase 2): each entry gets a source badge (manual / learned) and hit
count; a "Learn from recent dictations" button starts the correction loop.

## History

The list stays as-is. Changes:
- Toolbar gains a **gear popover** holding what is today the Settings›History
  section: Save Transcription History toggle, Maximum Entries picker.
  (One "History" in the app, not two.)
- Search field in the toolbar (matches text).
- Per-entry context disclosure (captured app/selection/clipboard) — later,
  pending the cute-vs-useful decision.

## Settings panes

### General
- Open on Login, Show Dock Icon (unchanged)
- Default output behavior: "Use clipboard to insert", "Copy to clipboard"
  (until Modes ships; then these become the default mode's output settings
  and this section becomes "Defaults")
- Permissions status row (see above)

### Shortcuts
Every hotkey in the app, grouped:
- **Push to talk** — recording hotkey capture + modifier-side pickers +
  "Use double-tap only" + minimum key time (today's Hot Key section, whole)
- **Always-On** — Paste hotkey, Dump hotkey — *editable recorders*
  (today: display-only text in the Always-On section; the settings fields
  `alwaysOnPasteHotkey` / `alwaysOnDumpHotkey` already exist)
- **History** — Paste Last Transcript hotkey (moves out of the History section)
- **Modes** — per-mode hotkeys listed read-only with jump links (once Modes ship)

### Recording
Everything about the act of recording:
- Recording Source (Microphone / System Audio) + Input Device + refresh
  (today's Recording Input section, whole)
- Sound Effects toggle + volume (today's Sound section)
- Audio Behavior while Recording (Pause Media / Mute / Nothing — from General)
- Prevent System Sleep while Recording (from General)
- **Always-On block**: Enable toggle + model/status readout + explanation
  (today's Always-On section minus the hotkey rows, which go to Shortcuts)

### Models
- Curated model list (today's Transcription Model section, whole)
- **Always-on streaming model picker** — new; the setting
  (`alwaysOnStreamingModel`) exists but has no UI today
- Output Language (the orphaned `LanguageSectionView` — wire it here as the
  global default; Modes override per-mode later)

### About
Unchanged: version + Check for Updates, Show Changelog, GitHub link.

---

## Where every current control lands (delta only)

| Today | Destination |
|---|---|
| Permissions section (top of Settings) | Onboarding + General status row |
| Transcription Model section | Models |
| Hot Key section | Shortcuts › Push to talk |
| Always-On section: enable/status | Recording › Always-On |
| Always-On section: paste/dump hotkey rows | Shortcuts › Always-On (now editable) |
| Recording Input section | Recording |
| Sound section | Recording |
| General: clipboard toggles | General › Defaults (→ Modes output later) |
| General: audio behavior, prevent sleep | Recording |
| General: login, dock icon | General (stays) |
| History section: save toggle, max entries | History toolbar gear |
| History section: paste-last hotkey | Shortcuts › History |
| Transforms: Text Transform GroupBox | Modes (default mode's config) |
| Transforms: Removals/Remappings/Scratchpad | Dictionary |
| (orphaned) LanguageSectionView | Models › Output Language |

## SwiftUI integration notes

Validated against Apple docs + current macOS 26 (Tahoe) field reports, 2026-07.

- **Window: keep the delegate-owned NSWindow — this is the correct
  architecture for a MenuBarExtra app, not a legacy shortcut.** Pure
  SwiftUI window scenes are known-broken for accessory/menu-bar apps on
  Tahoe (`openSettings` needs an existing SwiftUI render tree; workarounds
  involve hidden windows, activation-policy flips, timing delays, and an
  undocumented scene-declaration-order dependency — see steipete's
  "Showing Settings from macOS Menu Bar Items"). TimberVox's
  NSWindow + NSHostingView + explicit `NSApp.activate` flow sidesteps all
  of that. Fix it in place:
  - add `.resizable` to the styleMask (this alone is why it can't resize)
  - `contentMinSize` ≈ 640×520
  - `setFrameAutosaveName("main")` — persists size/position across launches
    (the NSWindow equivalent of scene state restoration)
  - keep `isReleasedWhenClosed = false`
- **Sidebar container: `TabView` + `.tabViewStyle(.sidebarAdaptable)`**
  (macOS 15+). Destinations are declared as `Tab("…", systemImage:, value:)`
  with `TabSection("Settings")` for the settings group; the SYSTEM renders
  the sidebar (rows, selection, headers, insets, Liquid Glass on 26) —
  correct by construction, which deletes the current styling bugs
  (Button-wrapped rows, lost top inset) as a class. `NavigationStack` inside
  each tab gives per-pane toolbars (History: search + Delete All; Modes:
  drill-in detail). Extras if wanted: `tabViewSidebarFooter`,
  `sectionActions`, user reordering via `tabViewCustomization`.
  - Caveat: `sidebarAdaptable` was new in macOS 15.0 with early glitches;
    verify on 15.x. The container is swappable — panes don't know their
    host — so falling back to `NavigationSplitView` (native `Label` +
    `.tag()` rows under `List(selection:)`, `Section` headers,
    `navigationSplitViewColumnWidth`) is an afternoon, not a rewrite.
  - Choose `NavigationSplitView` instead only if we later need custom
    sidebar rows (dynamic content, context menus, pinned modes).
- **Title-bar crowding:** the modern treatment is toolbar modifiers, not
  styleMask hacks — `.toolbarBackgroundVisibility(.hidden, for:
  .windowToolbar)` / `.toolbar(removing: .title)` (both macOS 15+, per the
  Destination Video sample). Detail panes keep `.navigationTitle`, which
  gives each pane a proper toolbar and restores the sidebar's top inset.
- **Targets:** macOS 15.0/15.2, Swift 6. Building with the Xcode 26 SDK
  opts the app into Liquid Glass automatically on Tahoe; the 26-only APIs
  worth adopting deliberately — `glassEffect(_:in:)`, `GlassEffectContainer`,
  `backgroundExtensionEffect()` (content extending under the sidebar) —
  go behind `if #available(macOS 26, *)`. The capsule indicator is a natural
  `glassEffect` candidate.
- **Alternative considered and rejected:** `TabView` +
  `.tabViewStyle(.sidebarAdaptable)` (macOS 15) also renders as a sidebar
  and is what Destination Video uses, but it's tab-semantics — less control
  over grouping and detail toolbars than `NavigationSplitView`, and we
  already have the split view.
- **Live viewing:** `#Preview` blocks exist in 7 views — every new pane gets
  one (renderable from Xcode canvas or agent-side). Inject hot reload is
  already wired in every view (`@ObserveInjection`/`.enableInjection()`);
  running InjectionIII/InjectionNext beside a debug build gives ~1s live
  updates without rebuilding.

## Code organization

Feature folders mirror the IA (Apple prescribes no structure; this is the
dominant convention and matches the repo's existing shape). Target layout:

```
TimberVox/
  UI/                      ← shared, reused views (promotion target)
    HotKeyView, StarRatingView, AutoDownloadBannerView,
    settingsCaption style, (future: Kbd chip, InfoHint, stat tile)
  Features/
    Home/                  ← HomeView, StatsStrip, TypingTestSheet, WhatsNewFeed
    Modes/                 ← ModesListView, ModeDetailView
    Dictionary/            ← replacement/removal/vocabulary tables, Scratchpad
    History/               ← existing + gear popover
    Settings/
      GeneralPane/  ShortcutsPane/  RecordingPane/  ModelsPane/  AboutPane/
    Transcription/         ← capsule indicator (its own surface, not a page)
  Stores/  Services/  Clients/   ← unchanged roles
```

Rules:
- A view used by one page lives in that page's folder; used by 2+ pages →
  promote to `UI/`. (`HotKeyView` promotes on day one: Shortcuts pane +
  Modes detail + History gear all use it.)
- **Every view file ships a `#Preview`.** Page-level previews attach a
  shared `PreviewModifier` (Xcode 16+) that supplies a mock world —
  populated model list, fake history, granted permissions — so previews
  look like the real app, not a fresh install. Canvas previews are the
  view-building loop; Inject hot reload is the running-app loop.

## Implementation order

Each step is shippable on its own.

1. **Sidebar + pane split** — new `ActiveTab` cases (home, modes, dictionary,
   history, general, shortcuts, recording, models, about); move existing
   section views into panes per the table. No new controls. `SettingsView`'s
   mega-Form dissolves.
2. **Quick wires** — Language picker into Models; always-on paste/dump
   recorders into Shortcuts (reuse the existing capture flow from
   `PasteLastTranscriptHotkeyRow`); always-on streaming model picker.
3. **History gear popover** — move save/max-entries; delete the settings section.
4. **Permissions → onboarding** — first-run sheet + General status row.
5. **Home v1** — stats strip (history-derived), quick actions, What's New
   from CHANGELOG.md. Typing-test sheet for the time-saved calibration.
6. **Modes v1** — `Mode` model + migration of globals into a default mode;
   list/detail UI; per-mode hotkey dispatch in the hotkey processor.
7. **Dictionary reorg** — rename tab, add Vocabulary section, entry provenance
   fields (prepares the correction loop, which is its own project).

Later projects (separate specs when we get there): correction loop
(alignment diff, recurrence counts, proposal inbox), auto profiles,
voice commands via the dormant keyword-spotting client, cloud auth
(Keychain + license activation against the existing Workers endpoints).
