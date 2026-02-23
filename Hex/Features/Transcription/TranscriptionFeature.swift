import HexCore
import Inject
import SwiftUI

// MARK: - View

struct TranscriptionView: View {
	var store: TranscriptionStore
	var alwaysOnListening: Bool = false
	@ObserveInjection var inject

	var status: TranscriptionIndicatorView.Status {
		if alwaysOnListening {
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

	var body: some View {
		TranscriptionIndicatorView(
			status: status,
			meter: store.meter
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
			alwaysOnListening: alwaysOnStore.isListening
		)
	}
}
