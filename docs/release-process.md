# ToyLocal Release Process

This document tracks the current release shape. The app is intended to be a public, signed, notarized macOS app with Sparkle updates and an optional Homebrew cask, but the full one-command release pipeline is not currently present in this checkout.

## Current Local Gates

Install local tooling first:

```bash
brew install swiftlint
```

Run these before merging releasable changes:

```bash
just check
swift format lint --recursive --configuration .swift-format ToyLocal ToyLocalCore
swiftlint lint --quiet
cd ToyLocalCore && swift test --parallel
xcodebuild test -project toy-local.xcodeproj -scheme "toy-local" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project toy-local.xcodeproj -scheme "toy-local" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## Release Artifacts

The intended public artifacts are:

- `ToyLocal-{version}.dmg` for direct download and Sparkle.
- `ToyLocal-{version}.zip` for Homebrew cask distribution.
- `toy-local-latest.dmg` as a stable latest-download object.
- `appcast.xml` for Sparkle updates.

## Existing Release Files

- `bin/generate_appcast`: Sparkle appcast generator binary.
- `toy-local.rb`: Homebrew cask formula template.
- `CHANGELOG.md`: human-readable release history.
- `ToyLocal/Resources/changelog.md`: in-app changelog content.

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
