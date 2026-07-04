import Foundation
import ToyLocalCore

@MainActor
extension ToyLocalAppDelegate {
  func downloadModelForCommand(_ model: String) {
    ToyLocalApp.appStore.settings.modelDownload.downloadModel(model)
    writeDebugState()
    Task { @MainActor in
      while ToyLocalApp.appStore.settings.modelDownload.isDownloading {
        try? await Task.sleep(for: .milliseconds(500))
        writeDebugState()
      }
      writeDebugState()
    }
  }

  func transcribeFileForCommand(model: String, path: String) {
    let url = URL(fileURLWithPath: path)
    debugLocalTranscription = .init(
      audioPath: url.path,
      error: nil,
      model: model,
      status: "running",
      text: nil
    )
    writeDebugState()

    Task { @MainActor in
      do {
        let text = try await ToyLocalApp.services.transcription.transcribe(
          url: url,
          model: model
        ) { _ in
          Task { @MainActor [weak self] in
            self?.writeDebugState()
          }
        }
        debugLocalTranscription = .init(
          audioPath: url.path,
          error: nil,
          model: model,
          status: "succeeded",
          text: text
        )
      } catch {
        debugLocalTranscription = .init(
          audioPath: url.path,
          error: error.localizedDescription,
          model: model,
          status: "failed",
          text: nil
        )
      }
      writeDebugState()
    }
  }

  func textTransformForCommand(
    text: String,
    mode rawMode: String?,
    model: String?,
    customInstructions: String?
  ) {
    var settingsSnapshot = ToyLocalApp.services.settings.settings

    if let rawMode, !rawMode.isEmpty {
      guard let mode = TextTransformMode(rawValue: rawMode) else {
        ToyLocalApp.appStore.transcription.textTransformState = .failed(
          mode: nil,
          modelID: model ?? settingsSnapshot.textTransformModel,
          inputCharacterCount: text.count,
          message: "Unsupported text transform mode: \(rawMode)."
        )
        writeDebugState()
        return
      }
      settingsSnapshot.textTransformMode = mode
    } else if !settingsSnapshot.textTransformMode.usesTextTransform {
      settingsSnapshot.textTransformMode = .messagePrompt
    }

    if let model, !model.isEmpty {
      settingsSnapshot.textTransformModel = model
    }
    if let customInstructions, !customInstructions.isEmpty {
      settingsSnapshot.customTextTransformInstructions = customInstructions
      if rawMode == nil {
        settingsSnapshot.textTransformMode = .customPrompt
      }
    }

    let store = ToyLocalApp.appStore.transcription
    if let request = store.textTransformRequest(for: settingsSnapshot, contextSnapshot: nil) {
      store.textTransformState = .running(
        mode: settingsSnapshot.textTransformMode,
        request: request,
        input: text
      )
    } else {
      store.textTransformState = .skipped(reason: "No text transform request could be built.")
    }
    store.error = nil
    writeDebugState()

    Task { @MainActor in
      do {
        let result = try await store.applyTextTransformIfNeeded(
          to: text,
          settings: settingsSnapshot,
          contextSnapshot: nil
        )
        store.textTransformState = result.state
      } catch {
        store.textTransformState = .failed(
          mode: settingsSnapshot.textTransformMode,
          modelID: settingsSnapshot.textTransformModel,
          inputCharacterCount: text.count,
          message: error.localizedDescription
        )
        store.error = error.localizedDescription
      }
      writeDebugState()
    }
  }
}
