import TimberVoxCore
import Foundation

struct StopRecordingContext {
  let stopTime: Date
  let startTime: Date?
  let duration: TimeInterval
  let decision: RecordingDecisionEngine.Decision
  let settingsSnapshot: TimberVoxSettings
  let sourceAppBundleID: String?
  let sourceAppName: String?
  let contextSnapshot: DictationContextSnapshot?
}
