# Changelog

## Unreleased

- TimberVox is FluidAudio-only.
- The visible model catalog is limited to supported Parakeet models.
- Settings and history are stored under TimberVox application support paths.
- Added a first-run setup flow for Microphone and Accessibility permissions.
- Normal TimberVox windows now stay hidden until required permissions are granted.
- If a required permission is removed later, TimberVox returns to setup instead of continuing with broken hotkey/paste behavior.
- Removed App Sandbox so Accessibility permission prompting and text insertion can work correctly.
- Added PermissionPilot as a pinned Swift Package dependency for permission status/request plumbing.
- Added `timbervox://` and `timbervox-debug://` app-control links plus a Swift live driver that launches TimberVox, resets permissions, captures debug state, and drives onboarding through AX button presses.
- Fixed hotkey keycap display for the grave/backtick key and Sauce-supported non-letter keys.
- Added a source-backed FluidAudio model metrics inventory plus codable local diagnostic result schema.
- Added Core cloud transcription and language-model catalogs plus cloud metric profiles that stay aligned with TimberVox Cloud route IDs.
