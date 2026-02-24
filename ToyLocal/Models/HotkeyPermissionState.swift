import Foundation
import ToyLocalCore

struct HotkeyPermissionState: Codable, Equatable {
	var accessibility: PermissionStatus = .notDetermined
	var inputMonitoring: PermissionStatus = .notDetermined
	var lastUpdated: Date = .distantPast
}
