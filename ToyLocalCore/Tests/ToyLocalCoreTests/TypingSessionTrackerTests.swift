import Foundation
@testable import ToyLocalCore
import Testing

struct TypingSessionTrackerTests {
	@Test
	func startsTrackingAndAccumulatesPrintableKeys() {
		var tracker = TypingSessionTracker()

		let firstEvents = tracker.process(
			keyEvent: KeyEvent(key: .h, modifiers: []),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(
			firstEvents == [
				.trackingStarted(appBundleID: "com.apple.TextEdit"),
				.textUpdated(text: "h", appBundleID: "com.apple.TextEdit")
			]
		)

		let secondEvents = tracker.process(
			keyEvent: KeyEvent(key: .i, modifiers: []),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(
			secondEvents == [
				.textUpdated(text: "hi", appBundleID: "com.apple.TextEdit")
			]
		)
		#expect(tracker.snapshot == .init(appBundleID: "com.apple.TextEdit", text: "hi"))
	}

	@Test
	func returnSubmitsPromptAndResetsSession() {
		var tracker = TypingSessionTracker()
		_ = tracker.process(keyEvent: KeyEvent(key: .h, modifiers: []), appBundleID: "com.apple.TextEdit")
		_ = tracker.process(keyEvent: KeyEvent(key: .i, modifiers: []), appBundleID: "com.apple.TextEdit")

		let submitEvents = tracker.process(
			keyEvent: KeyEvent(key: .return, modifiers: []),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(
			submitEvents == [
				.submitted(text: "hi", appBundleID: "com.apple.TextEdit")
			]
		)
		#expect(tracker.snapshot == .init(appBundleID: nil, text: ""))
	}

	@Test
	func deleteRemovesLastCharacter() {
		var tracker = TypingSessionTracker()
		_ = tracker.process(keyEvent: KeyEvent(key: .h, modifiers: []), appBundleID: "com.apple.TextEdit")
		_ = tracker.process(keyEvent: KeyEvent(key: .i, modifiers: []), appBundleID: "com.apple.TextEdit")

		let deleteEvents = tracker.process(
			keyEvent: KeyEvent(key: .delete, modifiers: []),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(
			deleteEvents == [
				.textUpdated(text: "h", appBundleID: "com.apple.TextEdit")
			]
		)
		#expect(tracker.snapshot == .init(appBundleID: "com.apple.TextEdit", text: "h"))
	}

	@Test
	func escapeCancelsInProgressPrompt() {
		var tracker = TypingSessionTracker()
		_ = tracker.process(keyEvent: KeyEvent(key: .h, modifiers: []), appBundleID: "com.apple.TextEdit")
		_ = tracker.process(keyEvent: KeyEvent(key: .i, modifiers: []), appBundleID: "com.apple.TextEdit")

		let cancelEvents = tracker.process(
			keyEvent: KeyEvent(key: .escape, modifiers: []),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(
			cancelEvents == [
				.canceled(text: "hi", appBundleID: "com.apple.TextEdit")
			]
		)
		#expect(tracker.snapshot == .init(appBundleID: nil, text: ""))
	}

	@Test
	func appSwitchCancelsUnsubmittedPrompt() {
		var tracker = TypingSessionTracker()
		_ = tracker.process(keyEvent: KeyEvent(key: .h, modifiers: []), appBundleID: "com.apple.TextEdit")
		_ = tracker.process(keyEvent: KeyEvent(key: .i, modifiers: []), appBundleID: "com.apple.TextEdit")

		let appSwitchEvents = tracker.appDidChange(to: "com.apple.Terminal")

		#expect(
			appSwitchEvents == [
				.canceled(text: "hi", appBundleID: "com.apple.TextEdit")
			]
		)
		#expect(tracker.snapshot == .init(appBundleID: nil, text: ""))
	}

	@Test
	func commandChordDoesNotStartPromptTracking() {
		var tracker = TypingSessionTracker()

		let events = tracker.process(
			keyEvent: KeyEvent(key: .k, modifiers: [.command]),
			appBundleID: "com.apple.TextEdit"
		)

		#expect(events.isEmpty)
		#expect(tracker.snapshot == .init(appBundleID: nil, text: ""))
	}
}
