import Foundation

/// Known Parakeet Core ML bundles that ToyLocal supports.
public enum ParakeetModel: String, CaseIterable, Sendable {
	case englishV2 = "parakeet-tdt-0.6b-v2-coreml"
	case multilingualV3 = "parakeet-tdt-0.6b-v3-coreml"
	case streamingEou160 = "parakeet-realtime-eou-120m-160ms-coreml"
	case streamingEou320 = "parakeet-realtime-eou-120m-320ms-coreml"

	/// The identifier used throughout the app (matches the on-disk folder name).
	public var identifier: String { rawValue }

	/// Whether this is a streaming (always-on) model rather than a batch model.
	public var isStreaming: Bool {
		switch self {
		case .streamingEou160, .streamingEou320: return true
		default: return false
		}
	}

	/// Whether the model only supports English transcription.
	public var isEnglishOnly: Bool {
		switch self {
		case .multilingualV3: return false
		default: return true
		}
	}

	/// Short capability label for UI copy.
	public var capabilityLabel: String {
		if isStreaming { return "English · Streaming" }
		return isEnglishOnly ? "English" : "Multilingual"
	}

	/// Convenience text for recommendation badges.
	public var recommendationLabel: String {
		if isStreaming { return "Always-On (English)" }
		return isEnglishOnly ? "Recommended (English)" : "Recommended (Multilingual)"
	}
}
