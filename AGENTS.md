# AGENTS.md — how to work in this repo

Every agent (Claude, Codex, or otherwise) reads this file before touching anything. The work list lives in docs/TODO.md and contains ONLY work items.

## Non-negotiable rules

- No commits until explicitly requested.
- Every change names its verification gate and runs it.
- Files stay under 500 lines; splits follow real responsibility boundaries, never mechanical line cuts. Type bodies stay under 300 lines.
- Numbers are named constants. Never repeat a magic number.
- No code comments in UI code.
- Components own their sizing and behavior. Call sites do not pass widths, heights, row counts, or insets unless that call site is a documented exception. If two call sites configure the same thing, the component is wrong — fix the component.
- Take UI direction literally. The prototype and Chi's screenshots are the spec; copy physically, do not reinterpret.
- When behavior is uncertain or something fails, read the latest OFFICIAL documentation for the technology in question. Never curate product facts from secondary sources (registries, code lists, memory).
- Choose the mainstream approach first; note modern alternatives as caveats in docs/TODO.md.
- Markdown in docs/ uses complete sentences and checkbox lists. Never hard-wrap lines — one sentence or bullet stays on one line and the editor soft-wraps.

## Gates

Fast gate (every change):
- `swift format lint --recursive --configuration .swift-format TimberVox TimberVoxCore TimberVoxLiveDriver/Sources`
- `swiftlint lint --quiet`
- `cd TimberVoxCore && swift test --parallel`
- `just test-app`

Live gate (user-visible behavior):
- `just live-suite permission-onboarding debug`
- `just live-suite permission-regression debug`

Release gate: Release xcodebuild, signed Debug from Terminal, notarized artifacts, Sparkle appcast with strictly increasing CFBundleVersion.

Visual verification: render the relevant #Preview (Xcode MCP RenderPreview) in BOTH color schemes for any UI change. Preview renders cannot show child NSWindows (popovers in the real app) or real window chrome — those need a real app relaunch, and reports must say so instead of claiming verification.

## UI system (locked)

- Design tokens only: `TLTheme` + `Shadcn` named steps. No raw hex or opacity literals in panes.
- One component per file under TimberVox/UI/ with the `TL` prefix.
- `TLSettingsCard` interleaves dividers automatically; rows are `TLSettingsRow`/`TLSettingsToggleRow`; dropdowns are `TLOptionMenu` popovers (segmented controls excepted); never system Menu/Picker in panes.
- Dropdown panels show a bounded number of rows then scroll; the bound lives INSIDE the component.
- Shortcut recorder state machine lives in `TLShortcutRecorder`; real capture goes through `SettingsStore` capture modes per docs/hotkey-semantics.md.
- Geometry plumbing uses `onGeometryChange` ONLY (GeometryReader + preference keys silently broke anchor delivery once already).
- Popovers require `TLFloatingHost`; every pane preview wraps in it.
- Headers are page-owned; no pane name in the header; empty header slot shows the microphone pill.

## Resources (use them; do not re-derive)

- docs/TODO.md — the work list. docs/app-organization.md — the IA spec. docs/hotkey-semantics.md — hotkey engine behavior. docs/recorders/ — parked recorder HUD spec. docs/archive/ — history.
- CHANGELOG.md (repo root) — every landed change gets one line under Unreleased.
- Chat history across all agents: `chat-sync` skill (search before re-deriving decisions; sessions cover Superwhisper reverse-engineering, storage schema findings, chrome research).
- Reference apps ON THIS MACHINE: /Applications/superwhisper.app (primary design reference; its SQLite/GRDB schema was inspected and documented), /Applications/MacWhisper.app (secondary; competitive target).
- ~/GitHub/superwhisper-api — reverse-engineered wire contract, mode files, captured prompts, and superwhisper-ui-clone (exact CSS values, layouts).
- TimberVoxBackendPrototype/Runs/ — 69 recorded provider responses (Deepgram raw included). Replay before any live call; keep live calls to 3–5 per feature.
- Debug deep links (`timbervox-debug://`): state, check-permissions, show-onboarding, download-model, transcribe-file?model=&path=, text-transform?text=, quit. These drive REAL runs from a shell.
- TimberVoxLiveDriver — launch/AX-drive the real app; `just live-suite`.
- API keys: TimberVoxCloudflareApi/.env (MISTRAL_API_KEY, DEEPGRAM_API_KEY, TIMBERVOX_ADMIN_TOKEN). License minting runs against local `wrangler dev` only; the deployed admin token is not retrievable. Wrangler ignores .env when .dev.vars exists — keep the two in sync or use only .env.
- Codex dispatch (when Claude orchestrates): `codex exec --sandbox workspace-write --model gpt-5.5 -c model_reasoning_effort="xhigh" "<brief>" < /dev/null` — stdin MUST be closed or codex hangs. Codex sandboxes cannot run xcodebuild or default-path swiftlint caches; the auditor runs those after.

## Testability classes (used in docs/TODO.md)

- [A] agent-verifiable end to end (unit test, debug link, live driver, replayed fixture).
- [B] agent wires and backend-tests; Chi does the visual/interactive pass.
- [C] needs human perception or hardware; agent stages, Chi verifies.
