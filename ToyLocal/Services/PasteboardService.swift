import AppKit
import Foundation
import Sauce
import ToyLocalCore

private let pasteboardLogger = ToyLocalLog.pasteboard

@MainActor
struct PasteboardClientLive {
	let settingsManager: SettingsManager

	private var hexSettings: ToyLocalSettings { settingsManager.settings }

	private struct PasteboardSnapshot {
		let items: [[String: Any]]

		init(pasteboard: NSPasteboard) {
			var saved: [[String: Any]] = []
			for item in pasteboard.pasteboardItems ?? [] {
				var itemDict: [String: Any] = [:]
				for type in item.types {
					if let data = item.data(forType: type) {
						itemDict[type.rawValue] = data
					}
				}
				saved.append(itemDict)
			}
			self.items = saved
		}

		func restore(to pasteboard: NSPasteboard) {
			pasteboard.clearContents()
			for itemDict in items {
				let item = NSPasteboardItem()
				for (type, data) in itemDict {
					if let data = data as? Data {
						item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
					}
				}
				pasteboard.writeObjects([item])
			}
		}
	}

	@MainActor
	func paste(text: String) async -> Bool {
		if hexSettings.useClipboardPaste {
			return await pasteWithClipboard(text)
		} else {
			return insertTextWithAccessibility(text)
		}
	}

