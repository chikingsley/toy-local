import Sauce
import ToyLocalCore
import XCTest
@testable import toy_local

@MainActor
final class SettingsStoreHotKeyCaptureTests: XCTestCase {
	func testMainHotKeyCaptureStoresKeyAndModifiers() {
		let store = makeStore()
		store.hexSettings.hotkey = HotKey(key: nil, modifiers: [])

		store.startSettingHotKey()
		store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
		store.handleKeyEvent(KeyEvent(key: .k, modifiers: [.command]))

		XCTAssertFalse(store.isSettingHotKey)
		XCTAssertTrue(store.currentModifiers.isEmpty)
		XCTAssertEqual(store.hexSettings.hotkey.key, .k)
		XCTAssertTrue(store.hexSettings.hotkey.modifiers.matchesExactly([.command]))
	}

	func testMainHotKeyCaptureSupportsModifierOnlyHotKey() {
		let store = makeStore()
		store.hexSettings.hotkey = HotKey(key: .k, modifiers: [.command])

		store.startSettingHotKey()
		store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.option]))
		store.handleKeyEvent(KeyEvent(key: nil, modifiers: []))

		XCTAssertFalse(store.isSettingHotKey)
		XCTAssertTrue(store.currentModifiers.isEmpty)
		XCTAssertNil(store.hexSettings.hotkey.key)
		XCTAssertTrue(store.hexSettings.hotkey.modifiers.matchesExactly([.option]))
	}

	func testPasteHotKeyCaptureRequiresModifierBeforeKey() {
		let store = makeStore()
		store.hexSettings.pasteLastTranscriptHotkey = nil

		store.startSettingPasteLastTranscriptHotkey()
		store.handleKeyEvent(KeyEvent(key: .v, modifiers: []))

		XCTAssertNil(store.hexSettings.pasteLastTranscriptHotkey)
		XCTAssertTrue(store.isSettingPasteLastTranscriptHotkey)

		store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
		store.handleKeyEvent(KeyEvent(key: .v, modifiers: [.command]))

		XCTAssertFalse(store.isSettingPasteLastTranscriptHotkey)
		XCTAssertTrue(store.currentPasteLastModifiers.isEmpty)
		XCTAssertEqual(store.hexSettings.pasteLastTranscriptHotkey?.key, .v)
		XCTAssertTrue(store.hexSettings.pasteLastTranscriptHotkey?.modifiers.matchesExactly([.command]) == true)
	}

	func testPasteHotKeyCaptureEscapeCancelsMode() {
		let store = makeStore()

		store.startSettingPasteLastTranscriptHotkey()
		store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.option]))
		store.handleKeyEvent(KeyEvent(key: .escape, modifiers: []))

		XCTAssertFalse(store.isSettingPasteLastTranscriptHotkey)
		XCTAssertTrue(store.currentPasteLastModifiers.isEmpty)
	}

	private func makeStore() -> SettingsStore {
		SettingsStore(services: ServiceContainer())
	}
}
