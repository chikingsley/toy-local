import Foundation

do {
  let cli = CLI(arguments: Array(CommandLine.arguments.dropFirst()))
  try await cli.run()
} catch let error as CLIError {
  FileHandle.standardError.write(Data((error.message + "\n").utf8))
  exit(Int32(error.exitCode))
} catch {
  FileHandle.standardError.write(Data(("error: \(error.localizedDescription)\n").utf8))
  exit(1)
}
