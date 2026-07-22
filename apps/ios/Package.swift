// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "TimberVoxIOSNativeTests",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "TimberVoxSwipeDecoder", targets: ["TimberVoxSwipeDecoder"])
  ],
  targets: [
    .target(
      name: "TimberVoxSwipeDecoder",
      path: "targets/keyboard",
      exclude: [
        "AppGroupBridge.swift",
        "Info.plist",
        "KeyboardRootView.swift",
        "KeyboardSuggestionBar.swift",
        "KeyboardViewController.swift",
        "FUTO_SWIPE_LICENSE.txt",
        "FutoContextLanguageModel.swift",
        "FutoSwipeRuntime.swift",
        "NeuralSwipeDecoder.swift",
        "SwipeKeySurface.swift",
        "TimberVoxExecuTorchBridge.h",
        "TimberVoxExecuTorchBridge.mm",
        "TimberVoxKeyboard-Bridging-Header.h",
        "assets",
        "expo-target.config.js",
        "futo_swipe_encoder.pte",
        "futo_swipe_context_lm.pte",
        "futo_swipe_refiner.pte",
        "generated.entitlements",
      ],
      sources: [
        "CTCTrieDecoder.swift",
        "GeometricSwipeDecoder.swift",
        "KeyboardLanguageEngine.swift",
        "FutoContextVocabulary.swift",
        "FutoWordHash.swift",
        "SwipeInputPreprocessor.swift",
        "SwipeDecoderTypes.swift",
      ]
    ),
    .testTarget(
      name: "TimberVoxSwipeDecoderTests",
      dependencies: ["TimberVoxSwipeDecoder"],
      path: "targets/keyboard-tests"
    ),
  ]
)
