import ArgumentParser
import Foundation

struct StateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "state",
    abstract: "Ask TimberVox to write debug state and print it."
  )

  @Option var target: Target = .debug

  func run() throws {
    let snapshot = try AppControl(target: target).requestState()
    let data = try JSONEncoder.prettySorted.encode(snapshot)
    guard let output = String(data: data, encoding: .utf8) else {
      throw DriverError("Failed to encode debug state as UTF-8")
    }
    print(output)
  }
}

extension JSONEncoder {
  static var prettySorted: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}
