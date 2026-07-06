import AVFoundation
import TimberVoxCore
import Foundation
import SwiftUI

public enum SoundEffect: String, CaseIterable, Sendable {
  case pasteTranscript
  case startRecording
  case stopRecording
  case cancel
}

actor SoundEffectsClientLive {
  private let logger = TimberVoxLog.sound
  private let minimumVolume = 0.0
  private let maximumVolume = 1.0

  private let engine = AVAudioEngine()
  private let settingsManager: SettingsManager
  private var playerNodes: [SoundEffectResource: AVAudioPlayerNode] = [:]
  private var audioBuffers: [SoundEffectResource: AVAudioPCMBuffer] = [:]
  private var isEngineRunning = false

  // Back the actor with a dedicated Default-QoS serial queue. The synchronous
  // AVAudioEngine/AVAudioPlayerNode calls below (stop/scheduleBuffer/play) block
  // while they synchronise with AVAudioEngine's internal command queue, which runs
  // at Default QoS. Running the actor at Default QoS as well keeps those blocking
  // calls at a matching priority and avoids a priority inversion when the actor is
  // driven from a higher-QoS (user-initiated) Task.
  private let queue = DispatchSerialQueue(label: "com.chiejimofor.timbervox.sound-effects", qos: .default)

  nonisolated var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  init(settingsManager: SettingsManager) {
    self.settingsManager = settingsManager
  }

  func play(_ soundEffect: SoundEffect) async {
    let settings = await settingsManager.settings
    guard settings.soundEffectsEnabled, let resource = soundEffect.resource(for: settings.soundEffectsStyle) else {
      return
    }
    guard loadSound(resource, for: soundEffect),
      let player = playerNodes[resource],
      let buffer = audioBuffers[resource]
    else {
      logger.error("Requested sound \(soundEffect.rawValue) not preloaded")
      return
    }
    prepareEngineIfNeeded()
    let clampedVolume = min(max(settings.soundEffectsVolume, minimumVolume), maximumVolume)
    player.volume = Float(clampedVolume)
    player.stop()
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in }
    player.play()
  }

  func stop(_ soundEffect: SoundEffect) {
    soundEffect.resources.forEach {
      playerNodes[$0]?.stop()
    }
  }

  func stopAll() {
    playerNodes.values.forEach { $0.stop() }
  }

  func preloadSounds() async {
    guard !isSetup else { return }

    for soundEffect in SoundEffect.allCases {
      for resource in soundEffect.resources {
        loadSound(resource, for: soundEffect)
      }
    }
    prepareEngineIfNeeded()

    isSetup = true
  }

  private var isSetup = false

  @discardableResult
  private func loadSound(_ resource: SoundEffectResource, for soundEffect: SoundEffect) -> Bool {
    if audioBuffers[resource] != nil, playerNodes[resource] != nil {
      return true
    }

    guard
      let url = resource.url
    else {
      logger.error("Missing sound resource \(resource.path)")
      return false
    }

    do {
      let file = try AVAudioFile(forReading: url)
      let frameCount = AVAudioFrameCount(file.length)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
        logger.error("Failed to allocate buffer for \(soundEffect.rawValue)")
        return false
      }
      try file.read(into: buffer)
      audioBuffers[resource] = buffer

      let player = AVAudioPlayerNode()
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
      playerNodes[resource] = player
      return true
    } catch {
      logger.error("Failed to load sound \(soundEffect.rawValue): \(error.localizedDescription)")
      return false
    }
  }

  private func prepareEngineIfNeeded() {
    if !isEngineRunning || !engine.isRunning {
      engine.prepare()
      if #available(macOS 13.0, *) {
        engine.isAutoShutdownEnabled = false
      }
      do {
        try engine.start()
        isEngineRunning = true
      } catch {
        logger.error("Failed to start AVAudioEngine: \(error.localizedDescription)")
      }
    }
  }
}

private struct SoundEffectResource: Hashable, Sendable {
  let fileName: String
  let fileExtension: String
  let subdirectory: String

  var url: URL? {
    Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: subdirectory)
      ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Resources/\(subdirectory)")
      ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
  }

  var path: String {
    "\(subdirectory)/\(fileName).\(fileExtension)"
  }
}

private extension SoundEffect {
  var resources: [SoundEffectResource] {
    switch self {
    case .startRecording:
      [standardResource, classicResource]
    case .stopRecording:
      [standardResource, classicResource]
    case .pasteTranscript, .cancel:
      [standardResource]
    }
  }

  func resource(for style: SoundEffectsStyle) -> SoundEffectResource? {
    switch style {
    case .standard:
      standardResource
    case .classic:
      switch self {
      case .startRecording, .stopRecording:
        classicResource
      case .pasteTranscript, .cancel:
        standardResource
      }
    case .off:
      nil
    }
  }

  var standardResource: SoundEffectResource {
    SoundEffectResource(
      fileName: standardFileName,
      fileExtension: "m4a",
      subdirectory: "Audio/SoundEffects/Default"
    )
  }

  var classicResource: SoundEffectResource {
    SoundEffectResource(
      fileName: classicFileName,
      fileExtension: "m4a",
      subdirectory: "Audio/SoundEffects/Classic"
    )
  }

  var standardFileName: String {
    switch self {
    case .pasteTranscript:
      "Notification"
    case .startRecording:
      "Start"
    case .stopRecording:
      "Stop"
    case .cancel:
      "NotificationError"
    }
  }

  var classicFileName: String {
    switch self {
    case .pasteTranscript:
      "Notification"
    case .startRecording:
      "StartClassic"
    case .stopRecording:
      "StopClassic"
    case .cancel:
      "NotificationError"
    }
  }
}
