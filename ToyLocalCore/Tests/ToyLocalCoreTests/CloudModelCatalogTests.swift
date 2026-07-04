import Foundation
import XCTest

@testable import ToyLocalCore

final class CloudModelCatalogTests: XCTestCase {
  func testCloudTranscriptionModelsUseCloudRuntime() {
    XCTAssertTrue(CloudTranscriptionModels.all.allSatisfy { $0.runtime == .cloud })
    XCTAssertTrue(CloudRealtimeTranscriptionModels.all.allSatisfy { $0.runtime == .cloud })
    XCTAssertTrue(TranscriptionModelCatalog.cloud.allSatisfy { $0.runtime == .cloud })
  }

  func testCombinedTranscriptionCatalogIncludesLocalAndCloudModels() {
    XCTAssertNotNil(TranscriptionModelCatalog.model(id: FluidAudioModels.parakeetTdtV3.id))
    XCTAssertNotNil(TranscriptionModelCatalog.model(id: CloudTranscriptionModels.deepgramNova3.id))
    XCTAssertNotNil(TranscriptionModelCatalog.model(id: CloudRealtimeTranscriptionModels.mistralVoxtralMiniRealtime.id))
    XCTAssertEqual(Set(TranscriptionModelCatalog.all.map(\.id)).count, TranscriptionModelCatalog.all.count)
  }

  func testCloudTranscriptionCatalogKeepsProviderRoutingOutOfCore() {
    XCTAssertTrue(TranscriptionModelCatalog.cloud.allSatisfy { $0.upstreamModel == nil })
  }

  func testCloudTranscriptionModelIDsExistInServerRoutes() throws {
    let routes = try readCloudflareModelRoutes()
    for model in TranscriptionModelCatalog.cloud {
      XCTAssertTrue(
        serverRegistryContains(modelID: model.id, providerID: model.provider.rawValue, routes: routes),
        "\(model.id) missing from ToyLocalCloudflareApi/src/ai/model-routes.ts"
      )
    }
  }

  func testCloudLanguageCatalogUsesToyLocalModelIDsOnly() {
    XCTAssertEqual(CloudLanguageModels.defaultModel.id, ToyLocalSettings.defaultTextTransformModel)
    XCTAssertNil(CloudLanguageModels.model(id: "ollama-llama3.2"))
    XCTAssertTrue(CloudLanguageModels.all.allSatisfy { $0.upstreamModel == nil })
  }

  func testCloudLanguageModelIDsExistInServerRoutes() throws {
    let routes = try readCloudflareModelRoutes()
    for model in CloudLanguageModels.all {
      XCTAssertTrue(
        serverRegistryContains(modelID: model.id, providerID: model.provider.rawValue, routes: routes),
        "\(model.id) missing from ToyLocalCloudflareApi/src/ai/model-routes.ts"
      )
    }
  }

  func testCloudModelsHaveMetricProfilesWithoutFakeBenchmarks() {
    let profiledIDs = Set(CloudModelMetrics.profiles.map(\.modelID))
    let cloudModelIDs =
      Set(TranscriptionModelCatalog.cloud.map(\.id))
      .union(CloudLanguageModels.all.map(\.id))

    XCTAssertEqual(profiledIDs, cloudModelIDs)
    XCTAssertTrue(CloudModelMetrics.profiles.allSatisfy { $0.runtime == .cloud })
    XCTAssertTrue(CloudModelMetrics.profiles.allSatisfy { $0.download == nil })
    XCTAssertTrue(CloudModelMetrics.profiles.allSatisfy { $0.officialMetrics.isEmpty })
    XCTAssertTrue(CloudModelMetrics.profiles.allSatisfy { !$0.sources.isEmpty })
  }
}

private func serverRegistryContains(modelID: String, providerID: String, routes: String) -> Bool {
  let providerPrefix = "\(providerID)-"
  guard modelID.hasPrefix(providerPrefix) else {
    return false
  }
  let upstreamModel = String(modelID.dropFirst(providerPrefix.count))
  let hasLanguageRoute = routes.contains("languageRoutes(\"\(providerID)\"")
  let hasTranscriptionRoute = routes.contains("transcriptionRoutes(\"\(providerID)\"")
  let hasRealtimeRoute = routes.contains("realtimeRoutes(\"\(providerID)\"")
  let hasProviderRoute = hasLanguageRoute || hasTranscriptionRoute || hasRealtimeRoute

  return hasProviderRoute && routes.contains("\"\(upstreamModel)\"")
}

private func readCloudflareModelRoutes(filePath: String = #filePath) throws -> String {
  let root = try repositoryRoot(from: URL(fileURLWithPath: filePath))
  let routeFile = root.appendingPathComponent("ToyLocalCloudflareApi/src/ai/model-routes.ts")
  return try String(contentsOf: routeFile, encoding: .utf8)
}

private func repositoryRoot(from fileURL: URL) throws -> URL {
  var directory = fileURL.deletingLastPathComponent()
  while directory.path != "/" {
    if directory.lastPathComponent == "toy-local" {
      return directory
    }
    directory.deleteLastPathComponent()
  }
  throw NSError(
    domain: "ToyLocalCoreTests",
    code: 1,
    userInfo: [NSLocalizedDescriptionKey: "Unable to resolve toy-local repository root."]
  )
}
