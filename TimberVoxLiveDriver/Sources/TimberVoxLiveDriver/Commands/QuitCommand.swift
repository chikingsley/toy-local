import ArgumentParser

struct QuitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "quit",
    abstract: "Quit TimberVox."
  )

  @Option var target: Target = .debug

  func run() {
    AppControl(target: target).quit()
  }
}
