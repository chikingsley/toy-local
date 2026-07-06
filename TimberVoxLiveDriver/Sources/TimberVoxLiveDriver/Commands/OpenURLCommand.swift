import ArgumentParser

struct OpenURLCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "open-url",
    abstract: "Open a TimberVox URL."
  )

  @Option var target: Target = .debug
  @Argument var url: String

  func run() throws {
    _ = target
    try AppControl(target: target).openURL(url)
  }
}
