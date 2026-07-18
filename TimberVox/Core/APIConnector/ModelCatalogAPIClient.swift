import Foundation

struct ModelCatalogAPIClient: Sendable {
  static let production = ModelCatalogAPIClient(baseURL: APIConnector.productionBaseURL)

  var api: APIConnector

  init(baseURL: URL, session: URLSession = .shared) {
    api = APIConnector(baseURL: baseURL, session: session)
  }

  func models() async throws -> [CatalogModel] {
    let response: ModelCatalogResponse = try await api.get(
      path: "v1/models"
    )
    if response.presentationSchemaVersion != 1 {
      throw APIConnectorError.invalidResponse
    }
    return response.models
  }
}

struct ModelCatalogResponse: Decodable {
  var models: [CatalogModel]
  var presentationSchemaVersion: Int
}
