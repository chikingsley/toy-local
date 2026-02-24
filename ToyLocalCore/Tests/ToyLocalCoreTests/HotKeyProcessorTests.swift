//
//  HotKeyProcessorTests.swift
//  ToyLocalCoreTests
//
//  Created by Kit Langton on 1/27/25.
//

import Foundation
@testable import ToyLocalCore
import Sauce
import Testing

struct HotKeyProcessorTests {
    // MARK: - Standard HotKey (key + modifiers) Tests

    // Tests a single key press that matches the hotkey
    @Test
    func pressAndHold_startsRecordingOnHotkey_standard() throws {
        runScenario(
            hotkey: HotKey(key: .a, modifiers: [.command]),
            steps: [
                ScenarioStep(time: 0.0, key: .a, modifiers: [.command], expectedOutput: .startRecording, expectedIsMatched: true)
            ]
        )
    }

    @Test
    func pressAndHold_startsRecordingOnHotkey_modifierOnly() throws {
        runScenario(
            hotkey: HotKey(key: nil, modifiers: [.option]),
            steps: [
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: .startRecording, expectedIsMatched: true)
            ]
        )
    }

    // Tests releasing the hotkey stops recording
    @Test
    func pressAndHold_stopsRecordingOnHotkeyRelease_standard() throws {
        runScenario(
            hotkey: HotKey(key: .a, modifiers: [.command]),
            steps: [
                ScenarioStep(time: 0.0, key: .a, modifiers: [.command], expectedOutput: .startRecording, expectedIsMatched: true),
                ScenarioStep(time: 0.2, key: nil, modifiers: [.command], expectedOutput: .stopRecording, expectedIsMatched: false)
            ]
        )
    }

    @Test
    func pressAndHold_stopsRecordingOnHotkeyRelease_modifierOnly() throws {
        runScenario(
            hotkey: HotKey(key: nil, modifiers: [.option]),
            steps: [
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: .startRecording, expectedIsMatched: true),
                ScenarioStep(time: 0.2, key: nil, modifiers: [], expectedOutput: .stopRecording, expectedIsMatched: false)
            ]
        )
    }

    @Test
    func pressAndHold_stopsRecordingOnHotkeyRelease_multipleModifiers() throws {
        runScenario(
            hotkey: HotKey(key: nil, modifiers: [.option, .command]),
            steps: [
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: nil, expectedIsMatched: false),
                ScenarioStep(time: 0.1, key: nil, modifiers: [.option, .command], expectedOutput: .startRecording, expectedIsMatched: true),
                ScenarioStep(time: 0.2, key: nil, modifiers: [], expectedOutput: .stopRecording, expectedIsMatched: false)
            ]
        )
    }

    @Test
    func pressAndHold_releasingModifierBeforeKeyStillStops() throws {
        runScenario(
            hotkey: HotKey(key: .u, modifiers: [.option]),
            steps: [
                // Press modifier first (Option)
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: nil, expectedIsMatched: false),
                // Then press the key to start recording
                ScenarioStep(time: 0.05, key: .u, modifiers: [.option], expectedOutput: .startRecording, expectedIsMatched: true),
                // Release the modifier while holding the key
                ScenarioStep(time: 1.5, key: .u, modifiers: [], expectedOutput: nil, expectedIsMatched: true),
                // Release the key a beat later — should stop recording automatically
                ScenarioStep(time: 1.55, key: nil, modifiers: [], expectedOutput: .stopRecording, expectedIsMatched: false)
            ]
        )
    }

    // Tests pressing a different key cancels recording
    @Test
    func pressAndHold_cancelsOnOtherKeyPress_standard() throws {
        runScenario(
            hotkey: HotKey(key: .a, modifiers: [.command]),
            steps: [
                // Initial hotkey press
                ScenarioStep(time: 0.0, key: .a, modifiers: [.command], expectedOutput: .startRecording, expectedIsMatched: true),
                // Different key press within cancel threshold
                ScenarioStep(time: 0.5, key: .b, modifiers: [.command], expectedOutput: .stopRecording, expectedIsMatched: false)
            ]
        )
    }

    // For modifier-only hotkeys, extra modifiers after threshold are ignored
    @Test
    func pressAndHold_ignoresExtraModifierAfterThreshold_modifierOnly() throws {
        runScenario(
            hotkey: HotKey(key: nil, modifiers: [.option]),
            steps: [
                // Initial hotkey press (option)
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: .startRecording, expectedIsMatched: true),
                // Press a different modifier after threshold (0.5s > 0.3s) - should be ignored
                ScenarioStep(time: 0.5, key: nil, modifiers: [.option, .command], expectedOutput: nil, expectedIsMatched: true)
            ]
        )
    }

    // Tests that pressing a different key after threshold doesn't cancel
    @Test
    func pressAndHold_doesNotCancelAfterThreshold_standard() throws {
        runScenario(
            hotkey: HotKey(key: .a, modifiers: [.command]),
            steps: [
                // Initial hotkey press
                ScenarioStep(time: 0.0, key: .a, modifiers: [.command], expectedOutput: .startRecording, expectedIsMatched: true),
                // Different key press after cancel threshold
                ScenarioStep(time: 1.5, key: .b, modifiers: [.command], expectedOutput: nil, expectedIsMatched: true)
            ]
        )
    }

    @Test
    func pressAndHold_doesNotCancelAfterThreshold_modifierOnly() throws {
        runScenario(
            hotkey: HotKey(key: nil, modifiers: [.option]),
            steps: [
                // Initial hotkey press
                ScenarioStep(time: 0.0, key: nil, modifiers: [.option], expectedOutput: .startRecording, expectedIsMatched: true),
                // Different modifier press after cancel threshold
                ScenarioStep(time: 1.5, key: nil, modifiers: [.option, .command], expectedOutput: nil, expectedIsMatched: true)
            ]
        )
    }

    // The user cannot "backslide" into pressing the hotkey. If the user is chording extra modifiers,
    // everything must be released before a hotkey can trigger
    @Test
    func pressAndHold_doesNotTriggerOnBackslide_standard() throws {
        runScenario(
            hotkey: HotKey(key: .a, modifiers: [.command]),
            steps: [
                // They press the hotkey with an extra modifier
                ScenarioStep(time: 0.0, key: .a, modifiers: [.command, .shift], expectedOutput: nil, expectedIsMatched: false),
                // And then release the extra modifier, nothing should happen
                ScenarioStep(time: 0.1, key: .a, modifiers: [.command], expectedOutput: nil, expectedIsMatched: false),
                // Then if they release everything, the hotkey should trigger
                ScenarioStep(time: 0.2, key: nil, modifiers: [], expectedOutput: nil, expectedIsMatched: false),
                // And try to press the hotkey again, it should start recording
                ScenarioStep(time: 0.3, key: .a, modifiers: [.command], expectedOutput: .startRecording, expectedIsMatched: true)
            ]
        )
    }

}

