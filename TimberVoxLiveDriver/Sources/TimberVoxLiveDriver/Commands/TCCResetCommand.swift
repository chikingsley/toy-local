import ArgumentParser

struct TCCResetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "tcc-reset",
    abstract: "Reset TimberVox TCC permissions."
  )

  @Option var target: Target = .debug

  func run() {
    AppControl(target: target).resetTCC(services: TCCService.allCases)
  }
}
