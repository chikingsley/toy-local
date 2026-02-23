import Foundation

public struct TranscriptPersistenceClient: Sendable {
    public var save: @Sendable (
        _ result: String,
        _ audioURL: URL,
        _ duration: TimeInterval,
        _ sourceAppBundleID: String?,
        _ sourceAppName: String?
    ) async throws -> Transcript

    public var deleteAudio: @Sendable (_ transcript: Transcript) async throws -> Void

    public init(
        save: @escaping @Sendable (String, URL, TimeInterval, String?, String?) async throws -> Transcript,
        deleteAudio: @escaping @Sendable (Transcript) async throws -> Void
    ) {
        self.save = save
        self.deleteAudio = deleteAudio
    }

    public static let live: TranscriptPersistenceClient = {
        return TranscriptPersistenceClient(
            save: { result, audioURL, duration, sourceAppBundleID, sourceAppName in
                let fm = FileManager.default

                let supportDir = try fm.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let ourAppFolder = supportDir.appendingPathComponent("com.kitlangton.Hex", isDirectory: true)
                let recordingsFolder = ourAppFolder.appendingPathComponent("Recordings", isDirectory: true)
                try fm.createDirectory(at: recordingsFolder, withIntermediateDirectories: true)

                let filename = "\(Date().timeIntervalSince1970).wav"
                let finalURL = recordingsFolder.appendingPathComponent(filename)
                try fm.moveItem(at: audioURL, to: finalURL)

                return Transcript(
                    timestamp: Date(),
                    text: result,
                    audioPath: finalURL,
                    duration: duration,
                    sourceAppBundleID: sourceAppBundleID,
                    sourceAppName: sourceAppName
                )
            },
            deleteAudio: { transcript in
                try FileManager.default.removeItem(at: transcript.audioPath)
            }
        )
    }()
}