	@MainActor
	func copy(text: String) async {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)
	}

	@MainActor
	func sendKeyboardCommand(_ command: KeyboardCommand) async {
		guard ensurePostEventAccess(context: "send keyboard command", promptIfMissing: true) else {
			return
		}

		let source = CGEventSource(stateID: .combinedSessionState)

		// Convert modifiers to CGEventFlags and key codes for modifier keys
		var modifierKeyCodes: [CGKeyCode] = []
		var flags = CGEventFlags()

		for modifier in command.modifiers.sorted {
			switch modifier.kind {
			case .command:
				flags.insert(.maskCommand)
				modifierKeyCodes.append(55) // Left Cmd
			case .shift:
				flags.insert(.maskShift)
				modifierKeyCodes.append(56) // Left Shift
			case .option:
				flags.insert(.maskAlternate)
				modifierKeyCodes.append(58) // Left Option
			case .control:
				flags.insert(.maskControl)
				modifierKeyCodes.append(59) // Left Control
			case .fn:
				flags.insert(.maskSecondaryFn)
				// Fn key doesn't need explicit key down/up
			}
		}

		// Press modifiers down
		for keyCode in modifierKeyCodes {
			let modDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
			modDown?.post(tap: .cghidEventTap)
		}

		// Press main key if present
		if let key = command.key {
			let keyCode = Sauce.shared.keyCode(for: key)

			let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
			keyDown?.flags = flags
			keyDown?.post(tap: .cghidEventTap)

			let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
			keyUp?.flags = flags
			keyUp?.post(tap: .cghidEventTap)
		}

		// Release modifiers in reverse order
		for keyCode in modifierKeyCodes.reversed() {
			let modUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
			modUp?.post(tap: .cghidEventTap)
		}

		pasteboardLogger.debug("Sent keyboard command: \(command.displayName)")
	}

	@MainActor
	func pasteWithClipboard(_ text: String) async -> Bool {
		let pasteboard = NSPasteboard.general
		let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
		let targetChangeCount = writeAndTrackChangeCount(pasteboard: pasteboard, text: text)
		_ = await waitForPasteboardCommit(targetChangeCount: targetChangeCount)
		let pasteSucceeded = await performPaste(text)

		// Only restore original pasteboard contents if:
		// 1. Copying to clipboard is disabled AND
		// 2. The paste operation succeeded
		if !hexSettings.copyToClipboard && pasteSucceeded {
			let savedSnapshot = snapshot
			Task { @MainActor in
				// Give slower apps a short window to read the plain-text entry
				// before we repopulate the clipboard with the user's previous rich data.
				try? await Task.sleep(for: .milliseconds(500))
				pasteboard.clearContents()
				savedSnapshot.restore(to: pasteboard)
			}
		}

		// If we failed to paste AND user doesn't want clipboard retention,
		// show a notification that text is available in clipboard
		if !pasteSucceeded && !hexSettings.copyToClipboard {
			// Keep the transcribed text in clipboard regardless of setting
			pasteboardLogger.notice("Paste operation failed; text remains in clipboard as fallback.")
		}

		return pasteSucceeded
	}

	@MainActor
	private func writeAndTrackChangeCount(pasteboard: NSPasteboard, text: String) -> Int {
		let before = pasteboard.changeCount
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)
		let after = pasteboard.changeCount
		if after == before {
			return after + 1
		}
		return after
	}

	@MainActor
	private func waitForPasteboardCommit(
		targetChangeCount: Int,
		timeout: Duration = .milliseconds(150),
		pollInterval: Duration = .milliseconds(5)
	) async -> Bool {
		guard targetChangeCount > NSPasteboard.general.changeCount else { return true }

		let deadline = ContinuousClock.now + timeout
		while ContinuousClock.now < deadline {
			if NSPasteboard.general.changeCount >= targetChangeCount {
				return true
			}
			try? await Task.sleep(for: pollInterval)
		}
		return false
	}

	// MARK: - Paste Orchestration

	@MainActor
	private enum PasteStrategy: CaseIterable {
		case cmdV
		case accessibility
	}

	@MainActor
	private func performPaste(_ text: String) async -> Bool {
		for strategy in PasteStrategy.allCases {
			let succeeded = await attemptPaste(text, using: strategy)
			if succeeded { return true }
		}
		return false
	}

	@MainActor
	private func attemptPaste(_ text: String, using strategy: PasteStrategy) async -> Bool {
		switch strategy {
		case .cmdV:
			return await postCmdV(delayMs: 0)
		case .accessibility:
			return (try? Self.insertTextAtCursor(text)) != nil
		}
	}

	// MARK: - Helpers

	@MainActor
	private func postCmdV(delayMs: Int) async -> Bool {
		guard ensurePostEventAccess(context: "paste command", promptIfMissing: false) else {
			return false
		}

		try? await wait(milliseconds: delayMs)
		let source = CGEventSource(stateID: .combinedSessionState)
		let vKey = vKeyCode()
		let cmdKey: CGKeyCode = 55
		let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
		let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
		vDown?.flags = .maskCommand
		let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
		vUp?.flags = .maskCommand
		let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)
		cmdDown?.post(tap: .cghidEventTap)
		vDown?.post(tap: .cghidEventTap)
		vUp?.post(tap: .cghidEventTap)
		cmdUp?.post(tap: .cghidEventTap)
		return true
	}

	@MainActor
	private func ensurePostEventAccess(context: String, promptIfMissing: Bool) -> Bool {
		if CGPreflightPostEventAccess() {
			return true
		}

		// Some environments report stale post-event preflight even after the user grants
		// Accessibility trust. Treat AX trust as sufficient for synthetic key posting.
		if isAccessibilityTrustedForAutomation() {
			pasteboardLogger.notice("Post-event preflight denied for \(context), but Accessibility is granted; continuing.")
			return true
		}

		guard promptIfMissing else {
			pasteboardLogger.notice("Event posting permission missing for \(context); skipping synthesized key events.")
			return false
		}

		let granted = CGRequestPostEventAccess()
		guard granted else {
			pasteboardLogger.error("Event posting permission denied for \(context); opening Accessibility settings.")
			openAccessibilitySettings()
			return false
		}

		return true
	}

	@MainActor
	private func isAccessibilityTrustedForAutomation() -> Bool {
		AXIsProcessTrusted()
	}

	@MainActor
	private func openAccessibilitySettings() {
		guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
			pasteboardLogger.error("Failed to construct Accessibility settings URL")
			return
		}
		NSWorkspace.shared.open(url)
	}

	@MainActor
	private func vKeyCode() -> CGKeyCode {
		if Thread.isMainThread { return Sauce.shared.keyCode(for: .v) }
		return DispatchQueue.main.sync { Sauce.shared.keyCode(for: .v) }
	}

	@MainActor
	private func wait(milliseconds: Int) async throws {
		try Task.checkCancellation()
		try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
	}

	@MainActor
	private func insertTextWithAccessibility(_ text: String) -> Bool {
		do {
			try Self.insertTextAtCursor(text)
			return true
		} catch {
			pasteboardLogger.notice("Accessibility insert failed for non-clipboard mode: \(String(describing: error))")
			return false
		}
	}

}

private extension PasteboardClientLive {
	enum PasteError: Error {
		case focusedElementNotFound
		case elementDoesNotSupportTextEditing
		case failedToInsertText
	}

	static func insertTextAtCursor(_ text: String) throws {
		let systemWideElement = AXUIElementCreateSystemWide()

		var focusedElementRef: CFTypeRef?
		let axError = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)
		guard axError == .success,
		      let focusedElementRef,
		      CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else {
			throw PasteError.focusedElementNotFound
		}

		let focusedElement = unsafeDowncast(focusedElementRef, to: AXUIElement.self)

		var value: CFTypeRef?
		let supportsText = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value) == .success
		let supportsSelectedText = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &value) == .success
		guard supportsText || supportsSelectedText else {
			throw PasteError.elementDoesNotSupportTextEditing
		}

		let insertResult = AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
		guard insertResult == .success else {
			throw PasteError.failedToInsertText
		}
	}
}
