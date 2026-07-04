// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ToyLocalCore",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "ToyLocalCore", targets: ["ToyLocalCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/Clipy/Sauce", branch: "master"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
  ],
  targets: [
    .target(
      name: "ToyLocalCore",
      dependencies: [
        "Sauce",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/ToyLocalCore",
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .testTarget(
      name: "ToyLocalCoreTests",
      dependencies: ["ToyLocalCore"],
      path: "Tests/ToyLocalCoreTests",
      resources: [
        .process("Transcription/CaptionRenderingFixtures.json")
      ]
    ),
  ]
)
