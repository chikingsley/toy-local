default: build

xcode_local_flags := "-derivedDataPath .build/DerivedData -clonedSourcePackagesDirPath .build/SourcePackages -disablePackageRepositoryCache -skipPackageUpdates -jobs 2"

# Regenerate TimberVox.xcodeproj from project.yml (run after any file add/move/delete)
generate:
    xcodegen generate

build: generate
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug build

check-build: generate
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug {{xcode_local_flags}} CODE_SIGNING_ALLOWED=NO build

format:
    swift format --in-place --recursive --configuration .swift-format TimberVox TimberVoxTests TimberVoxUITests

format-check:
    swift format lint --strict --recursive --configuration .swift-format TimberVox TimberVoxTests TimberVoxUITests

lint:
    swiftlint lint --strict --config .swiftlint.yml

test: generate
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug {{xcode_local_flags}} CODE_SIGNING_ALLOWED=NO test

# Measures the five-run Home click -> populated History signpost interval.
test-navigation-performance: generate
    xcodebuild -quiet -project TimberVox.xcodeproj -scheme TimberVoxNavigationPerformance -configuration Debug {{xcode_local_flags}} test -only-testing:TimberVoxUITests/NavigationPerformanceUITests/testHomeToHistoryPresentation

# One-time, idempotent import of active MacWhisper dictations and their audio.
import-macwhisper: generate
    touch /tmp/timbervox-import-macwhisper
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:TimberVoxTests/MacWhisperImportTests/testImportsLiveLibraryWhenExplicitlyEnabled; status=$?; rm -f /tmp/timbervox-import-macwhisper; exit $status

# Dual-speech acceptance: needs YOU. After the spoken "start speaking now" cue, say "purple elephant marmalade sandwich" repeatedly until the stop cue (~15s). Speaker volume is lowered automatically so the system phrase only reaches the tap.
test-dual-speech: generate
    touch /tmp/timbervox-dual-speech
    vol=$(osascript -e "output volume of (get volume settings)"); xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/DualSpeechLiveAcceptanceTests; status=$?; osascript -e "set volume output volume $vol"; rm -f /tmp/timbervox-dual-speech; exit $status

# Ten-minute capture endurance: looping tone, bounded memory, capture alive at the end. Takes ~11 minutes.
test-endurance: generate
    touch /tmp/timbervox-endurance
    vol=$(osascript -e "output volume of (get volume settings)"); osascript -e "set volume output volume 8"; xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/AudioEnduranceLiveTests; status=$?; osascript -e "set volume output volume $vol"; rm -f /tmp/timbervox-endurance; exit $status

# Pause-policy acceptance: QuickTime plays a tone; the Pause policy must silence the captured system audio and restore must resume it. May show a one-time "control QuickTime Player" permission dialog.
test-pause: generate
    touch /tmp/timbervox-pause-acceptance
    vol=$(osascript -e "output volume of (get volume settings)"); osascript -e "set volume output volume 25"; xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/PausePolicyLiveTests; status=$?; osascript -e "set volume output volume $vol"; rm -f /tmp/timbervox-pause-acceptance; exit $status

# Live acceptance: signed test host, real audio devices, real cloud providers. Artifacts land in /tmp/timbervox-acceptance.
test-live: generate
    touch /tmp/timbervox-live-audio-capture /tmp/timbervox-live-provider-acceptance
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/AudioCaptureLiveTests -only-testing:TimberVoxTests/PlaybackControlLiveTests -only-testing:TimberVoxTests/DictationProviderLiveAcceptanceTests; status=$?; rm -f /tmp/timbervox-live-audio-capture /tmp/timbervox-live-provider-acceptance; exit $status

# Text-transform acceptance: real fixed requests through Voice Lab. Artifacts land in /tmp/timbervox-acceptance.
test-transform-live: generate
    touch /tmp/timbervox-live-transform-acceptance
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedDataTransform test -only-testing:TimberVoxTests/TextTransformProviderLiveAcceptanceTests; status=$?; rm -f /tmp/timbervox-live-transform-acceptance; exit $status

# Local-model acceptance: prepares the Hummingbird batch route, verifies cache reuse across a fresh backend, then transcribes a known phrase with network access disabled.
test-local-model-live: generate
    touch /tmp/timbervox-live-local-model
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testHummingbirdBatchDownloadsPersistsAndTranscribesOffline; status=$?; rm -f /tmp/timbervox-live-local-model; exit $status

# Complete paired-package acceptance. This is separate because it also loads the realtime Core ML route and can expose hardware/runtime-specific model failures.
test-local-package-live: generate
    touch /tmp/timbervox-live-local-package
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testHummingbirdPackageDownloadsAndPersists; status=$?; rm -f /tmp/timbervox-live-local-package; exit $status

# Full local inference matrix. Downloads and runs every distinct batch/realtime asset exposed by the three local packages.
test-local-matrix-live: generate
    touch /tmp/timbervox-live-local-matrix
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testParakeetV3DownloadsAndTranscribes -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testNemotronEnglish560DownloadsAndTranscribes -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testNemotronEnglish1120DownloadsAndTranscribes -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testNemotronMultilingualLatinDownloadsAndTranscribes -only-testing:TimberVoxTests/LocalModelLiveAcceptanceTests/testNemotronMultilingualFullDownloadsAndTranscribesJapanese; status=$?; rm -f /tmp/timbervox-live-local-matrix; exit $status

# Full offline app workflow: system speech capture, local batch transcription, persistence, and clipboard delivery.
test-local-workflow-live: generate
    touch /tmp/timbervox-live-local-workflow
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/LocalWorkflowLiveTests/testSystemSpeechRunsThroughOfflineRecordToDeliveryWorkflow; status=$?; rm -f /tmp/timbervox-live-local-workflow; exit $status

# Real local-model failure/endurance paths: silence, long speech, cancellation/restart, and bounded offline preparation failure.
test-local-endurance-live: generate
    touch /tmp/timbervox-live-local-endurance
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/LocalModelEnduranceLiveTests; status=$?; rm -f /tmp/timbervox-live-local-endurance; exit $status

# Songbird language acceptance: six shared batch/realtime languages plus Japanese and Chinese realtime-only routes.
test-songbird-live: generate
    touch /tmp/timbervox-live-songbird
    xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -derivedDataPath .build/DerivedData test -only-testing:TimberVoxTests/SongbirdLiveAcceptanceTests; status=$?; rm -f /tmp/timbervox-live-songbird; exit $status

check: format-check lint test check-build

run: build
    open build/Debug/TimberVox.app 2>/dev/null || open "$(xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/TimberVox.app"

run-onboarding: build
    open "$(xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/TimberVox.app" --args --show-onboarding

run-app: build
    open "$(xcodebuild -project TimberVox.xcodeproj -scheme TimberVox -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/TimberVox.app" --args --skip-onboarding

open: generate
    open TimberVox.xcodeproj
