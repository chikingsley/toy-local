# Mac App Store launch checklist (TimberVox listing, TimberVox binary, target: August 1)

Compiled from Apple's Mac submission page (https://developer.apple.com/macos/submit/), App Review Guidelines, and this project's verified state. Owner tags: [Chi] = account/product decisions, [agent] = buildable/verifiable here.

## Build and technical requirements

- [x] App Sandbox enabled on the App Store target with working core features (verified 2026-07-05: launch, permissions, model load, real local transcription inside the sandbox).
- [x] No private APIs in the App Store binary (verified: zero MediaRemote symbols; direct build unaffected).
- [x] No self-updater in the App Store build (Sparkle unlinked; SU keys absent from Info-AppStore.plist).
- [ ] Build with the required Xcode/SDK (Apple requires macOS SDK 26+ for submissions as of 2026-04-28; we build with Xcode 26.x — confirm at archive time). [agent]
- [ ] Decide Apple-silicon-only vs universal. We currently target arm64 for development; Apple allows ARM64-only Mac apps (macOS 12+ minimum) but an app that ships Apple-silicon-only cannot later claim it never supported Intel. Recommendation: ship ARM64-only (FluidAudio CoreML models are Apple-silicon-first). [Chi confirms]
- [ ] Distribution signing: App Store Connect upload uses the Apple Distribution certificate + Mac App Store provisioning (automatic signing handles this at archive; verify the archive validates). [agent]
- [ ] Sandbox container data decision: MAS build starts with a fresh container — decide whether to import existing direct-build history on first launch. [Chi decides, agent builds]

## App Store Connect setup

- [ ] Register the App ID `com.chiejimofor.timbervox` at developer.apple.com → Identifiers (if not already present from signing). [Chi]
- [ ] Create the app record: App Store Connect → My Apps → "+" → New App → platform macOS, name `TimberVox`, primary language, bundle ID `com.chiejimofor.timbervox`, and SKU `com.chiejimofor.timbervox` or the already-created immutable SKU. [Chi]
- [ ] Agreements, Tax, and Banking: accept the Paid Apps agreement and complete banking + tax forms — REQUIRED before any in-app purchase can even be created or sandbox-tested; processing can take days, so this is the long pole. [Chi]
- [ ] Generate the In-App Purchase Key and an App Store Connect API key (Users and Access → Integrations) — both go to RevenueCat, and the App Store Connect API key also powers `just app-store-validate` and `just app-store-upload-wait`. [Chi]
- [x] App Store Connect upload credentials verified locally: app Apple ID `6787965139`, API key id `F0YBUEMFRDLI`, issuer id `d1804d83-f266-43bc-8cda-edb51b2c2354`, and the matching ignored `.p8` under `Config/keys/`. [agent verified 2026-07-06]
- [ ] Create the IAP/subscription products (pricing decision) once agreements clear. [Chi]

## Product page

- [ ] App name, subtitle, description (must include auto-renewing subscription disclosure if selling subscriptions), keywords, support URL, marketing URL. [Chi with agent drafts]
- [ ] App icon (existing AppIcon ships in the build; the store listing uses it automatically). 
- [ ] Screenshots: Mac screenshots at an accepted size (2880x1800, 2560x1600, or 1280x800). Plan: Home, Modes, a dictation-in-action shot, History, Settings. [agent can capture, Chi approves]
- [ ] Age rating questionnaire (will come out 4+). [Chi]
- [ ] Category: Productivity (current Info.plist says Utilities — pick one and align INFOPLIST_KEY_LSApplicationCategoryType). [Chi]

## Privacy and review readiness

- [ ] App Privacy nutrition labels: declare audio data (voice recordings processed on device; sent to our server only when a cloud model is selected), transcripts (stored locally), no tracking, no third-party ads. Cloud path discloses transfer to our processor (Deepgram/Mistral via our worker). [Chi enters, agent drafts the answers]
- [ ] Usage-description strings reviewed (microphone present; ensure any additional TCC-gated feature the MAS build exposes has a purpose string). [agent]
- [ ] Review notes: explain WHY the app requests Accessibility (paste simulation into the frontmost app) and Input Monitoring (global dictation hotkey) with steps for the reviewer to test; precedent apps that pass with these grants exist (window managers, clipboard managers). Include a demo login-free flow description. [agent drafts]
- [ ] Export compliance: the app uses only standard HTTPS/TLS — answer the encryption question with the standard exemption. [Chi]
- [ ] App Review Guidelines self-check: 2.5.1 public APIs only (verified), 2.4.5 Mac app requirements (sandbox verified), 3.1.1 purchases via IAP only in the MAS build (RevenueCat StoreKit flow; the web-billing path must NOT be linked or mentioned inside the MAS build). [agent]

## Testing and release

- [ ] TestFlight (Mac): upload a build, install via TestFlight app, run the full sandboxed hands-on pass (hotkeys, dictation, paste, Super Fast Mode, system audio). [Chi + agent]
- [ ] Upload path: run `just app-store-export`, then `just app-store-validate`, then `just app-store-upload-wait`; do not submit for public App Review until the review metadata, privacy answers, and RevenueCat production key are ready. [agent]
- [ ] Sandbox IAP purchase + restore verified through TestFlight build (see RevenueCat checklist). [Chi]
- [ ] Submit for review with manual release; first submission should land mid-July to leave room for a rejection round before August 1. [Chi]
- [ ] On approval: release manually, wait for propagation, then announce. [Chi]
