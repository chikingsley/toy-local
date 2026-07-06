set shell := ["/bin/zsh", "-f", "-cu"]

default:
  just --list

# Generate TimberVox.xcodeproj from project.yml (the source of truth)
generate:
  xcodegen generate

# Generate and open the app in Xcode
open: generate
  open TimberVox.xcodeproj

check: generate
  swift format lint --recursive --configuration .swift-format apps/mac/Sources packages/timbervox-core/Sources tools/timbervox-cli/Sources
  swiftlint lint --quiet
  cd packages/timbervox-core && swift test --parallel
  cd tools/timbervox-cli && swift build
  xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" -quiet
  xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

format-check:
  swift format lint --recursive --configuration .swift-format apps/mac/Sources packages/timbervox-core/Sources tools/timbervox-cli/Sources

lint:
  swiftlint lint --quiet

test-core:
  cd packages/timbervox-core && swift test --parallel

test-app: generate
  xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" -quiet

build-release: generate
  xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

app-store-export output="build/app-store/current": generate
  swift run --package-path tools/timbervox-cli timbervox-live app-store export "{{output}}"

app-store-validate package="build/app-store/current/export/TimberVox.pkg":
  swift run --package-path tools/timbervox-cli timbervox-live app-store validate "{{package}}"

app-store-list:
  swift run --package-path tools/timbervox-cli timbervox-live app-store list-apps

app-store-upload package="build/app-store/current/export/TimberVox.pkg":
  swift run --package-path tools/timbervox-cli timbervox-live app-store upload "{{package}}"

app-store-upload-wait package="build/app-store/current/export/TimberVox.pkg":
  swift run --package-path tools/timbervox-cli timbervox-live app-store upload "{{package}}" --wait

appcast +args:
  swift run --package-path tools/timbervox-cli timbervox-live app-store appcast {{args}}

tcc-reset target="debug":
  cd tools/timbervox-cli && swift run timbervox-live tcc-reset --target {{target}}

tcc-reset-debug:
  just tcc-reset debug

tcc-reset-release:
  just tcc-reset release

live +args:
  cd tools/timbervox-cli && swift run timbervox-live {{args}}

live-launch target="debug":
  just live launch --target {{target}}

live-quit target="debug":
  just live quit --target {{target}}

live-state target="debug":
  just live state --target {{target}}

live-open url target="debug":
  cd tools/timbervox-cli && swift run timbervox-live open-url --target {{target}} "{{url}}"

live-check-permissions target="debug":
  just live open-url --target {{target}} timbervox-debug://check-permissions

live-show-onboarding target="debug":
  just live open-url --target {{target}} timbervox-debug://show-onboarding

live-suite suite target="debug":
  just live suite {{suite}} --target {{target}}
