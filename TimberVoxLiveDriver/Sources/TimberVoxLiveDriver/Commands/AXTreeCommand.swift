import ArgumentParser

struct AXTreeCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ax-tree",
    abstract: "Print TimberVox's accessibility tree."
  )

  @Option var target: Target = .debug
  @Option var depth: Int = 8

  func run() throws {
    try AXDriver(app: AppControl(target: target)).printTree(maxDepth: depth)
  }
}
