// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TimberVoxBackendPrototype",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "TimberVoxBackendPrototype", targets: ["TimberVoxBackendPrototype"])
  ],
  dependencies: [
    .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.15.4")
  ],
  targets: [
    .executableTarget(
      name: "TimberVoxBackendPrototype",
      dependencies: ["FluidAudio"],
      path: "Sources/TimberVoxBackendPrototype"
    )
  ]
)
