import Foundation

public struct TypingSessionTracker: Sendable {
	public struct Snapshot: Equatable, Sendable {
		public var appBundleID: String?
		public var text: String

		public init(appBundleID: String?, text: String) {
			self.appBundleID = appBundleID
			self.text = text
		}

		public var isTracking: Bool {
			!text.isEmpty
		}
	}

	public enum Event: Equatable, Sendable {
		case trackingStarted(appBundleID: String?)
		case textUpdated(text: String, appBundleID: String?)
		case submitted(text: String, appBundleID: String?)
		case canceled(text: String, appBundleID: String?)
	}

	public private(set) var snapshot: Snapshot

	public init() {
		snapshot = Snapshot(appBundleID: nil, text: "")
	}

	/// Placeholder implementation for test-first development.
	/// The red-phase tests define the desired behavior.
	public mutating func process(keyEvent: KeyEvent, appBundleID: String?) -> [Event] {
		[]
	}

	/// Placeholder implementation for test-first development.
	/// The red-phase tests define the desired behavior.
	public mutating func appDidChange(to appBundleID: String?) -> [Event] {
		[]
	}
}
