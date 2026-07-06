import ArgumentParser
import Foundation

// App Store release automation, ported from the former tools/release/ shell scripts.
// Run from the repo root (the Justfile invokes this with `swift run --package-path`).

private enum ASC {
  static let teamID = "XM69J99HWP"
  static func env(_ key: String) -> String? {
    let value = ProcessInfo.processInfo.environment[key]
    return (value?.isEmpty ?? true) ? nil : value
  }
  static var apiKeyID: String { env("APP_STORE_CONNECT_API_KEY_ID") ?? "F0YBUEMFRDLI" }
  static var issuerID: String { env("APP_STORE_CONNECT_ISSUER_ID") ?? "d1804d83-f266-43bc-8cda-edb51b2c2354" }
  static var appleID: String { env("APP_STORE_CONNECT_APPLE_ID") ?? "6787965139" }
  static var p8Path: String { env("APP_STORE_CONNECT_P8_PATH") ?? "Config/keys/ApiKey_\(apiKeyID).p8" }

  static var authArgs: [String] {
    var args = ["--api-key", apiKeyID, "--api-issuer", issuerID, "--p8-file-path", p8Path]
    if let subject = env("APP_STORE_CONNECT_API_KEY_SUBJECT") {
      args += ["--api-key-subject", subject]
    }
    return args
  }
}

/// Run a tool inheriting the parent's stdio so xcodebuild/altool progress streams live.
@discardableResult
private func exec(_ executable: String, _ arguments: [String]) throws -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    throw DriverError("\(executable) \(arguments.joined(separator: " ")) failed with exit \(process.terminationStatus)")
  }
  return process.terminationStatus
}

private func requireFile(_ path: String, _ hint: String) throws {
  guard FileManager.default.fileExists(atPath: path) else {
    throw DriverError("Missing \(path). \(hint)")
  }
}

struct AppStoreCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "app-store",
    abstract: "Build, validate, and upload the Mac App Store package.",
    subcommands: [ExportCommand.self, ValidateCommand.self, UploadCommand.self, ListAppsCommand.self, AppcastCommand.self],
    defaultSubcommand: ListAppsCommand.self
  )

  struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export", abstract: "Archive TimberVox-AppStore and export an App Store .pkg.")
    @Argument(help: "Output directory.") var output = "build/app-store/current"

    func run() throws {
      let scheme = "TimberVox-AppStore"
      let archivePath = "\(output)/TimberVox-AppStore.xcarchive"
      let exportPath = "\(output)/export"
      let optionsPath = "\(output)/ExportOptions.plist"
      let jobs = ASC.env("TIMBERVOX_XCODEBUILD_JOBS") ?? "2"

      let fileManager = FileManager.default
      try? fileManager.removeItem(atPath: output)
      try fileManager.createDirectory(atPath: output, withIntermediateDirectories: true)

      print("Archiving \(scheme) (jobs=\(jobs))")
      try exec("/usr/bin/xcodebuild", [
        "-project", "TimberVox.xcodeproj",
        "-scheme", scheme,
        "-configuration", "Release",
        "-destination", "generic/platform=macOS",
        "-archivePath", archivePath,
        "-jobs", jobs,
        "archive",
        "-allowProvisioningUpdates",
      ])

      let exportOptions = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>destination</key><string>export</string>
        <key>manageAppVersionAndBuildNumber</key><true/>
        <key>method</key><string>app-store-connect</string>
        <key>signingStyle</key><string>automatic</string>
        <key>teamID</key><string>\(ASC.teamID)</string>
        <key>uploadSymbols</key><true/>
      </dict>
      </plist>
      """
      try exportOptions.write(toFile: optionsPath, atomically: true, encoding: .utf8)

      try exec("/usr/bin/xcodebuild", [
        "-exportArchive",
        "-archivePath", archivePath,
        "-exportPath", exportPath,
        "-exportOptionsPlist", optionsPath,
        "-allowProvisioningUpdates",
      ])
      print("App Store export written to \(exportPath)")
    }
  }

  struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate a package with App Store Connect.")
    @Argument(help: "Package path.") var package = "build/app-store/current/export/TimberVox.pkg"

    func run() throws {
      try requireFile(package, "Run: just app-store-export")
      try requireFile(ASC.p8Path, "Set APP_STORE_CONNECT_P8_PATH to the matching .p8 file.")
      try exec("/usr/bin/xcrun", ["altool", "--validate-app", package] + ASC.authArgs + ["--output-format", "json"])
    }
  }

  struct UploadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "upload", abstract: "Upload a package to App Store Connect.")
    @Argument(help: "Package path.") var package = "build/app-store/current/export/TimberVox.pkg"
    @Flag(name: .long, help: "Block until App Store Connect finishes processing.") var wait = false

    func run() throws {
      try requireFile(package, "Run: just app-store-export")
      try requireFile(ASC.p8Path, "Set APP_STORE_CONNECT_P8_PATH to the matching .p8 file.")
      var arguments = ["altool", "--upload-package", package] + ASC.authArgs + ["--output-format", "json", "--show-progress"]
      if wait { arguments.append("--wait") }
      try exec("/usr/bin/xcrun", arguments)
    }
  }

  struct ListAppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list-apps", abstract: "List App Store Connect apps for the account.")

    func run() throws {
      try requireFile(ASC.p8Path, "Set APP_STORE_CONNECT_P8_PATH to the matching .p8 file.")
      try exec("/usr/bin/xcrun", ["altool", "--list-apps", "--filter-apple-id", ASC.appleID] + ASC.authArgs + ["--output-format", "json"])
    }
  }

  struct AppcastCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "appcast", abstract: "Generate the Sparkle appcast (wraps the vendored generate_appcast tool).")
    @Argument(parsing: .captureForPassthrough, help: "Arguments passed to generate_appcast (e.g. the updates directory).") var passthrough: [String] = []

    func run() throws {
      let binary = "tools/release/generate_appcast"
      try requireFile(binary, "The vendored Sparkle generate_appcast binary is missing.")
      try exec(binary, passthrough)
    }
  }
}
