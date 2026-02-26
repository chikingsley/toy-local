import Foundation
import Sauce

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

	public mutating func process(keyEvent: KeyEvent, appBundleID: String?) -> [Event] {
		guard let key = keyEvent.key else {
			return []
		}

		guard shouldTrack(keyEvent: keyEvent) else {
			return []
		}

		var events: [Event] = []

		if !snapshot.text.isEmpty,
		   let trackedApp = snapshot.appBundleID,
		   trackedApp != appBundleID {
			events.append(.canceled(text: snapshot.text, appBundleID: trackedApp))
			snapshot = Snapshot(appBundleID: nil, text: "")
		}

		switch key {
		case .return, .keypadEnter:
			guard !snapshot.text.isEmpty else {
				return events
			}
			let submittedText = snapshot.text
			let submittedApp = snapshot.appBundleID ?? appBundleID
			snapshot = Snapshot(appBundleID: nil, text: "")
			events.append(.submitted(text: submittedText, appBundleID: submittedApp))
			return events

		case .escape:
			guard !snapshot.text.isEmpty else {
				return events
			}
			let canceledText = snapshot.text
			let canceledApp = snapshot.appBundleID ?? appBundleID
			snapshot = Snapshot(appBundleID: nil, text: "")
			events.append(.canceled(text: canceledText, appBundleID: canceledApp))
			return events

		case .delete, .forwardDelete:
			guard !snapshot.text.isEmpty else {
				return events
			}
			snapshot.text.removeLast()
			if snapshot.text.isEmpty {
				snapshot = Snapshot(appBundleID: nil, text: "")
				return events
			}
			events.append(.textUpdated(text: snapshot.text, appBundleID: snapshot.appBundleID))
			return events

		default:
			guard let character = typedCharacter(for: key, modifiers: keyEvent.modifiers) else {
				return events
			}

			if snapshot.text.isEmpty {
				snapshot.appBundleID = appBundleID
				events.append(.trackingStarted(appBundleID: appBundleID))
			}

			snapshot.text.append(character)
			events.append(.textUpdated(text: snapshot.text, appBundleID: snapshot.appBundleID))
			return events
		}
	}

	public mutating func appDidChange(to appBundleID: String?) -> [Event] {
		guard !snapshot.text.isEmpty else {
			return []
		}

		guard snapshot.appBundleID != appBundleID else {
			return []
		}

		let canceledText = snapshot.text
		let canceledApp = snapshot.appBundleID
		snapshot = Snapshot(appBundleID: nil, text: "")
		return [.canceled(text: canceledText, appBundleID: canceledApp)]
	}
}

private extension TypingSessionTracker {
	func shouldTrack(keyEvent: KeyEvent) -> Bool {
		!keyEvent.modifiers.contains(kind: .command)
			&& !keyEvent.modifiers.contains(kind: .control)
			&& !keyEvent.modifiers.contains(kind: .option)
			&& !keyEvent.modifiers.contains(kind: .fn)
	}

	func typedCharacter(for key: Key, modifiers: Modifiers) -> Character? {
		if key == .space { return " " }
		if key == .tab { return "\t" }

		if let numeric = numericCharacter(for: key) {
			return numeric
		}

		let singleCharRawValue = key.rawValue
		guard singleCharRawValue.count == 1 else {
			return nil
		}

		let isShiftPressed = modifiers.contains(kind: .shift)
		let value = isShiftPressed ? singleCharRawValue.uppercased() : singleCharRawValue.lowercased()
		return value.first
	}

	func numericCharacter(for key: Key) -> Character? {
		switch key {
		case .zero, .keypadZero: return "0"
		case .one, .keypadOne: return "1"
		case .two, .keypadTwo: return "2"
		case .three, .keypadThree: return "3"
		case .four, .keypadFour: return "4"
		case .five, .keypadFive: return "5"
		case .six, .keypadSix: return "6"
		case .seven, .keypadSeven: return "7"
		case .eight, .keypadEight: return "8"
		case .nine, .keypadNine: return "9"
		default: return nil
		}
	}
}