struct ScenarioStep {
    /// The time offset (in seconds) relative to the scenario start.
    let time: TimeInterval

    /// Which key (if any) is pressed in this chord
    let key: Key?

    /// Which modifiers are held in this chord
    let modifiers: Modifiers

    /// The expected output from `processor.process(...)` at this step,
    /// or `nil` if we expect no output.
    let expectedOutput: HotKeyProcessor.Output?

    /// Whether we expect `processor.isMatched` after this step, or `nil` if we don't care.
    let expectedIsMatched: Bool?

    /// If we want to check the processor's exact `state`.
    /// This is optional; if `nil` we won't check it.
    let expectedState: HotKeyProcessor.State?

    init(
        time: TimeInterval,
        key: Key? = nil,
        modifiers: Modifiers = [],
        expectedOutput: HotKeyProcessor.Output? = nil,
        expectedIsMatched: Bool? = nil,
        expectedState: HotKeyProcessor.State? = nil
    ) {
        self.time = time
        self.key = key
        self.modifiers = modifiers
        self.expectedOutput = expectedOutput
        self.expectedIsMatched = expectedIsMatched
        self.expectedState = expectedState
    }
}

func runScenario(
    hotkey: HotKey,
    steps: [ScenarioStep]
) {
    // Sort steps by time, just in case they're not in ascending order
    let sortedSteps = steps.sorted { $0.time < $1.time }

    // We'll keep track of the "current time" as we simulate
    var currentTime: TimeInterval = 0

    // Create the processor with an initial date
    var processor = HotKeyProcessor(hotkey: hotkey)
    processor.now = { Date(timeIntervalSince1970: currentTime) }

    // We'll step through each event
    for step in sortedSteps {
        currentTime = step.time

        // Build a KeyEvent from step's chord
        let keyEvent = KeyEvent(key: step.key, modifiers: step.modifiers)

        // Process
        let actualOutput = processor.process(keyEvent: keyEvent)

        // If step.expectedOutput != nil, #expect that it matches actualOutput
        if let expected = step.expectedOutput {
            #expect(
                actualOutput == expected,
                "\(step.time)s: expected output \(expected), got \(String(describing: actualOutput))"
            )
        } else {
            // We expect no output
            #expect(
                actualOutput == nil,
                "\(step.time)s: expected no output, got \(String(describing: actualOutput))"
            )
        }

        // If step.expectedIsMatched != nil, #expect that it matches processor.isMatched
        if let expMatch = step.expectedIsMatched {
            #expect(
                processor.isMatched == expMatch,
                "\(step.time)s: expected isMatched=\(expMatch), got \(processor.isMatched)"
            )
        }

        // If we want to test the entire state:
        if let expState = step.expectedState {
            #expect(
                processor.state == expState,
                "\(step.time)s: expected state=\(expState), got \(processor.state)"
            )
        }
    }
}

