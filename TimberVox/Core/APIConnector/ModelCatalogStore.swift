import Observation

@MainActor
@Observable
final class ModelCatalogStore {
  static let shared = ModelCatalogStore()

  private let client: ModelCatalogAPIClient
  private var hasLoaded = false

  private(set) var isLoading = false
  private(set) var lastError: String?
  private(set) var models: [CatalogModel] = []

  var hasLoadedSuccessfully: Bool { hasLoaded }

  init(client: ModelCatalogAPIClient = .current) {
    self.client = client
  }

  var languageModels: [CatalogModel] {
    models.filter(\.isLanguageModel).sorted { $0.displayName < $1.displayName }
  }

  func refreshIfNeeded() async {
    guard !hasLoaded else { return }
    await refresh()
  }

  func refresh() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      models = try await client.models()
      hasLoaded = true
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }
}
