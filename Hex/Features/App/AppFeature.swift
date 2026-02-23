import Inject
import SwiftUI

struct AppView: View {
	@Bindable var store: AppStore
	@State private var columnVisibility = NavigationSplitViewVisibility.automatic

	var body: some View {
		NavigationSplitView(columnVisibility: $columnVisibility) {
			List(selection: $store.activeTab) {
				Button {
					store.setActiveTab(.settings)
				} label: {
					Label("Settings", systemImage: "gearshape")
				}
				.buttonStyle(.plain)
				.tag(ActiveTab.settings)

				Button {
					store.setActiveTab(.remappings)
				} label: {
					Label("Transforms", systemImage: "text.badge.plus")
				}
				.buttonStyle(.plain)
				.tag(ActiveTab.remappings)

				Button {
					store.setActiveTab(.history)
				} label: {
					Label("History", systemImage: "clock")
				}
				.buttonStyle(.plain)
				.tag(ActiveTab.history)

				Button {
					store.setActiveTab(.about)
				} label: {
					Label("About", systemImage: "info.circle")
				}
				.buttonStyle(.plain)
				.tag(ActiveTab.about)
			}
		} detail: {
			switch store.activeTab {
			case .settings:
				SettingsView(
					store: store.settings,
					alwaysOnStore: store.alwaysOn,
					microphonePermission: store.microphonePermission,
					accessibilityPermission: store.accessibilityPermission,
					inputMonitoringPermission: store.inputMonitoringPermission
				)
				.navigationTitle("Settings")
			case .remappings:
				WordRemappingsView(store: store.settings)
					.navigationTitle("Transforms")
			case .history:
				HistoryView(store: store.history)
					.navigationTitle("History")
			case .about:
				AboutView(store: store.settings)
					.navigationTitle("About")
			}
		}
		.enableInjection()
	}
}
