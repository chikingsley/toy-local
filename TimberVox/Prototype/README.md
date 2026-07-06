# UI Prototype sandbox

Self-contained chrome prototype — nothing in the shipping app references this
folder. Everything here uses local @State and fake data (no AppStore /
SettingsStore). The faux window frame + traffic lights exist only so previews
show the full look; when a piece is approved it gets ported into Features/
and the fake chrome is replaced by the real NSWindow configuration
(see docs/app-organization.md → SwiftUI integration notes).

Work here freely. Delete pieces after they're ported.

## Layout

- `UI/` — shared components, one component per file (`Proto*`). Design
  tokens live in `UI/ProtoTheme.swift` — layout constants AND surface
  colors/radii. New surfaces must use tokens, not `.white.opacity(…)`
  literals.
- `Panes/` — one file per sidebar page. If a pane grows page-specific
  components, give it a folder with the pane + its components; promote
  anything used by 2+ panes to `UI/`.
- `Recorders/` — the recording-overlay variants plus `PrototypeRecordingStage`
  (the fake-desktop harness that hosts them).
- `PrototypeShell.swift` / `PrototypeModeSwitcher.swift` — window scaffold,
  sidebar/nav, and the floating mode-switcher HUD.

Provider logos and appearance thumbnails live in the app asset catalog
(`Assets.xcassets`, `provider-*` / `appearance-*` imagesets — template SVGs
where available), rendered through `UI/ProtoProviderLogo.swift`.

## Conventions

- Separators inside cards: `ProtoDivider()` — never a bare full-width
  `Divider()`. Use `leadingInset:` to align with an icon column.
- Rows: `ProtoRow` / `ProtoToggleRow` / `ProtoSettingsRow` before hand-rolling
  a new HStack skeleton.
- Section scaffolding: `ProtoSection { ProtoCard { … } }`, panes wrapped in
  `ProtoPane`, headers via `ProtoHeader`.
