import HexCore
import Inject
import SwiftUI

// MARK: - Date Extensions

extension Date {
	func relativeFormatted() -> String {
		let calendar = Calendar.current
		let now = Date()

		if calendar.isDateInToday(self) {
			return "Today"
		} else if calendar.isDateInYesterday(self) {
			return "Yesterday"
		} else if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day, daysAgo < 7 {
			let formatter = DateFormatter()
			formatter.dateFormat = "EEEE"
			return formatter.string(from: self)
		} else {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			formatter.timeStyle = .none
			return formatter.string(from: self)
		}
	}
}

struct TranscriptView: View {
	let transcript: Transcript
	let isPlaying: Bool
	let onPlay: () -> Void
	let onCopy: () -> Void
	let onDelete: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(transcript.text)
				.font(.body)
				.lineLimit(nil)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.trailing, 40) // Space for buttons
				.padding(12)

			Divider()

			HStack {
				HStack(spacing: 6) {
					// App icon and name
					if let bundleID = transcript.sourceAppBundleID,
					   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
						Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
							.resizable()
							.frame(width: 14, height: 14)
						if let appName = transcript.sourceAppName {
							Text(appName)
						}
						Text("\u{2022}")
					}

					Image(systemName: "clock")
					Text(transcript.timestamp.relativeFormatted())
					Text("\u{2022}")
					Text(transcript.timestamp.formatted(date: .omitted, time: .shortened))
					Text("\u{2022}")
					Text(String(format: "%.1fs", transcript.duration))
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)

				Spacer()

				HStack(spacing: 10) {
					Button {
						onCopy()
						showCopyAnimation()
					} label: {
						HStack(spacing: 4) {
							Image(systemName: showCopied ? "checkmark" : "doc.on.doc.fill")
							if showCopied {
								Text("Copied").font(.caption)
							}
						}
					}
					.buttonStyle(.plain)
					.foregroundStyle(showCopied ? .green : .secondary)
					.help("Copy to clipboard")

					Button(action: onPlay) {
						Image(systemName: isPlaying ? "stop.fill" : "play.fill")
					}
					.buttonStyle(.plain)
					.foregroundStyle(isPlaying ? .blue : .secondary)
					.help(isPlaying ? "Stop playback" : "Play audio")

					Button(action: onDelete) {
						Image(systemName: "trash.fill")
					}
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
					.help("Delete transcript")
				}
				.font(.subheadline)
			}
			.frame(height: 20)
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
		}
		.background(
			RoundedRectangle(cornerRadius: 8)
				.fill(Color(.windowBackgroundColor).opacity(0.5))
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
				)
		)
		.onDisappear {
			// Clean up any running task when view disappears
			copyTask?.cancel()
		}
	}

	@State private var showCopied = false
	@State private var copyTask: Task<Void, Error>?

	private func showCopyAnimation() {
		copyTask?.cancel()

		copyTask = Task {
			withAnimation {
				showCopied = true
			}

			try await Task.sleep(for: .seconds(1.5))

			withAnimation {
				showCopied = false
			}
		}
	}
}

#Preview {
	TranscriptView(
		transcript: Transcript(timestamp: Date(), text: "Hello, world!", audioPath: URL(fileURLWithPath: "/Users/langton/Downloads/test.m4a"), duration: 1.0),
		isPlaying: false,
		onPlay: {},
		onCopy: {},
		onDelete: {}
	)
}

struct HistoryView: View {
	@ObserveInjection var inject
	var store: HistoryStore
	@State private var showingDeleteConfirmation = false

	var body: some View {
		Group {
			if !store.saveTranscriptionHistory {
				ContentUnavailableView {
					Label("History Disabled", systemImage: "clock.arrow.circlepath")
				} description: {
					Text("Transcription history is currently disabled.")
				} actions: {
					Button("Enable in Settings") {
						store.navigateToSettings()
					}
				}
			} else if store.transcriptionHistory.history.isEmpty {
				ContentUnavailableView {
					Label("No Transcriptions", systemImage: "text.bubble")
				} description: {
					Text("Your transcription history will appear here.")
				}
			} else {
				historyContent
			}
		}.enableInjection()
	}

	private var historyContent: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				ForEach(store.transcriptionHistory.history) { transcript in
					TranscriptView(
						transcript: transcript,
						isPlaying: store.playingTranscriptID == transcript.id,
						onPlay: { store.playTranscript(transcript.id) },
						onCopy: { store.copyToClipboard(transcript.text) },
						onDelete: { store.deleteTranscript(transcript.id) }
					)
				}
			}
			.padding()
		}
		.toolbar {
			Button(role: .destructive, action: { showingDeleteConfirmation = true }, label: {
				Label("Delete All", systemImage: "trash")
			})
		}
		.alert("Delete All Transcripts", isPresented: $showingDeleteConfirmation) {
			Button("Delete All", role: .destructive) {
				store.confirmDeleteAll()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Are you sure you want to delete all transcripts? This action cannot be undone.")
		}
	}
}
