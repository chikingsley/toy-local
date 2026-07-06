import ArgumentParser

struct LaunchCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "launch",
    abstract: "Launch the built TimberVox app."
  )

  @Option var target: Target = .debug

  func run() throws {
    try AppControl(target: target).launch()
  }
}
