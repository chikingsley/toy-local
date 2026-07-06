# TimberVox — Voice to Text

Press-and-hold a hotkey to transcribe your voice and paste the result wherever you're typing.

> **Note:** `TimberVox` currently targets **Apple Silicon** Macs.

Or download via Homebrew:
```bash
brew install --cask timbervox
```

I've opened-sourced the project in the hopes that others will find it useful. `TimberVox` uses [FluidAudio](https://github.com/FluidInference/FluidAudio) for on-device transcription, with Parakeet models currently wired into the app. The app is structured with SwiftUI, Observation (`@Observable`) stores, async services, and a small pure-Swift core package for testable hotkey/transcript logic.

## Instructions

Once you open `TimberVox`, you'll need to grant microphone and Accessibility permissions so it can record your voice, listen for global hotkeys, and control paste/typing in other apps.

Once you've configured a global hotkey, there are **two recording modes**:

1. **Press-and-hold** the hotkey to begin recording, say whatever you want, and then release the hotkey to start the transcription process. 
2. **Double-tap** the hotkey to *lock recording*, say whatever you want, and then **tap** the hotkey once more to start the transcription process.

## Hot Reload (Debug)

This project uses [`Inject`](https://github.com/krzysztofzablocki/Inject), powered by [`InjectionIII`](https://github.com/johnno1962/InjectionIII), for live Swift/SwiftUI updates while the app is running.

One-time setup:

1. Install InjectionIII in `/Applications` (app name should be `InjectionIII.app`).
2. Run `TimberVox` in Xcode using the Debug configuration.
3. Save Swift files while the app is running to inject changes live.

Notes:

- Debug already has the required `-Xlinker -interposable` linker flag.
- The app target includes an `Inject Bundle` build phase that runs InjectionIII's `copy_bundle.sh`.
- Per InjectionIII's current README, running `InjectionIII.app` is not required for standalone injection once the bundle is loaded.
- Opening `InjectionIII.app` is still useful for optional tooling (for example tracing/profiling menus and project-specific app UI).
- If InjectionIII isn't installed, build continues with a warning and hot reload is simply disabled.
- Hot reload code paths are debug-only no-ops in production builds.

## Contributing

**Issue reports are welcome!** If you encounter bugs or have feature requests, please [open an issue](https://github.com/chikingsley/timbervox/issues).

**Note on Pull Requests:** At this stage, I'm not actively reviewing code contributions for significant features or core logic changes. The project is evolving rapidly and it's easier for me to work directly from issue reports. Bug fixes and documentation improvements are still appreciated, but please open an issue first to discuss before investing time in a large PR. Thanks for understanding!

### Testing

Install repo tooling first:

```bash
brew install swiftlint
```

Run individual pieces:

```bash
just --list
just check
swift format lint --recursive --configuration .swift-format TimberVox TimberVoxCore
swiftlint lint --quiet
cd TimberVoxCore && swift test --parallel
xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Reset local macOS permission prompts for development:

```bash
just tcc-reset-debug
just tcc-reset-release
```

## License

This project is licensed under the MIT License. See `LICENSE` for details.
