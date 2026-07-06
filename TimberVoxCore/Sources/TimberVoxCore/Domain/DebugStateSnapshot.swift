public struct DebugStateSnapshot: Codable, Equatable, Sendable {
  public struct PermissionSnapshot: Codable, Equatable, Sendable {
    public let microphone: String
    public let accessibility: String
    public let screenCapture: String

    public init(microphone: String, accessibility: String, screenCapture: String) {
      self.microphone = microphone
      self.accessibility = accessibility
      self.screenCapture = screenCapture
    }
  }

  public struct TranscriptionSnapshot: Codable, Equatable, Sendable {
    public struct TextTransformSnapshot: Codable, Equatable, Sendable {
      public let phase: String
      public let mode: String?
      public let requestedModelID: String?
      public let responseModelID: String?
      public let providerID: String?
      public let inputCharacterCount: Int?
      public let outputCharacterCount: Int?
      public let outputPreview: String?
      public let error: String?

      public init(
        phase: String,
        mode: String?,
        requestedModelID: String?,
        responseModelID: String?,
        providerID: String?,
        inputCharacterCount: Int?,
        outputCharacterCount: Int?,
        outputPreview: String?,
        error: String?
      ) {
        self.phase = phase
        self.mode = mode
        self.requestedModelID = requestedModelID
        self.responseModelID = responseModelID
        self.providerID = providerID
        self.inputCharacterCount = inputCharacterCount
        self.outputCharacterCount = outputCharacterCount
        self.outputPreview = outputPreview
        self.error = error
      }
    }

    public let isRecording: Bool
    public let isTranscribing: Bool
    public let isPrewarming: Bool
    public let textTransform: TextTransformSnapshot
    public let error: String?

    public init(
      isRecording: Bool,
      isTranscribing: Bool,
      isPrewarming: Bool,
      textTransform: TextTransformSnapshot,
      error: String?
    ) {
      self.isRecording = isRecording
      self.isTranscribing = isTranscribing
      self.isPrewarming = isPrewarming
      self.textTransform = textTransform
      self.error = error
    }
  }

  public struct ModelSnapshot: Codable, Equatable, Sendable {
    public let displayName: String?
    public let error: String?
    public let identifier: String?
    public let isDownloading: Bool
    public let isReady: Bool
    public let progress: Double

    public init(
      displayName: String?,
      error: String?,
      identifier: String?,
      isDownloading: Bool,
      isReady: Bool,
      progress: Double
    ) {
      self.displayName = displayName
      self.error = error
      self.identifier = identifier
      self.isDownloading = isDownloading
      self.isReady = isReady
      self.progress = progress
    }
  }

  public struct LocalTranscriptionSnapshot: Codable, Equatable, Sendable {
    public let audioPath: String
    public let error: String?
    public let model: String
    public let status: String
    public let text: String?

    public init(
      audioPath: String,
      error: String?,
      model: String,
      status: String,
      text: String?
    ) {
      self.audioPath = audioPath
      self.error = error
      self.model = model
      self.status = status
      self.text = text
    }
  }

  public let bundleIdentifier: String
  public let processIdentifier: Int32
  public let mainExperienceStarted: Bool
  public let visibleWindows: [String]
  public let permissions: PermissionSnapshot
  public let transcription: TranscriptionSnapshot
  public let model: ModelSnapshot
  public let localTranscription: LocalTranscriptionSnapshot?
  public let activeTab: String
  public let generatedAt: String

  public init(
    bundleIdentifier: String,
    processIdentifier: Int32,
    mainExperienceStarted: Bool,
    visibleWindows: [String],
    permissions: PermissionSnapshot,
    transcription: TranscriptionSnapshot,
    model: ModelSnapshot,
    localTranscription: LocalTranscriptionSnapshot?,
    activeTab: String,
    generatedAt: String
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.processIdentifier = processIdentifier
    self.mainExperienceStarted = mainExperienceStarted
    self.visibleWindows = visibleWindows
    self.permissions = permissions
    self.transcription = transcription
    self.model = model
    self.localTranscription = localTranscription
    self.activeTab = activeTab
    self.generatedAt = generatedAt
  }
}
