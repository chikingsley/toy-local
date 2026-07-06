// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TimberVoxLiveDriver",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "timbervox-live", targets: ["TimberVoxLiveDriver"])
  ],
  dependencies: [
    .package(path: "../TimberVoxCore"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.1.3"),
  ],
  targets: [
    .executableTarget(
      name: "TimberVoxLiveDriver",
      dependencies: [
        "TimberVoxCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Yams",
      ],
      linkerSettings: [
        .linkedFramework("ApplicationServices")
      ]
    )
  ]
)
