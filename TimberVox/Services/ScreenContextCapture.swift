import AppKit
import TimberVoxCore
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import Vision

private let screenContextCaptureLogger = TimberVoxLog.transcription

struct ScreenContextCaptureResult {
  var text: String?
  var attachment: DictationContextAttachment?
}

enum ScreenContextCapture {
  static func capture(
    attachmentDirectory: URL?,
    capturedAt: Date,
    maxCharacters: Int = 12_000
  ) -> ScreenContextCaptureResult {
    guard CGPreflightScreenCaptureAccess() else {
      return ScreenContextCaptureResult(text: nil, attachment: nil)
    }
    guard let image = captureScreenImage() else {
      return ScreenContextCaptureResult(text: nil, attachment: nil)
    }

    let attachment = saveScreenImage(image, attachmentDirectory: attachmentDirectory, capturedAt: capturedAt)
    let text = recognizeText(in: image, maxCharacters: maxCharacters)
    return ScreenContextCaptureResult(text: text, attachment: attachment)
  }

  private static func captureScreenImage() -> CGImage? {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ScreenCaptureImageBox()

    Task.detached(priority: .userInitiated) {
      do {
        box.set(.success(try await captureScreenImageAsync()))
      } catch {
        box.set(.failure(error))
      }
      semaphore.signal()
    }

    guard semaphore.wait(timeout: .now() + 3) == .success else {
      screenContextCaptureLogger.error("Timed out while capturing screen context")
      return nil
    }

    switch box.result {
    case .success(let image):
      return image
    case .failure(let error):
      screenContextCaptureLogger.error("Failed to capture screen context: \(error.localizedDescription)")
      return nil
    case .none:
      return nil
    }
  }

  private static func captureScreenImageAsync() async throws -> CGImage? {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else { return nil }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    filter.includeMenuBar = true

    let configuration = SCStreamConfiguration()
    configuration.width = display.width
    configuration.height = display.height
    configuration.showsCursor = false
    configuration.queueDepth = 1
    if #available(macOS 14.0, *) {
      configuration.captureResolution = .best
    }

    return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
  }

  private static func recognizeText(in image: CGImage, maxCharacters: Int) -> String? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = true

    do {
      try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    } catch {
      screenContextCaptureLogger.error("Failed to recognize screen text: \(error.localizedDescription)")
      return nil
    }

    let text = request.results?
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let text, !text.isEmpty else { return nil }
    return String(text.prefix(maxCharacters))
  }

  private static func saveScreenImage(
    _ image: CGImage,
    attachmentDirectory: URL?,
    capturedAt: Date
  ) -> DictationContextAttachment? {
    guard let attachmentDirectory else { return nil }
    let filename = "screen-\(UUID().uuidString).png"
    let url = attachmentDirectory.appending(component: filename)
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      return nil
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    let byteCount = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
    return DictationContextAttachment(
      kind: .screenImage,
      source: nil,
      uniformTypeIdentifier: UTType.png.identifier,
      filename: filename,
      byteCount: byteCount,
      localPath: url.path,
      capturedAt: capturedAt
    )
  }
}

private final class ScreenCaptureImageBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storedResult: Result<CGImage?, Error>?

  var result: Result<CGImage?, Error>? {
    lock.withLock {
      storedResult
    }
  }

  func set(_ result: Result<CGImage?, Error>) {
    lock.withLock {
      storedResult = result
    }
  }
}
