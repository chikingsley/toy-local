import Sauce
import TimberVoxCore
import XCTest

@testable import TimberVox

@MainActor
final class SettingsStoreHotKeyCaptureTests: XCTestCase {
  func testMainHotKeyCaptureStoresKeyAndModifiers() {
    let store = makeStore()
    store.timberVoxSettings.hotkey = HotKey(key: nil, modifiers: [])

    store.startSettingHotKey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
    store.handleKeyEvent(KeyEvent(key: .k, modifiers: [.command]))

    XCTAssertFalse(store.isSettingHotKey)
    XCTAssertTrue(store.currentModifiers.isEmpty)
    XCTAssertEqual(store.timberVoxSettings.hotkey.key, .k)
    XCTAssertTrue(store.timberVoxSettings.hotkey.modifiers.matchesExactly([.command]))
  }

  func testMainHotKeyCaptureSupportsModifierOnlyHotKey() {
    let store = makeStore()
    store.timberVoxSettings.hotkey = HotKey(key: .k, modifiers: [.command])

    store.startSettingHotKey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.option]))
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: []))

    XCTAssertFalse(store.isSettingHotKey)
    XCTAssertTrue(store.currentModifiers.isEmpty)
    XCTAssertNil(store.timberVoxSettings.hotkey.key)
    XCTAssertTrue(store.timberVoxSettings.hotkey.modifiers.matchesExactly([.option]))
  }

  func testPasteHotKeyCaptureRequiresModifierBeforeKey() {
    let store = makeStore()
    store.timberVoxSettings.pasteLastTranscriptHotkey = nil

    store.startSettingPasteLastTranscriptHotkey()
    store.handleKeyEvent(KeyEvent(key: .v, modifiers: []))

    XCTAssertNil(store.timberVoxSettings.pasteLastTranscriptHotkey)
    XCTAssertTrue(store.isSettingPasteLastTranscriptHotkey)

    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.command]))
    store.handleKeyEvent(KeyEvent(key: .v, modifiers: [.command]))

    XCTAssertFalse(store.isSettingPasteLastTranscriptHotkey)
    XCTAssertTrue(store.currentPasteLastModifiers.isEmpty)
    XCTAssertEqual(store.timberVoxSettings.pasteLastTranscriptHotkey?.key, .v)
    XCTAssertTrue(store.timberVoxSettings.pasteLastTranscriptHotkey?.modifiers.matchesExactly([.command]) == true)
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
    store.timberVoxSettings.alwaysOnPasteHotkey = nil

    store.startSettingAlwaysOnPasteHotkey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.fn]))
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: []))

    XCTAssertFalse(store.isSettingAlwaysOnPasteHotkey)
    XCTAssertTrue(store.currentAlwaysOnPasteModifiers.isEmpty)
    XCTAssertNil(store.timberVoxSettings.alwaysOnPasteHotkey?.key)
    XCTAssertTrue(store.timberVoxSettings.alwaysOnPasteHotkey?.modifiers.matchesExactly([.fn]) == true)
  }

  func testAlwaysOnDumpCaptureStoresKeyAndModifiers() {
    let store = makeStore()
    store.timberVoxSettings.alwaysOnDumpHotkey = nil

    store.startSettingAlwaysOnDumpHotkey()
    store.handleKeyEvent(KeyEvent(key: nil, modifiers: [.control, .option]))
    store.handleKeyEvent(KeyEvent(key: .d, modifiers: [.control, .option]))

    XCTAssertFalse(store.isSettingAlwaysOnDumpHotkey)
    XCTAssertTrue(store.currentAlwaysOnDumpModifiers.isEmpty)
    XCTAssertEqual(store.timberVoxSettings.alwaysOnDumpHotkey?.key, .d)
    XCTAssertTrue(store.timberVoxSettings.alwaysOnDumpHotkey?.modifiers.matchesExactly([.control, .option]) == true)
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
