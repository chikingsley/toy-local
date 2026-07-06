import ArgumentParser

struct TimberVoxLive: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "timbervox-live",
    abstract: "Drive TimberVox live app smoke suites.",
    subcommands: [
      LaunchCommand.self,
      QuitCommand.self,
      StateCommand.self,
      OpenURLCommand.self,
      TCCResetCommand.self,
      AXTreeCommand.self,
      SuiteCommand.self,
      AppStoreCommand.self,
    ],
    defaultSubcommand: StateCommand.self
  )
}

TimberVoxLive.main()
