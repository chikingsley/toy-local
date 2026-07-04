// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ToyLocalBackendPrototype",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "ToyLocalBackendPrototype", targets: ["ToyLocalBackendPrototype"])
  ],
  dependencies: [
    .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.15.4")
  ],
  targets: [
    .executableTarget(
      name: "ToyLocalBackendPrototype",
      dependencies: ["FluidAudio"],
      path: "Sources/ToyLocalBackendPrototype"
    )
  ]
)
