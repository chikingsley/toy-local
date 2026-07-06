import TimberVoxCore
import Foundation

private let mediaRestoreLogger = TimberVoxLog.media

extension RecordingClientLive {
  func resumeMediaIfNeeded() async {
    let playersToResume = pausedPlayers
    let shouldResumeMedia = didPauseMedia
    let shouldResumeViaMediaRemote = didPauseViaMediaRemote
    let volumeToRestore = previousVolume
    let inputVolumeToRestore = previousInputVolume

    clearMediaState()

    if let inputVolume = inputVolumeToRestore {
      RecordingAudioHardware.restoreInputVolume(inputVolume)
    }

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
    previousInputVolume = nil
  }
}
