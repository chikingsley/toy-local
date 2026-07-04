// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ToyLocalLiveDriver",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "toy-local-live", targets: ["ToyLocalLiveDriver"])
  ],
  dependencies: [
    .package(path: "../ToyLocalCore"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.1.3"),
  ],
  targets: [
    .executableTarget(
      name: "ToyLocalLiveDriver",
      dependencies: [
        "ToyLocalCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Yams",
      ],
      linkerSettings: [
        .linkedFramework("ApplicationServices")
      ]
    )
  ]
)
