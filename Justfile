set shell := ["/bin/zsh", "-f", "-cu"]

default:
  just --list

check:
  swift format lint --recursive --configuration .swift-format ToyLocal ToyLocalCore ToyLocalLiveDriver/Sources
  swiftlint lint --quiet
  cd ToyLocalCore && swift test --parallel
  cd ToyLocalLiveDriver && swift build
  xcodebuild test -project toy-local.xcodeproj -scheme "toy-local" -destination "platform=macOS,arch=arm64" -quiet
  xcodebuild build -project toy-local.xcodeproj -scheme "toy-local" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

format-check:
  swift format lint --recursive --configuration .swift-format ToyLocal ToyLocalCore ToyLocalLiveDriver/Sources

lint:
  swiftlint lint --quiet

test-core:
  cd ToyLocalCore && swift test --parallel

test-app:
  xcodebuild test -project toy-local.xcodeproj -scheme "toy-local" -destination "platform=macOS,arch=arm64" -quiet

build-release:
  xcodebuild build -project toy-local.xcodeproj -scheme "toy-local" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

tcc-reset target="debug":
  cd ToyLocalLiveDriver && swift run toy-local-live tcc-reset --target {{target}}

tcc-reset-debug:
  just tcc-reset debug

tcc-reset-release:
  just tcc-reset release

live +args:
  cd ToyLocalLiveDriver && swift run toy-local-live {{args}}

live-launch target="debug":
  just live launch --target {{target}}

live-quit target="debug":
  just live quit --target {{target}}

live-state target="debug":
  just live state --target {{target}}

live-open url target="debug":
  cd ToyLocalLiveDriver && swift run toy-local-live open-url --target {{target}} "{{url}}"

live-check-permissions target="debug":
  just live open-url --target {{target}} toylocal-debug://check-permissions

live-show-onboarding target="debug":
  just live open-url --target {{target}} toylocal-debug://show-onboarding

live-suite suite target="debug":
  just live suite {{suite}} --target {{target}}