// MARK: - Recording Decision Tests

struct RecordingDecisionTests {
    private func makeContext(
        hotkey: HotKey,
        minimumKeyTime: TimeInterval = 0.2,
        duration: TimeInterval?
    ) -> RecordingDecisionEngine.Context {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let start = duration.map { now.addingTimeInterval(-$0) }
        return RecordingDecisionEngine.Context(
            hotkey: hotkey,
            minimumKeyTime: minimumKeyTime,
            recordingStartTime: start,
            currentTime: now
        )
    }

    @Test
    func modifierOnlyShortPressIsDiscarded() {
        let ctx = makeContext(hotkey: HotKey(key: nil, modifiers: [.command]), duration: 0.1)
        #expect(RecordingDecisionEngine.decide(ctx) == .discardShortRecording)
    }

    @Test
    func printableKeyShortPressStillProceeds() {
        let ctx = makeContext(hotkey: HotKey(key: .quote, modifiers: [.command]), duration: 0.1)
        #expect(RecordingDecisionEngine.decide(ctx) == .proceedToTranscription)
    }

    @Test
    func longPressModifierOnlyProceeds() {
        // Duration at modifierOnlyMinimumDuration threshold (0.3s)
        let ctx = makeContext(hotkey: HotKey(key: nil, modifiers: [.option]), duration: 0.3)
        #expect(RecordingDecisionEngine.decide(ctx) == .proceedToTranscription)
    }

    @Test
    func missingStartTimeDefaultsToShort() {
        let ctx = RecordingDecisionEngine.Context(
            hotkey: HotKey(key: nil, modifiers: [.option]),
            minimumKeyTime: 0.2,
            recordingStartTime: nil,
            currentTime: Date(timeIntervalSinceReferenceDate: 0)
        )
        #expect(RecordingDecisionEngine.decide(ctx) == .discardShortRecording)
    }

    // MARK: - Modifier-Only Minimum Duration Tests

    @Test
    func modifierOnly_enforcesMinimumDuration_0_3s() {
        // User sets minimumKeyTime to 0.1s, but modifier-only enforces modifierOnlyMinimumDuration (0.3s)
        let ctx = makeContext(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.1, duration: 0.25)
        #expect(RecordingDecisionEngine.decide(ctx) == .discardShortRecording)
    }

    @Test
    func modifierOnly_proceedsWhenAboveMinimumDuration() {
        // User sets minimumKeyTime to 0.1s, recording is 0.35s (above modifierOnlyMinimumDuration)
        let ctx = makeContext(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.1, duration: 0.35)
        #expect(RecordingDecisionEngine.decide(ctx) == .proceedToTranscription)
    }

    @Test
    func modifierOnly_respectsUserPreferenceWhenHigher() {
        // User sets minimumKeyTime to 0.5s (higher than modifierOnlyMinimumDuration)
        let ctx = makeContext(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.5, duration: 0.4)
        #expect(RecordingDecisionEngine.decide(ctx) == .discardShortRecording)
    }

