# toy-local — Voice → Text

Press-and-hold a hotkey to transcribe your voice and paste the result wherever you're typing.

**Local fork name: `toy-local` (inspired by [Hex](https://github.com/kitlangton/Hex) by Kit Langton).**

> **Note:** `toy-local` currently targets **Apple Silicon** Macs.

Or download via Homebrew:
```bash
brew install --cask toy-local
```

I've opened-sourced the project in the hopes that others will find it useful! `toy-local` supports both [Parakeet TDT v3](https://github.com/FluidInference/FluidAudio) via the awesome [FluidAudio](https://github.com/FluidInference/FluidAudio) (the default—it's frickin' unbelievable: fast, multilingual, and cloud-optimized) and the awesome [WhisperKit](https://github.com/argmaxinc/WhisperKit) for on-device transcription. We use the incredible [Swift Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) for structuring the app. Please open issues with any questions or feedback! ❤️

## Instructions

Once you open `toy-local`, you'll need to grant microphone, Accessibility, and Input Monitoring permissions so it can record your voice, control paste/typing in other apps, and listen for global hotkeys.

Once you've configured a global hotkey, there are **two recording modes**:

1. **Press-and-hold** the hotkey to begin recording, say whatever you want, and then release the hotkey to start the transcription process. 
2. **Double-tap** the hotkey to *lock recording*, say whatever you want, and then **tap** the hotkey once more to start the transcription process.

## Hot Reload (Debug)

This project uses [`Inject`](https://github.com/krzysztofzablocki/Inject), powered by [`InjectionIII`](https://github.com/johnno1962/InjectionIII), for live Swift/SwiftUI updates while the app is running.

One-time setup:

1. Install InjectionIII in `/Applications` (app name should be `InjectionIII.app`).
2. Run `toy-local` in Xcode using the Debug configuration.
3. Save Swift files while the app is running to inject changes live.

Notes:

- Debug already has the required `-Xlinker -interposable` linker flag.
- The app target includes an `Inject Bundle` build phase that runs InjectionIII's `copy_bundle.sh`.
- Per InjectionIII's current README, running `InjectionIII.app` is not required for standalone injection once the bundle is loaded.
- Opening `InjectionIII.app` is still useful for optional tooling (for example tracing/profiling menus and project-specific app UI).
- If InjectionIII isn't installed, build continues with a warning and hot reload is simply disabled.
- Hot reload code paths are debug-only no-ops in production builds.

## Contributing

**Issue reports are welcome!** If you encounter bugs or have feature requests, please [open an issue](https://github.com/chikingsley/toy-local/issues).

**Note on Pull Requests:** At this stage, I'm not actively reviewing code contributions for significant features or core logic changes. The project is evolving rapidly and it's easier for me to work directly from issue reports. Bug fixes and documentation improvements are still appreciated, but please open an issue first to discuss before investing time in a large PR. Thanks for understanding!

### Testing

Run the full local quality gate:

```bash
bun run check
```

Run individual pieces:

```bash
bun run format:check             # swift format lint
bun run lint                     # swiftlint
cd ToyLocalCore && swift test --parallel
xcodebuild test -project toy-local.xcodeproj -scheme "toy-local" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project toy-local.xcodeproj -scheme "toy-local" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

### Changelog workflow

- **For AI agents:** Run `bun run changeset:add-ai <type> "summary"` (e.g., `bun run changeset:add-ai patch "Fix clipboard timing"`) to create a changeset non-interactively.
- **For humans:** Run `bunx changeset` when your PR needs release notes. Pick `patch`, `minor`, or `major` and write a short summary—this creates a `.changeset/*.md` fragment.
- Check what will ship with `bunx changeset status --verbose`.
- `npm run sync-changelog` (or `bun run tools/scripts/sync-changelog.ts`) mirrors the root `CHANGELOG.md` into `ToyLocal/Resources/changelog.md` so the in-app sheet always matches GitHub releases.
- The release tool consumes the pending fragments, bumps `package.json` + `Info.plist`, regenerates `CHANGELOG.md`, and feeds the resulting section to GitHub + Sparkle automatically. Releases fail fast if no changesets are queued, so you can't forget.
- If you truly need to ship without pending Changesets (for example, re-running a failed publish), the release script will now prompt you to confirm and choose a `patch`/`minor`/`major` bump interactively before continuing.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
