import Foundation
import ToyLocalCore

private let mediaRestoreLogger = ToyLocalLog.media

extension RecordingClientLive {
  func resumeMediaIfNeeded(
    playersToResume: [String],
    shouldResumeMedia: Bool,
    shouldResumeViaMediaRemote: Bool,
    volumeToRestore: Float?
  ) {
    guard !playersToResume.isEmpty || shouldResumeMedia || shouldResumeViaMediaRemote || volumeToRestore != nil else {
      return
    }

    Task {
      if let volume = volumeToRestore {
        RecordingAudioHardware.restoreSystemVolume(volume)
      } else if !playersToResume.isEmpty {
        mediaRestoreLogger.notice("Resuming players: \(playersToResume.joined(separator: ", "))")
        resumeMediaApplications(playersToResume)
      } else if shouldResumeViaMediaRemote {
        await resumeMediaRemoteOrFallback()
      } else if shouldResumeMedia {
        await MainActor.run {
          sendMediaKey()
        }
        mediaRestoreLogger.notice("Resuming media via media key")
      }

      self.clearMediaState()
    }
  }

  private func resumeMediaRemoteOrFallback() async {
    if mediaRemoteController?.send(.play) == true {
      mediaRestoreLogger.notice("Resuming media via MediaRemote")
    } else {
      mediaRestoreLogger.error("Failed to resume via MediaRemote; falling back to media key")
      await MainActor.run {
        sendMediaKey()
      }
    }
  }

  private func clearMediaState() {
    pausedPlayers = []
    didPauseMedia = false
    didPauseViaMediaRemote = false
    previousVolume = nil
  }
}
