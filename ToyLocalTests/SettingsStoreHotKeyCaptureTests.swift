import Sauce
import ToyLocalCore
import XCTest

@testable import toy_local

@MainActor
final class SettingsStoreHotKeyCaptureTests: XCTestCase {
  func testMainHotKeyCaptureStoresKeyAndModifiers() {
    let store = makeStore()
    store.toyLocalSettings.hotkey = HotKey(key: nil, modifiers: [])

    store.startSettingHotKey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
    store.handleKeyEvent(KeyEvent(key: .k, modifiers: [.command]))

    XCTAssertFalse(store.isSettingHotKey)
    XCTAssertTrue(store.currentModifiers.isEmpty)
    XCTAssertEqual(store.toyLocalSettings.hotkey.key, .k)
    XCTAssertTrue(store.toyLocalSettings.hotkey.modifiers.matchesExactly([.command]))
  }

  func testMainHotKeyCaptureSupportsModifierOnlyHotKey() {
    let store = makeStore()
    store.toyLocalSettings.hotkey = HotKey(key: .k, modifiers: [.command])

    store.startSettingHotKey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.option]))
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: []))

    XCTAssertFalse(store.isSettingHotKey)
    XCTAssertTrue(store.currentModifiers.isEmpty)
    XCTAssertNil(store.toyLocalSettings.hotkey.key)
    XCTAssertTrue(store.toyLocalSettings.hotkey.modifiers.matchesExactly([.option]))
  }

  func testPasteHotKeyCaptureRequiresModifierBeforeKey() {
    let store = makeStore()
    store.toyLocalSettings.pasteLastTranscriptHotkey = nil

    store.startSettingPasteLastTranscriptHotkey()
    store.handleKeyEvent(KeyEvent(key: .v, modifiers: []))

    XCTAssertNil(store.toyLocalSettings.pasteLastTranscriptHotkey)
    XCTAssertTrue(store.isSettingPasteLastTranscriptHotkey)

    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
    store.handleKeyEvent(KeyEvent(key: .v, modifiers: [.command]))

    XCTAssertFalse(store.isSettingPasteLastTranscriptHotkey)
    XCTAssertTrue(store.currentPasteLastModifiers.isEmpty)
    XCTAssertEqual(store.toyLocalSettings.pasteLastTranscriptHotkey?.key, .v)
    XCTAssertTrue(store.toyLocalSettings.pasteLastTranscriptHotkey?.modifiers.matchesExactly([.command]) == true)
  }

  func testPasteHotKeyCaptureEscapeCancelsMode() {
    let store = makeStore()

    store.startSettingPasteLastTranscriptHotkey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.option]))
    store.handleKeyEvent(KeyEvent(key: .escape, modifiers: []))

    XCTAssertFalse(store.isSettingPasteLastTranscriptHotkey)
    XCTAssertTrue(store.currentPasteLastModifiers.isEmpty)
  }

  func testAlwaysOnPasteCaptureSupportsModifierOnlyHotKey() {
    let store = makeStore()
    store.toyLocalSettings.alwaysOnPasteHotkey = nil

    store.startSettingAlwaysOnPasteHotkey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.fn]))
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: []))

    XCTAssertFalse(store.isSettingAlwaysOnPasteHotkey)
    XCTAssertTrue(store.currentAlwaysOnPasteModifiers.isEmpty)
    XCTAssertNil(store.toyLocalSettings.alwaysOnPasteHotkey?.key)
    XCTAssertTrue(store.toyLocalSettings.alwaysOnPasteHotkey?.modifiers.matchesExactly([.fn]) == true)
  }

  func testAlwaysOnDumpCaptureStoresKeyAndModifiers() {
    let store = makeStore()
    store.toyLocalSettings.alwaysOnDumpHotkey = nil

    store.startSettingAlwaysOnDumpHotkey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.control, .option]))
    store.handleKeyEvent(KeyEvent(key: .d, modifiers: [.control, .option]))

    XCTAssertFalse(store.isSettingAlwaysOnDumpHotkey)
    XCTAssertTrue(store.currentAlwaysOnDumpModifiers.isEmpty)
    XCTAssertEqual(store.toyLocalSettings.alwaysOnDumpHotkey?.key, .d)
    XCTAssertTrue(store.toyLocalSettings.alwaysOnDumpHotkey?.modifiers.matchesExactly([.control, .option]) == true)
  }

  func testAnyHotKeyCaptureTracksAllCaptureModes() {
    let store = makeStore()

    XCTAssertFalse(store.isSettingAnyHotKey)
    store.startSettingPasteLastTranscriptHotkey()
    XCTAssertTrue(store.isSettingAnyHotKey)
    store.handleKeyEvent(KeyEvent(key: .escape, modifiers: []))
    XCTAssertFalse(store.isSettingAnyHotKey)
  }

  private func makeStore() -> SettingsStore {
    SettingsStore(services: ServiceContainer())
  }
}
