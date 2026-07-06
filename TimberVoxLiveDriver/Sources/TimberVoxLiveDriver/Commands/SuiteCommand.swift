import ArgumentParser
import Foundation

struct SuiteCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "suite",
    abstract: "Run a TimberVox live suite."
  )

  @Argument(help: "Suite name or path, e.g. permission-onboarding.")
  var suite: String

  @Option var target: Target?

  func run() throws {
    let runner = SuiteRunner()
    try runner.run(suite: suite, targetOverride: target)
  }
}
