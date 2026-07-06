# TimberVox Repo Reorg Plan

Status: draft, 2026-07-06. Aligns this repo to the locked
[Apple App Monorepo Structure Standard](repo-structure-standard.md) (from `citration/docs`).

## Context (verified state)

- The working tree is a layered, **uncommitted** rename: `toy-local` → `TimberVox` → `TimberVox`.
  Git still tracks `toy-local`/`ToyLocal*`; remote is still `github.com/chikingsley/toy-local.git`.
- The "OS" naming was introduced by a Codex agent on 2026-07-06 to match a pre-existing
  App Store Connect listing named `TimberVox`. **That listing has since been deleted.**
- New product name: **TimberVox**. New bundle ID: **`com.chiejimofor.timbervox`**
  (old `com.chiejimofor.timbervox` is likely burned by the listing deletion).
- Apple account: Chibuzor Ejimofor · Team `XM69J99HWP` · issuer `d1804d83-…` ·
  working ASC key `Config/keys/ApiKey_F0YBUEMFRDLI.p8`.
- Secrets (`Config/keys/*.p8`, `*.cer`, `*.local.xcconfig`, `.env`) are already gitignored. Good.

## Target layout (standard applied to this repo)

```text
timbervox/
  README.md
  project.yml                     # XcodeGen — source of truth (new)
  Justfile                        # thin task entrypoint (just open / just check)
  .gitignore .swift-format .swiftlint.yml
  apps/
    mac/
      Sources/
        App/            # from TimberVox/App
        Features/       # from TimberVox/Features
        DesignSystem/   # new — extracted from UI (tokens/colors/typography/components)
        UI/             # from TimberVox/UI (shell/controls)
        Clients/        # from TimberVox/Clients (transport: API/auth/sync)
        Providers/      # from TimberVox/Services (capability providers)
        Stores/         # from TimberVox/State + TimberVox/Stores
        Support/        # new — logging/env/errors/diagnostics
        Extensions/     # new
        PreviewSupport/ # new — preview fixtures/fakes; absorbs TimberVox/Prototype
      Tests/            # from TimberVoxTests
      Resources/        # Assets.xcassets, Localizable.xcstrings, Preview Content, AppIcon.icon
      Config/           # Info.plist(s), entitlements, xcconfig (keys stay gitignored)
  packages/
    timbervox-core/         # from TimberVoxCore (Apple-shared Swift core)
    timbervox-contracts/    # new — shared API schemas/fixtures (mac + future Expo)
  services/
    timbervox-api/          # from TimberVoxCloudflareApi (Cloudflare Worker)
  tools/
    timbervox-cli/          # from TimberVoxLiveDriver (timbervox-live) + folded bin/ scripts
    timbervox-probe/        # from TimberVoxBackendPrototype (dev probe) — or archive
  docs/
    repo-structure-standard.md    # copied from citration
    repo-reorg-plan.md            # this file
    …existing repo-wide docs
  timbervox.rb                     # Homebrew cask (renamed)
```

Future `apps/ios`, `apps/mobile` (Expo), `apps/web` drop in without further restructuring.

## Phases (each is a checkpoint)

### Phase 0 — Rebrand to TimberVox  (naming only, no structure change)
- Repo-wide `timbervox`/`TimberVox` → `timbervox`/`TimberVox`: display name, `TimberVox.app`/`.pkg`,
  deep links `timbervox://` + `timbervox-debug://`, Sparkle appcast, cask, `TIMBERVOX_CLOUD_API_URL`,
  `ServiceContainer.swift` default URL, docs.
- Set bundle IDs → `com.chiejimofor.timbervox` (+ `.debug`, `.tests`); update entitlements.
- **Cloudflare (outward-facing — explicit go before destructive steps):** create `timbervox` D1,
  `timbervox-artifacts` R2, `timbervox-jobs`/`-dlq` queues, worker `timbervox`, route
  `timbervox.peacockery.studio`; repoint `wrangler.jsonc`; deploy; verify; then retire the empty
  `timbervox` resources.
- Later (user, in ASC website): create a fresh **TimberVox** app record with bundle ID
  `com.chiejimofor.timbervox` when ready to submit.

### Phase 1 — Clean git baseline
- Stage the entire `toy-local → timbervox` transition and commit as one rename baseline
  (preserves history/blame via rename detection).
- Delete `LICENSE` (divorced from the original fork; product is private). No code references to the
  original author remain — LICENSE is the last one.
- Rename GitHub repo `toy-local` → `timbervox`; update `origin`.

### Phase 2 — Adopt XcodeGen
- Author `project.yml` capturing the mac app target(s) + test bundle + package refs + entitlements +
  build settings currently in `TimberVox.xcodeproj`.
- Gitignore `*.xcodeproj/`; wire `just open` = `xcodegen generate && open TimberVox.xcodeproj`.
- Verify: `xcodegen generate`, `xcodebuild -list`, `xcodebuild build` on the app scheme.

### Phase 3 — Restructure into apps/ packages/ services/ tools/
- `git mv` per the target map. Update `project.yml` source paths, `Package.swift` paths, `Justfile`
  paths, and import/module references.
- Move `Localizable.xcstrings` from repo root into `apps/mac/Resources/`.

### Phase 4 — Consolidate CLIs
- Make `tools/timbervox-cli` the single Swift CLI; fold `bin/export_app_store`,
  `bin/upload_app_store`, `bin/generate_appcast` in as Swift subcommands.
- Delete `bin/` and the empty `scripts/`. `Justfile` calls the CLI.

### Phase 5 — Previews cleanup
- Centralize preview fixtures/fakes in `apps/mac/Sources/PreviewSupport/`.
- Wrap `#Preview` blocks in `#if DEBUG`.
- Remove live-service instantiation from preview/prototype surfaces
  (e.g. the real `AVAudioEngine()` in `PrototypeRecordingStage.swift`).

### Phase 6 — Contracts + docs hygiene
- Add `packages/timbervox-contracts` (shared API schemas/fixtures for mac + future Expo/web).
- Copy `repo-structure-standard.md` into `docs/`; move API-only docs into `services/timbervox-api/docs/`.

## Verification gate (from the standard)
- `README.md` names one root Xcode entrypoint (`TimberVox.xcodeproj`).
- `project.yml` at root; generated `.xcodeproj` gitignored.
- `xcodegen generate` + `xcodebuild -list` + `xcodebuild build` succeed.
- `apps/ packages/ services/ tools/ docs/` ownership is clean; API-only docs live in the service.
