import AVFoundation
import AppKit
import TimberVoxCore
import SwiftUI

private let historyLogger = TimberVoxLog.history

class AudioPlayerController: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
  private var player: AVAudioPlayer?
  var onPlaybackFinished: (() -> Void)?

  func play(url: URL) throws -> AVAudioPlayer {
    let player = try AVAudioPlayer(contentsOf: url)
    player.delegate = self
    player.play()
    self.player = player
    return player
  }

  func stop() {
    player?.stop()
    player = nil
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard self.player === player else { return }
    self.player = nil
    let callback = onPlaybackFinished
    onPlaybackFinished = nil
    Task { @MainActor in
      callback?()
    }
  }
}

@MainActor @Observable
final class HistoryStore {
  var records: [TranscriptRecord] = []
  var playingTranscriptID: String?
  var playbackPosition: TimeInterval = 0
  var playbackDuration: TimeInterval = 0
  var audioPlayer: AVAudioPlayer?
  var audioPlayerController: AudioPlayerController?
  private var playbackTicker: Task<Void, Never>?

  private let settings: SettingsManager
  private let pasteboard: PasteboardClientLive
  private let transcriptStore: TranscriptStore
  private let transcriptHistoryPersistence: TranscriptHistoryPersistence
  private var currentSearchText = ""

  init(services: ServiceContainer) {
    self.settings = services.settings
    self.pasteboard = services.pasteboard
    self.transcriptStore = services.transcriptStore
    self.transcriptHistoryPersistence = services.transcriptHistoryPersistence
    self.transcriptHistoryPersistence.onDidChange = { [weak self] in
      self?.refreshRecords()
    }
    refreshRecords()
  }

  var saveTranscriptionHistory: Bool {
    settings.settings.saveTranscriptionHistory
  }

  func refreshRecords() {
    search(currentSearchText)
  }

  func search(_ text: String) {
    currentSearchText = text
    do {
      records = try transcriptStore.search(text)
    } catch {
      records = []
      historyLogger.error("Failed to search transcript records: \(error.localizedDescription)")
    }
  }

  func record(id: String) -> TranscriptRecord? {
    if let record = records.first(where: { $0.id == id }) {
      return record
    }
    do {
      return try transcriptStore.record(id: id)
    } catch {
      historyLogger.error("Failed to read transcript record \(id): \(error.localizedDescription)")
      return nil
    }
  }

  func updateTitle(id: String, title: String) {
    guard var record = record(id: id) else { return }
    record.title = title
    do {
      try transcriptStore.update(record)
      refreshRecords()
    } catch {
      historyLogger.error("Failed to update transcript title \(id): \(error.localizedDescription)")
    }
  }

  func playTranscript(_ id: String) {
    if playingTranscriptID == id {
      stopPlayback()
      return
    }

    stopPlayback()

    guard let record = record(id: id),
      let audioPath = record.audioPath,
      !audioPath.isEmpty
    else {
      return
    }

    do {
      let controller = AudioPlayerController()
      let player = try controller.play(url: URL(fileURLWithPath: audioPath))

      audioPlayer = player
      audioPlayerController = controller
      playingTranscriptID = id
      playbackDuration = player.duration
      playbackPosition = 0
      startPlaybackTicker()

      controller.onPlaybackFinished = { [weak self] in
        Task { @MainActor in
          guard let self, self.playingTranscriptID == id else { return }
          self.stopPlayback()
        }
      }
    } catch {
      historyLogger.error("Failed to play audio: \(error.localizedDescription)")
    }
  }

  func seek(to position: TimeInterval) {
    guard let audioPlayer else { return }
    audioPlayer.currentTime = min(max(0, position), audioPlayer.duration)
    playbackPosition = audioPlayer.currentTime
  }

  func stopPlayback() {
    playbackTicker?.cancel()
    playbackTicker = nil
    audioPlayerController?.stop()
    audioPlayer = nil
    audioPlayerController = nil
    playingTranscriptID = nil
    playbackPosition = 0
    playbackDuration = 0
  }

  private func startPlaybackTicker() {
    playbackTicker?.cancel()
    playbackTicker = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, let player = self.audioPlayer else { return }
        self.playbackPosition = player.currentTime
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  func copyToClipboard(_ text: String) {
    Task {
      await pasteboard.copy(text: text)
    }
  }

  func deleteTranscript(_ id: String) {
    if playingTranscriptID == id {
      stopPlayback()
    }
    transcriptHistoryPersistence.deleteRecord(id: id)
    refreshRecords()
  }

  func confirmDeleteAll() {
    let ids = records.map(\.id)
    stopPlayback()
    for id in ids {
      transcriptHistoryPersistence.deleteRecord(id: id)
    }
    refreshRecords()
  }
}
