# TimberVox iOS

Expo/React Native host app plus a native SwiftUI custom keyboard extension. The keyboard communicates with the app through the shared App Group.

[`ARCHITECTURE.md`](ARCHITECTURE.md) is the source of truth for the rebuild, page/component map, native boundaries, decoded Shortcut contract, cleanup rules, and iPhone acceptance lanes.

## Current experimental slice

- First-run microphone and keyboard setup with an app-settings recovery action
- Minimal Home recorder that starts and stops realtime dictation directly
- Local SQLite History with searchable transcripts, retained WAV audio, playback, sharing, and deletion
- Settings with live keyboard/full-access evidence and background-session status
- Expo SDK 57 host app with background audio recording
- Voxtral realtime streaming through `wss://timbervox.peacockery.studio/v1/realtime`
- App-owned TimberVox API authentication injected at build time
- SwiftUI keyboard extension with tap typing, a visible swipe trail, local prototype swipe decoding, three predictions, and a bottom-right dictation control
- Live partial text in the keyboard and final text insertion into the current field
- Debug-only direct launch of `timbervox://session` when no session is active

The swipe decoder is intentionally a small geometric prototype, not yet a SwiftKey-quality language model. The screen UI and background-session controller are experiments being rebuilt deliberately; they are not the accepted product shell.

## Run

```bash
cd apps/ios
pnpm install
pnpm check
pnpm prebuild:ios
pnpm ios
```

This requires a development build; Expo Go cannot contain the keyboard extension. After installing, enable **Settings > General > Keyboard > Keyboards > Add New Keyboard > TimberVoxKeyboard** and grant Full Access so the App Group bridge can operate.

Complete setup, or continue into the app-only recorder. The Home microphone records and transcribes directly. A background session may then stay active while the keyboard's microphone button starts and stops realtime dictation. Users never enter an API key.

Local development, internal preview, and the dedicated `testflight-dev` profile may embed a disposable test Worker credential when `TIMBERVOX_EMBED_DEV_CREDENTIAL=1`. The key comes from `TIMBERVOX_API_KEY` or the ignored repository file at `Config/keys/TimberVoxAPI.local.xcconfig`; EAS builds require the key to exist as an EAS environment secret. The `production` profile explicitly omits this credential. Before public release, replace the disposable-key path with a revocable app-to-Worker mobile session stored in iOS secure storage.

## Personal and distribution modes

The Debug keyboard tries to open the TimberVox host app when a session is not running. This is useful for an Xcode-installed personal development build, but it is deliberately compiled out of Release because App Review guideline 4.4.1 forbids a keyboard extension from launching apps other than Settings.

The next native gate is a signed `AudioRecordingIntent` plus Live Activity spike on a physical iPhone. It must establish whether the Expo JavaScript runtime remains available during system-launched recording before capture ownership is finalized. App Group delivery, microphone behavior, Shortcut start/stop, returned transcript, and keyboard insertion all require physical-device acceptance.
