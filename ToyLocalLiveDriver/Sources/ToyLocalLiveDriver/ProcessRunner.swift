import Foundation

@discardableResult
func runProcess(
  _ executable: String,
  _ arguments: [String],
  allowFailure: Bool = false
) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments

  let output = Pipe()
  let error = Pipe()
  process.standardOutput = output
  process.standardError = error

  try process.run()
  process.waitUntilExit()

  let outputData = output.fileHandleForReading.readDataToEndOfFile()
  let errorData = error.fileHandleForReading.readDataToEndOfFile()
  let outputText = String(data: outputData, encoding: .utf8) ?? ""
  let errorText = String(data: errorData, encoding: .utf8) ?? ""

  guard process.terminationStatus == 0 || allowFailure else {
    throw DriverError(
      """
      \(executable) \(arguments.joined(separator: " ")) failed with exit \(process.terminationStatus)
      \(errorText.isEmpty ? outputText : errorText)
      """
    )
  }

  return outputText
}
