# Changelog

## Unreleased

- ToyLocal is FluidAudio-only.
- The visible model catalog is limited to supported Parakeet models.
- Settings and history are stored under ToyLocal application support paths.
- Added a first-run setup flow for Microphone and Accessibility permissions.
- Normal ToyLocal windows now stay hidden until required permissions are granted.
- If a required permission is removed later, ToyLocal returns to setup instead of continuing with broken hotkey/paste behavior.
- Removed App Sandbox so Accessibility permission prompting and text insertion can work correctly.
- Added PermissionPilot as a pinned Swift Package dependency for permission status/request plumbing.
- Added `toylocal://` and `toylocal-debug://` app-control links plus a Swift live driver that launches ToyLocal, resets permissions, captures debug state, and drives onboarding through AX button presses.
- Fixed hotkey keycap display for the grave/backtick key and Sauce-supported non-letter keys.
- Added a source-backed FluidAudio model metrics inventory plus codable local diagnostic result schema.
- Added Core cloud transcription and language-model catalogs plus cloud metric profiles that stay aligned with Toy Local Cloud route IDs.
