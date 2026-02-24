import SwiftUI
import AppKit
import ToyLocalCore
import Sauce

struct MenuBarCopyLastTranscriptButton: View {
	let store: AppStore
	private static let namedKeyEquivalents: [Key: KeyEquivalent] = [
		.one: "1",
		.two: "2",
		.three: "3",
		.four: "4",
		.five: "5",
		.six: "6",
		.seven: "7",
		.eight: "8",
		.nine: "9",
		.zero: "0",
		.comma: ",",
		.period: ".",
		.slash: "/",
		.backslash: "\\",
		.quote: "'",
		.semicolon: ";",
		.leftBracket: "[",
		.rightBracket: "]",
		.minus: "-",
		.equal: "=",
		.grave: "`"
	]

	var body: some View {
		let lastText = store.settings.transcriptionHistory.history.first?.text
		let preview: String = {
			guard let text = lastText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return "" }
			let snippet = text.prefix(40)
			return "\(snippet)\(text.count > 40 ? "..." : "")"
		}()

		let button = Button(action: {
			if lastText != nil {
				store.pasteLastTranscript()
			}
		}, label: {
			HStack(spacing: 6) {
				Text("Paste Last Transcript")
				if !preview.isEmpty {
					Text("(\(preview))")
						.foregroundStyle(.secondary)
				}
			}
		})
		.disabled(lastText == nil)

		let hexSettings = store.settings.hexSettings
		if let hotkey = hexSettings.pasteLastTranscriptHotkey,
		   let key = hotkey.key,
		   let keyEquivalent = toKeyEquivalent(key) {
			button.keyboardShortcut(keyEquivalent, modifiers: toEventModifiers(hotkey.modifiers))
		} else {
			button
		}
	}

	private func toKeyEquivalent(_ key: Key) -> KeyEquivalent? {
		if let mapped = Self.namedKeyEquivalents[key] {
			return mapped
		}

		guard key.rawValue.count == 1, let character = key.rawValue.first else {
			return nil
		}

		return KeyEquivalent(character)
	}

	private func toEventModifiers(_ modifiers: Modifiers) -> SwiftUI.EventModifiers {
		var result: SwiftUI.EventModifiers = []
		if modifiers.contains(kind: .command) { result.insert(.command) }
		if modifiers.contains(kind: .option) { result.insert(.option) }
		if modifiers.contains(kind: .shift) { result.insert(.shift) }
		if modifiers.contains(kind: .control) { result.insert(.control) }
		return result
	}
}
