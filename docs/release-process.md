# TimberVox Release Process

This document tracks the current release shape. The app is intended to be a public, signed, notarized macOS app with Sparkle updates and an optional Homebrew cask, but the full one-command release pipeline is not currently present in this checkout.

## Current Local Gates

Install local tooling first:

```bash
brew install swiftlint
```

Run these before merging releasable changes:

```bash
just check
swift format lint --recursive --configuration .swift-format TimberVox TimberVoxCore
swiftlint lint --quiet
cd TimberVoxCore && swift test --parallel
xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## Release Artifacts

The intended public artifacts are:

- `TimberVox-{version}.dmg` for direct download and Sparkle.
- `TimberVox-{version}.zip` for Homebrew cask distribution.
- `timbervox-latest.dmg` as a stable latest-download object.
- `appcast.xml` for Sparkle updates.

## Existing Release Files

- `bin/generate_appcast`: Sparkle appcast generator binary.
- `bin/export_app_store`: Mac App Store archive/export helper that writes a local App Store Connect package under `build/app-store/current` by default.
- `bin/upload_app_store`: App Store Connect validation/upload helper that uses `xcrun altool` with the local ignored App Store Connect API key by default.
- `timbervox.rb`: Homebrew cask formula template.
- `CHANGELOG.md`: human-readable release history.
- `TimberVox/Resources/changelog.md`: in-app changelog content.

## Mac App Store Export Check

Run the local App Store export check with `just app-store-export`.

This command replaces `build/app-store/current`, archives the `TimberVox-AppStore` scheme, exports with automatic App Store Connect signing, and leaves the `TimberVox.pkg` package plus `DistributionSummary.plist` for inspection.

This is not an upload or submission step.

## Mac App Store Upload

Run `just app-store-validate` to validate the exported package, or `just app-store-upload-wait` to upload it and wait for App Store Connect processing.

The upload helper defaults to the verified local App Store Connect app and API key: app Apple ID `6787965139`, API key id `F0YBUEMFRDLI`, issuer id `d1804d83-f266-43bc-8cda-edb51b2c2354`, and `Config/keys/ApiKey_F0YBUEMFRDLI.p8`.

Uploading a build is not the same as submitting for App Review.

## Missing Pipeline Work

Before a real public release, rebuild or restore the release tool that:

1. Updates app versions and release notes.
2. Builds and archives the app with Developer ID signing.
3. Notarizes the app and DMG.
4. Creates DMG and ZIP artifacts.
5. Generates `appcast.xml` with strictly increasing `CFBundleVersion`.
6. Uploads release artifacts to S3.
7. Creates a GitHub release and updates the Homebrew cask metadata.

Do not publish Sparkle updates manually unless `CFBundleVersion` ordering has been checked. Duplicate or decreasing build numbers break update delivery.
