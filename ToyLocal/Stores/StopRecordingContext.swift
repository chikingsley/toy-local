import Foundation
import ToyLocalCore

struct StopRecordingContext {
  let stopTime: Date
  let startTime: Date?
  let duration: TimeInterval
  let decision: RecordingDecisionEngine.Decision
  let settingsSnapshot: ToyLocalSettings
  let sourceAppBundleID: String?
  let sourceAppName: String?
  let contextSnapshot: DictationContextSnapshot?
}
