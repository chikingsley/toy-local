import TimberVoxCore
import Foundation

struct HotkeyPermissionState: Codable, Equatable {
  var accessibility: PermissionStatus = .notDetermined
  var lastUpdated: Date = .distantPast
}