    @Test
    func printableKey_doesNotEnforceModifierOnlyMinimum() {
        // Printable key hotkeys use user's minimumKeyTime, not modifierOnlyMinimumDuration
        let ctx = makeContext(hotkey: HotKey(key: .a, modifiers: [.command]), minimumKeyTime: 0.1, duration: 0.15)
        #expect(RecordingDecisionEngine.decide(ctx) == .proceedToTranscription)
    }
}

// MARK: - Mouse Click Tests

struct MouseClickTests {
    @Test
    func mouseClick_discardsQuickModifierOnlyRecording() throws {
        var currentTime: TimeInterval = 0
        var processor = HotKeyProcessor(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.15)
        processor.now = { Date(timeIntervalSince1970: currentTime) }

        // Start recording with modifier-only hotkey
        currentTime = 0
        let startOutput = processor.process(keyEvent: KeyEvent(key: nil, modifiers: [.option]))
        #expect(startOutput == .startRecording)

        // Mouse click 0.25s later (< 0.3s threshold for modifier-only) should discard silently
        currentTime = 0.25
        let clickOutput = processor.processMouseClick()
        #expect(clickOutput == .discard)
    }

    @Test
    func mouseClick_ignoredAfterThreshold() throws {
        var currentTime: TimeInterval = 0
        var processor = HotKeyProcessor(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.15)
        processor.now = { Date(timeIntervalSince1970: currentTime) }

        // Start recording with modifier-only hotkey
        currentTime = 0
        let startOutput = processor.process(keyEvent: KeyEvent(key: nil, modifiers: [.option]))
        #expect(startOutput == .startRecording)

        // Mouse click 0.35s later (> 0.3s threshold) should be ignored - only ESC cancels
        currentTime = 0.35
        let clickOutput = processor.processMouseClick()
        #expect(clickOutput == nil)
    }

    @Test
    func mouseClick_ignoredInDoubleTapLock() throws {
        var currentTime: TimeInterval = 0
        var processor = HotKeyProcessor(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.15)
        processor.now = { Date(timeIntervalSince1970: currentTime) }

        // First tap
        currentTime = 0
        _ = processor.process(keyEvent: KeyEvent(key: nil, modifiers: [.option]))
        currentTime = 0.2
        _ = processor.process(keyEvent: KeyEvent(key: nil, modifiers: []))

        // Second tap within threshold - should lock
        currentTime = 0.4
        _ = processor.process(keyEvent: KeyEvent(key: nil, modifiers: [.option]))
        currentTime = 0.5
        _ = processor.process(keyEvent: KeyEvent(key: nil, modifiers: []))

        // Should be in double-tap lock now
        #expect(processor.state == .doubleTapLock)

        // Mouse click should be ignored - only ESC cancels locked recordings
        currentTime = 0.6
        let clickOutput = processor.processMouseClick()
        #expect(clickOutput == nil)
    }

    @Test
    func mouseClick_ignoresKeyPlusModifierHotkey() throws {
        var currentTime: TimeInterval = 0
        var processor = HotKeyProcessor(hotkey: HotKey(key: .a, modifiers: [.command]), minimumKeyTime: 0.15)
        processor.now = { Date(timeIntervalSince1970: currentTime) }

        // Start recording with key+modifier hotkey
        currentTime = 0
        let startOutput = processor.process(keyEvent: KeyEvent(key: .a, modifiers: [.command]))
        #expect(startOutput == .startRecording)

        // Mouse click should be ignored for key+modifier hotkeys
        currentTime = 0.1
        let clickOutput = processor.processMouseClick()
        #expect(clickOutput == nil)
    }

    @Test
    func mouseClick_respectsHigherUserPreference() throws {
        var currentTime: TimeInterval = 0
        var processor = HotKeyProcessor(hotkey: HotKey(key: nil, modifiers: [.option]), minimumKeyTime: 0.5)
        processor.now = { Date(timeIntervalSince1970: currentTime) }

        // Start recording with modifier-only hotkey
        currentTime = 0
        let startOutput = processor.process(keyEvent: KeyEvent(key: nil, modifiers: [.option]))
        #expect(startOutput == .startRecording)

        // Mouse click 0.4s later (> 0.3s but < 0.5s user preference) should still discard
        currentTime = 0.4
        let clickOutput = processor.processMouseClick()
        #expect(clickOutput == .discard)
    }
}
