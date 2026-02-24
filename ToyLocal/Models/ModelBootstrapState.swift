import Foundation

struct ModelBootstrapState: Equatable {
	var isModelReady: Bool = true
	var progress: Double = 1
	var lastError: String?
	var modelIdentifier: String?
	var modelDisplayName: String?
}
