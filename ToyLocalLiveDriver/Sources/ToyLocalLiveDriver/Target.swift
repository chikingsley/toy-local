import ArgumentParser
import Foundation

enum Target: String, ExpressibleByArgument, Decodable, CaseIterable {
  case debug
  case release

  var bundleIdentifier: String {
    switch self {
    case .debug:
      "com.chiejimofor.toylocal.debug"
    case .release:
      "com.chiejimofor.toylocal"
    }
  }

  var configuration: String {
    switch self {
    case .debug:
      "Debug"
    case .release:
      "Release"
    }
  }
}

struct DriverError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

extension URL {
  static var repoRoot: URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
  }

  static var toyLocalApplicationSupport: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/com.chiejimofor.toylocal", isDirectory: true)
  }
}
