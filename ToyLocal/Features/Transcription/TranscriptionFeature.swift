import ToyLocalCore
import Inject
import SwiftUI

// MARK: - View

struct TranscriptionView: View {
	var store: TranscriptionStore
	var alwaysOnStore: AlwaysOnStore?
	@ObserveInjection var inject

	var status: TranscriptionIndicatorView.Status {
		if alwaysOnStore?.isListening == true {
			return .alwaysOnListening
		} else if store.isTranscribing {
			return .transcribing
		} else if store.isRecording {
			return .recording
		} else if store.isPrewarming {
			return .prewarming
		} else {
			return .hidden
		}
	}

	/// Use the always-on meter when listening, otherwise the transcription meter.
	var activeMeter: Meter {
		if let alwaysOnStore, alwaysOnStore.isListening {
			return alwaysOnStore.meter
		}
		return store.meter
	}

	var body: some View {
		// Force observation of always-on state changes
		// swiftlint:disable:next redundant_discardable_let
		let _ = alwaysOnStore?.isListening
		// swiftlint:disable:next redundant_discardable_let
		let _ = alwaysOnStore?.meter

		TranscriptionIndicatorView(
			status: status,
			meter: activeMeter
		)
		.enableInjection()
	}
}

// MARK: - Indicator Host (combines TranscriptionView + AlwaysOn state)

/// Wraps TranscriptionView and passes always-on listening state for the indicator.
struct IndicatorHostView: View {
	let transcriptionStore: TranscriptionStore
	let alwaysOnStore: AlwaysOnStore

	var body: some View {
		TranscriptionView(
			store: transcriptionStore,
			alwaysOnStore: alwaysOnStore
		)
	}
}
