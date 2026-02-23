@preconcurrency import AVFoundation
import CoreAudio
import Dependencies
import DependenciesMacros
import HexCore

extension AVAudioPCMBuffer: @unchecked @retroactive Sendable {}

// MARK: - Client Interface

@DependencyClient
struct StreamingAudioClient: Sendable {
	var startCapture: @Sendable () async throws -> AsyncStream<AVAudioPCMBuffer> = { .finished }
	var stopCapture: @Sendable () async -> Void = {}
	var isCapturing: @Sendable () async -> Bool = { false }
}

extension StreamingAudioClient: TestDependencyKey {
	static let testValue = StreamingAudioClient()
}

extension DependencyValues {
	var streamingAudio: StreamingAudioClient {
		get { self[StreamingAudioClient.self] }
		set { self[StreamingAudioClient.self] = newValue }
	}
}

// MARK: - Live Implementation

extension StreamingAudioClient: DependencyKey {
	static let liveValue: StreamingAudioClient = {
		let live = StreamingAudioClientLive()
		return StreamingAudioClient(
			startCapture: { try await live.startCapture() },
			stopCapture: { await live.stopCapture() },
			isCapturing: { await live.isCapturing }
		)
	}()
}

private actor StreamingAudioClientLive {
	private let logger = HexLog.streaming
	private var engine: AVAudioEngine?
	private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
	var isCapturing = false

	/// Target format for FluidAudio: 16kHz mono Float32.
	private let targetSampleRate: Double = 16000
	private let targetChannels: AVAudioChannelCount = 1

	/// Buffer size in frames at 16kHz for ~160ms chunks (matching StreamingChunkSize.ms160).
	private let bufferFrameCount: AVAudioFrameCount = 2560

	func startCapture() throws -> AsyncStream<AVAudioPCMBuffer> {
		if isCapturing {
			logger.notice("Already capturing, stopping previous session")
			stopCaptureSync()
		}

		let engine = AVAudioEngine()
		self.engine = engine

		let inputNode = engine.inputNode
		let hardwareFormat = inputNode.outputFormat(forBus: 0)
		logger.notice("Hardware input format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

		guard let targetFormat = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: targetSampleRate,
			channels: targetChannels,
			interleaved: false
		) else {
			throw NSError(
				domain: "StreamingAudio",
				code: -1,
				userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"]
			)
		}

		// Converter to resample from hardware format to 16kHz mono
		let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)

		let stream = AsyncStream<AVAudioPCMBuffer> { continuation in
			self.continuation = continuation
		}

		// Install tap on input node at the hardware format
		// We resample in the callback to 16kHz mono
		let tapBufferSize: AVAudioFrameCount = AVAudioFrameCount(hardwareFormat.sampleRate * 0.16) // ~160ms at hardware rate
		inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: hardwareFormat) { [weak self] buffer, _ in
			guard let self else { return }

			if let converter {
				// Resample to target format
				guard let convertedBuffer = AVAudioPCMBuffer(
					pcmFormat: targetFormat,
					frameCapacity: self.bufferFrameCount
				) else { return }

				var error: NSError?
				let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
					outStatus.pointee = .haveData
					return buffer
				}

				if status == .error {
					return
				}

				self.continuation?.yield(convertedBuffer)
			} else {
				// Formats match, pass through
				self.continuation?.yield(buffer)
			}
		}

		try engine.start()
		isCapturing = true
		logger.notice("Streaming audio capture started")

		return stream
	}

	func stopCapture() {
		stopCaptureSync()
	}

	private func stopCaptureSync() {
		continuation?.finish()
		continuation = nil
		engine?.inputNode.removeTap(onBus: 0)
		engine?.stop()
		engine = nil
		isCapturing = false
		logger.notice("Streaming audio capture stopped")
	}
}
