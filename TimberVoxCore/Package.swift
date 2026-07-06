// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TimberVoxCore",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "TimberVoxCore", targets: ["TimberVoxCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/Clipy/Sauce", branch: "master"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
  ],
  targets: [
    .target(
      name: "TimberVoxCore",
      dependencies: [
        "Sauce",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/TimberVoxCore",
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .testTarget(
      name: "TimberVoxCoreTests",
      dependencies: ["TimberVoxCore"],
      path: "Tests/TimberVoxCoreTests",
      resources: [
        .process("Transcription/CaptionRenderingFixtures.json")
      ]
    ),
  ]
)
