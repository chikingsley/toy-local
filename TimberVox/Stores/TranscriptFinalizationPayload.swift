import TimberVoxCore
import Foundation

struct TranscriptFinalizationPayload {
  let finalText: String
  let rawText: String
  let modeName: String?
  let duration: TimeInterval
  let sourceAppBundleID: String?
  let sourceAppName: String?
  let audioURL: URL
  let contextSnapshot: DictationContextSnapshot?
}
