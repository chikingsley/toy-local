import TimberVoxCore
import Foundation

private let mediaControlLogger = TimberVoxLog.media

extension RecordingClientLive {
  private static let loweredVolumeFactor: Float = 0.25

  func scheduleMediaControlTask(for behavior: RecordingAudioBehavior, sessionID: UUID) {
    switch behavior {
    case .pauseMedia:
      schedulePauseMediaControlTask(sessionID: sessionID)
    case .mute:
      scheduleMuteMediaControlTask(sessionID: sessionID)
    case .lowerVolume:
      scheduleLowerVolumeMediaControlTask(sessionID: sessionID)
    case .doNothing:
      break
    }
  }

  private func schedulePauseMediaControlTask(sessionID: UUID) {
    mediaControlTask = Task { [sessionID] in
      guard self.isCurrentSession(sessionID) else { return }
      if await self.pauseUsingMediaRemoteIfPossible(sessionID: sessionID) {
        return
      }

      let paused = pauseAllMediaApplications()
      guard self.isCurrentSession(sessionID) else {
        resumeMediaApplications(paused)
        return
      }
      self.updatePausedPlayers(paused, sessionID: sessionID)

      guard self.isCurrentSession(sessionID) else { return }
      if paused.isEmpty, await isAudioPlayingOnDefaultOutput() {
        guard self.isCurrentSession(sessionID) else { return }
        mediaControlLogger.notice("Detected active audio on default output; sending media pause")
        await MainActor.run {
          sendMediaKey()
        }
        self.setDidPauseMedia(true, sessionID: sessionID)
        mediaControlLogger.notice("Paused media via media key fallback")
      } else if !paused.isEmpty {
        mediaControlLogger.notice("Paused media players: \(paused.joined(separator: ", "))")
      }
    }
  }

  private func scheduleMuteMediaControlTask(sessionID: UUID) {
    mediaControlTask = Task { [sessionID] in
      guard self.isCurrentSession(sessionID) else { return }
      let volume = RecordingAudioHardware.muteSystemVolume()
      guard self.isCurrentSession(sessionID) else {
        RecordingAudioHardware.restoreSystemVolume(volume)
        return
      }
      self.setPreviousVolume(volume, sessionID: sessionID)
    }
  }

  private func scheduleLowerVolumeMediaControlTask(sessionID: UUID) {
    mediaControlTask = Task { [sessionID] in
      guard self.isCurrentSession(sessionID) else { return }
      let volume = RecordingAudioHardware.lowerSystemVolume(to: Self.loweredVolumeFactor)
      guard self.isCurrentSession(sessionID) else {
        RecordingAudioHardware.restoreSystemVolume(volume)
        return
      }
      self.setPreviousVolume(volume, sessionID: sessionID)
    }
  }

  @discardableResult
  private func pauseUsingMediaRemoteIfPossible(sessionID: UUID) async -> Bool {
    guard let controller = mediaRemoteController else {
      return false
    }

    let isPlaying = await controller.isMediaPlaying()
    guard isPlaying, self.isCurrentSession(sessionID), !Task.isCancelled else {
      return false
    }

    guard controller.send(.pause) else {
      mediaControlLogger.error("Failed to send MediaRemote pause command")
      return false
    }

    setDidPauseViaMediaRemote(true, sessionID: sessionID)
    mediaControlLogger.notice("Paused media via MediaRemote")
    return true
  }

  private func updatePausedPlayers(_ players: [String], sessionID: UUID) {
    guard recordingSessionID == sessionID else { return }
    pausedPlayers = players
  }

  private func setDidPauseMedia(_ value: Bool, sessionID: UUID) {
    guard recordingSessionID == sessionID else { return }
    didPauseMedia = value
  }

  private func setDidPauseViaMediaRemote(_ value: Bool, sessionID: UUID) {
    guard recordingSessionID == sessionID else { return }
    didPauseViaMediaRemote = value
  }

  private func setPreviousVolume(_ volume: Float, sessionID: UUID) {
    guard recordingSessionID == sessionID else { return }
    previousVolume = volume
  }
}
