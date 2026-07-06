set shell := ["/bin/zsh", "-f", "-cu"]

default:
  just --list

check:
  swift format lint --recursive --configuration .swift-format TimberVox TimberVoxCore TimberVoxLiveDriver/Sources
  swiftlint lint --quiet
  cd TimberVoxCore && swift test --parallel
  cd TimberVoxLiveDriver && swift build
  xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" -quiet
  xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

format-check:
  swift format lint --recursive --configuration .swift-format TimberVox TimberVoxCore TimberVoxLiveDriver/Sources

lint:
  swiftlint lint --quiet

test-core:
  cd TimberVoxCore && swift test --parallel

test-app:
  xcodebuild test -project TimberVox.xcodeproj -scheme "TimberVox" -destination "platform=macOS,arch=arm64" -quiet

build-release:
  xcodebuild build -project TimberVox.xcodeproj -scheme "TimberVox" -configuration Release -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet

app-store-export output="build/app-store/current":
  bin/export_app_store "{{output}}"

app-store-validate package="build/app-store/current/export/TimberVox.pkg":
  bin/upload_app_store validate "{{package}}"

app-store-list:
  bin/upload_app_store list-apps

app-store-upload package="build/app-store/current/export/TimberVox.pkg":
  bin/upload_app_store upload "{{package}}"

app-store-upload-wait package="build/app-store/current/export/TimberVox.pkg":
  bin/upload_app_store upload-wait "{{package}}"

tcc-reset target="debug":
  cd TimberVoxLiveDriver && swift run timbervox-live tcc-reset --target {{target}}

tcc-reset-debug:
  just tcc-reset debug

tcc-reset-release:
  just tcc-reset release

live +args:
  cd TimberVoxLiveDriver && swift run timbervox-live {{args}}

live-launch target="debug":
  just live launch --target {{target}}

live-quit target="debug":
  just live quit --target {{target}}

live-state target="debug":
  just live state --target {{target}}

live-open url target="debug":
  cd TimberVoxLiveDriver && swift run timbervox-live open-url --target {{target}} "{{url}}"

live-check-permissions target="debug":
  just live open-url --target {{target}} timbervox-debug://check-permissions

live-show-onboarding target="debug":
  just live open-url --target {{target}} timbervox-debug://show-onboarding

live-suite suite target="debug":
  just live suite {{suite}} --target {{target}}
