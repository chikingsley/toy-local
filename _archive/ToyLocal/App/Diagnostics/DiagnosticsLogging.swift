import ToyLocalCore
import OSLog

enum DiagnosticsLogging {
  private nonisolated(unsafe) static var isBootstrapped = false
  private static let logger = Logger(subsystem: ToyLocalLog.subsystem, category: "Diagnostics")

  static func bootstrapIfNeeded() {
    guard !isBootstrapped else { return }
    logger.notice("Diagnostics logging initialized")
    isBootstrapped = true
  }
}
