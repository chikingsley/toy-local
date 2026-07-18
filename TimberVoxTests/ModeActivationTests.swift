import XCTest

@testable import TimberVox

@MainActor
final class ModeActivationTests: XCTestCase {
  func testSourceApplicationSelectsMatchingModeAndFallsBackToActiveMode() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let appModeID = store.addMode()
    store.updateMode(id: appModeID) { mode in
      mode.activationBundleIdentifiers = ["com.apple.Notes"]
    }

    XCTAssertEqual(
      store.mode(forSourceApplicationBundleIdentifier: "com.apple.Notes").id,
      appModeID
    )
    XCTAssertEqual(
      store.mode(forSourceApplicationBundleIdentifier: "com.apple.Safari").id,
      store.activeModeID
    )
    XCTAssertEqual(store.mode(forSourceApplicationBundleIdentifier: nil).id, store.activeModeID)
  }

  func testActivationBundleIdentifiersPersistAcrossStoreReloads() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let appModeID = store.addMode()
    store.updateMode(id: appModeID) { mode in
      mode.activationBundleIdentifiers = ["com.apple.Notes", "com.apple.Safari"]
    }

    let reloadedStore = ModeStore(defaults: defaults)

    XCTAssertEqual(
      reloadedStore.mode(id: appModeID)?.activationBundleIdentifiers,
      ["com.apple.Notes", "com.apple.Safari"]
    )
  }

  func testActiveModePersistsAcrossStoreReloads() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let selectedModeID = store.addMode()

    store.activeModeID = selectedModeID

    XCTAssertEqual(ModeStore(defaults: defaults).activeModeID, selectedModeID)
  }

  func testDuplicateCopiesEditableConfigurationWithoutBecomingActive() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let sourceID = store.addMode()
    store.updateMode(id: sourceID) { mode in
      mode.name = "Support reply"
      mode.nameIsCustomized = true
      mode.iconSystemName = "bubble.left.fill"
      mode.activationBundleIdentifiers = ["com.apple.Mail"]
      mode.audioModelID = "scribe-v2"
      mode.languageCode = "en"
      mode.realtimeEnabled = true
      mode.diarizationEnabled = true
      mode.includesSystemAudio = true
      mode.playbackPolicy = .mute
      mode.textTransformPreset = .custom
      mode.textTransformModelID = "gemini-2.5-flash"
      mode.customTextTransformInstructions = "Write a concise reply."
      mode.textTransformContextOptions = .allAvailable
    }
    store.activeModeID = sourceID

    let duplicateID = store.duplicateMode(id: sourceID)
    let source = try XCTUnwrap(store.mode(id: sourceID))
    let duplicate = try XCTUnwrap(store.mode(id: duplicateID))

    XCTAssertEqual(duplicate.name, "Support reply Copy")
    XCTAssertNotEqual(duplicate.id, source.id)
    XCTAssertEqual(duplicate.iconSystemName, source.iconSystemName)
    XCTAssertEqual(duplicate.activationBundleIdentifiers, source.activationBundleIdentifiers)
    XCTAssertEqual(duplicate.audioModelID, source.audioModelID)
    XCTAssertEqual(duplicate.languageCode, source.languageCode)
    XCTAssertEqual(duplicate.realtimeEnabled, source.realtimeEnabled)
    XCTAssertEqual(duplicate.diarizationEnabled, source.diarizationEnabled)
    XCTAssertEqual(duplicate.includesSystemAudio, source.includesSystemAudio)
    XCTAssertEqual(duplicate.playbackPolicy, source.playbackPolicy)
    XCTAssertEqual(duplicate.textTransformPreset, source.textTransformPreset)
    XCTAssertEqual(duplicate.textTransformModelID, source.textTransformModelID)
    XCTAssertEqual(
      duplicate.customTextTransformInstructions,
      source.customTextTransformInstructions
    )
    XCTAssertEqual(duplicate.textTransformContextOptions, source.textTransformContextOptions)
    XCTAssertEqual(store.activeModeID, sourceID)
  }

  func testDeletingActiveModeSelectsRemainingModeAndPersists() throws {
    let defaults = try makeDefaults()
    let store = ModeStore(defaults: defaults)
    let activeID = store.addMode()
    store.activeModeID = activeID

    store.deleteMode(id: activeID)

    XCTAssertNil(store.mode(id: activeID))
    XCTAssertEqual(store.activeModeID, store.modes.first?.id)
    XCTAssertEqual(ModeStore(defaults: defaults).activeModeID, store.activeModeID)
  }

  func testLegacyModeWithoutActivationIdentifiersDecodesWithEmptySelection() throws {
    let mode = DictationMode.defaultMode()
    let encoded = try JSONEncoder().encode(mode)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object.removeValue(forKey: "activationBundleIdentifiers")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(DictationMode.self, from: legacyData)

    XCTAssertTrue(decoded.activationBundleIdentifiers.isEmpty)
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "ModeActivationTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
