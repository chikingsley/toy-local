import ArgumentParser

struct ToyLocalLive: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "toy-local-live",
    abstract: "Drive ToyLocal live app smoke suites.",
    subcommands: [
      LaunchCommand.self,
      QuitCommand.self,
      StateCommand.self,
      OpenURLCommand.self,
      TCCResetCommand.self,
      AXTreeCommand.self,
      SuiteCommand.self,
    ],
    defaultSubcommand: StateCommand.self
  )
}

ToyLocalLive.main()
