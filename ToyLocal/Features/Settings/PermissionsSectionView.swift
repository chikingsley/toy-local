import Inject
import SwiftUI
import ToyLocalCore

struct PermissionsSectionView: View {
	@ObserveInjection var inject
	let microphonePermission: PermissionStatus
	let accessibilityPermission: PermissionStatus
	let inputMonitoringPermission: PermissionStatus
	let requestMicrophonePermission: () -> Void
	let requestAccessibilityPermission: () -> Void
	let requestInputMonitoringPermission: () -> Void
	private let cardColumns = [GridItem(.adaptive(minimum: 220), spacing: 10)]

	var body: some View {
		Section {
			LazyVGrid(columns: cardColumns, spacing: 10) {
					permissionCard(
						title: "Microphone",
						icon: "mic.fill",
						status: microphonePermission
					) {
						requestMicrophonePermission()
					}

					permissionCard(
						title: "Accessibility",
						icon: "accessibility",
						status: accessibilityPermission
					) {
						requestAccessibilityPermission()
					}

					permissionCard(
						title: "Input Monitoring",
						icon: "keyboard",
						status: inputMonitoringPermission
					) {
						requestInputMonitoringPermission()
					}
			}

			if accessibilityPermission != .granted {
					warningCard(
						message: "Accessibility is required so ToyLocal can control typing and paste behavior across apps.",
						buttonTitle: "Open Accessibility Settings"
					) {
						requestAccessibilityPermission()
					}
				}

			if inputMonitoringPermission != .granted {
					warningCard(
						message: "Input Monitoring is required so ToyLocal can listen for your hotkeys in every app.",
						buttonTitle: "Open Input Monitoring Settings"
					) {
						requestInputMonitoringPermission()
					}
				}
		} header: {
			Text("Permissions")
		}
		.enableInjection()
	}

	@ViewBuilder
	private func permissionCard(
		title: String,
		icon: String,
		status: PermissionStatus,
		action: @escaping () -> Void
	) -> some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.body)
				.foregroundStyle(.secondary)
				.frame(width: 16)

			Text(title)
				.font(.body.weight(.medium))
				.lineLimit(1)
				.truncationMode(.tail)
				.layoutPriority(1)

			Spacer()

			switch status {
			case .granted:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.font(.body)
			case .denied, .notDetermined:
				Button("Grant") {
					action()
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.frame(maxWidth: .infinity)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}

	@ViewBuilder
	private func warningCard(message: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Label {
				Text(message)
					.font(.callout)
					.foregroundStyle(.primary)
			} icon: {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.yellow)
			}

			Button(buttonTitle) {
				action()
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.small)
			.padding(.top, 2)
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}
