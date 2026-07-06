import Foundation

struct CLI {
  let arguments: [String]

  func run() async throws {
    guard let command = arguments.first else {
      print(Self.helpText)
      return
    }

    let options = try Options(Array(arguments.dropFirst()))
    switch command {
    case "help", "--help", "-h":
      print(Self.helpText)
    case "inventory":
      try writeInventory(options: options)
    case "runs":
      try writeRunIndex(options: options)
    case "coverage":
      try writeCoverage(options: options)
    case "artifacts":
      try writeArtifactReport(options: options)
    case "asr":
      try await runASR(options: options)
    case "vad":
      try await runVAD(options: options)
    case "diarize":
      try await runDiarization(options: options)
    case "keyword":
      try await runKeyword(options: options)
    case "deepgram":
      try await runDeepgram(options: options)
    case "diagnostics":
      try await runDiagnostics(options: options)
    case "suite":
      try await runSuite(options: options)
    default:
      throw CLIError("unknown command: \(command)\n\n\(Self.helpText)")
    }
  }

  private func writeInventory(options: Options) throws {
    let output = InventoryOutput(
      generatedAt: Date(),
      fluidAudioVersion: "0.15.4",
      models: ModelInventory.all
    )
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "inventory", modelID: "fluidaudio")
    try run.writeJSON(output, filename: "result.json")
    try run.writeJSON(RunSummary(command: "inventory", modelID: "fluidaudio", status: "ok", resultPath: run.url.path), filename: "summary.json")
    print(run.url.path)
  }

  private func writeRunIndex(options: Options) throws {
    let outputRoot = try options.outputRoot()
    let index = try RunIndex.build(outputRoot: outputRoot)
    let indexURL = outputRoot.appendingPathComponent("index.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(index).write(to: indexURL, options: .atomic)
    print(indexURL.path)
  }

  private func writeCoverage(options: Options) throws {
    let outputRoot = try options.outputRoot()
    _ = try RunIndex.build(outputRoot: outputRoot)
    let coverage = try Coverage.build(outputRoot: outputRoot)
    let coverageURL = outputRoot.appendingPathComponent("coverage.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(coverage).write(to: coverageURL, options: .atomic)
    print(coverageURL.path)
  }

  private func writeArtifactReport(options: Options) throws {
    let outputRoot = try options.outputRoot()
    let report = try ArtifactReport.build(outputRoot: outputRoot)
    let reportURL = outputRoot.appendingPathComponent("artifacts.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(report).write(to: reportURL, options: .atomic)
    print(reportURL.path)
  }

  private func runASR(options: Options) async throws {
    let model = try options.required("model")
    let audio = try options.audioURL()
    let input = RunInput(command: "asr", modelID: model, audioPath: audio.path, options: options.dictionary)
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "asr", modelID: model)
    let progressLog = try ProbeProgressLog(runURL: run.url)
    defer { progressLog.close() }
    try run.writeJSON(input, filename: "input.json")

    do {
      let result = try await LocalASRProbe.run(modelID: model, audioURL: audio, progressHandler: progressLog.downloadHandler())
      try run.writeJSON(result, filename: "result.json")
      try run.writeJSON(RunSummary(command: "asr", modelID: model, status: "ok", resultPath: run.url.path), filename: "summary.json")
      print(run.url.path)
    } catch {
      try writeFailure(error, command: "asr", modelID: model, run: run)
      throw error
    }
  }

  private func runVAD(options: Options) async throws {
    let audio = try options.audioURL()
    let model = "silero-vad"
    let input = RunInput(command: "vad", modelID: model, audioPath: audio.path, options: options.dictionary)
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "vad", modelID: model)
    let progressLog = try ProbeProgressLog(runURL: run.url)
    defer { progressLog.close() }
    try run.writeJSON(input, filename: "input.json")

    do {
      let result = try await VADProbe.run(audioURL: audio, progressHandler: progressLog.downloadHandler())
      try run.writeJSON(result, filename: "result.json")
      try run.writeJSON(RunSummary(command: "vad", modelID: model, status: "ok", resultPath: run.url.path), filename: "summary.json")
      print(run.url.path)
    } catch {
      try writeFailure(error, command: "vad", modelID: model, run: run)
      throw error
    }
  }

  private func runDiarization(options: Options) async throws {
    let model = try options.required("model")
    let audio = try options.audioURL()
    let input = RunInput(command: "diarize", modelID: model, audioPath: audio.path, options: options.dictionary)
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "diarize", modelID: model)
    let progressLog = try ProbeProgressLog(runURL: run.url)
    defer { progressLog.close() }
    try run.writeJSON(input, filename: "input.json")

    do {
      let result = try await DiarizationProbe.run(modelID: model, audioURL: audio, progressLog: progressLog)
      try run.writeJSON(result, filename: "result.json")
      try run.writeJSON(RunSummary(command: "diarize", modelID: model, status: "ok", resultPath: run.url.path), filename: "summary.json")
      print(run.url.path)
    } catch {
      try writeFailure(error, command: "diarize", modelID: model, run: run)
      throw error
    }
  }

  private func runKeyword(options: Options) async throws {
    let audio = try options.audioURL()
    let terms = try options.required("terms")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let model = options.value("model") ?? "ctc110m"
    let input = RunInput(command: "keyword", modelID: model, audioPath: audio.path, options: options.dictionary)
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "keyword", modelID: model)
    let progressLog = try ProbeProgressLog(runURL: run.url)
    defer { progressLog.close() }
    try run.writeJSON(input, filename: "input.json")

    do {
      let result = try await KeywordProbe.run(modelID: model, audioURL: audio, terms: terms)
      try run.writeJSON(result, filename: "result.json")
      try run.writeJSON(RunSummary(command: "keyword", modelID: model, status: "ok", resultPath: run.url.path), filename: "summary.json")
      print(run.url.path)
    } catch {
      try writeFailure(error, command: "keyword", modelID: model, run: run)
      throw error
    }
  }

  private func runDeepgram(options: Options) async throws {
    let audio = try options.audioURL()
    let model = options.value("model") ?? "nova-3"
    let diarize = options.bool("diarize") ?? false
    let apiKey =
      options.value("api-key")
      ?? ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"]
      ?? ProcessInfo.processInfo.environment["DG_API_KEY"]
    guard let apiKey, !apiKey.isEmpty else {
      throw CLIError("missing Deepgram key. Set DEEPGRAM_API_KEY or pass --api-key.")
    }

    let input = RunInput(command: "deepgram", modelID: model, audioPath: audio.path, options: options.redacted(["api-key"]))
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "deepgram", modelID: "\(model)-diarize-\(diarize)")
    try run.writeJSON(input, filename: "input.json")

    do {
      let result = try await DeepgramProbe(apiKey: apiKey).run(model: model, diarize: diarize, audioURL: audio)
      try run.writeJSON(result.normalized, filename: "result.json")
      try run.writeData(result.rawJSON, filename: "raw.json")
      try run.writeJSON(RunSummary(command: "deepgram", modelID: model, status: "ok", resultPath: run.url.path), filename: "summary.json")
      print(run.url.path)
    } catch {
      try writeFailure(error, command: "deepgram", modelID: model, run: run)
      throw error
    }
  }

  private func runSuite(options: Options) async throws {
    let audio = try options.audioURL()
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "suite", modelID: "local-smoke")
    let suite = try await SuiteProbe.run(audioURL: audio, includeHeavy: options.bool("include-heavy") ?? false)
    try run.writeJSON(RunInput(command: "suite", modelID: "local-smoke", audioPath: audio.path, options: options.dictionary), filename: "input.json")
    try run.writeJSON(suite, filename: "result.json")
    try run.writeJSON(RunSummary(command: "suite", modelID: "local-smoke", status: "ok", resultPath: run.url.path), filename: "summary.json")
    print(run.url.path)
  }

  private func runDiagnostics(options: Options) async throws {
    let audio = try options.audioURL()
    let scope = options.value("scope") ?? "quick"
    let models = try DiagnosticsRunner.selectedModels(
      scope: scope,
      explicitModels: options.csv("models")
    )
    let keywordTerms = options.csv("terms")
    let terms = keywordTerms.isEmpty ? ["TimberVox", "FluidAudio", "Parakeet"] : keywordTerms
    let deepgramApiKey =
      options.value("api-key")
      ?? ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"]
      ?? ProcessInfo.processInfo.environment["DG_API_KEY"]
    let store = try RunStore(outputRoot: options.outputRoot())
    let run = try store.createRun(command: "diagnostics", modelID: scope)
    let input = DiagnosticsInput(
      audioPath: audio.path,
      scope: scope,
      requestedModels: models.map(\.id),
      keywordTerms: terms,
      includeCloud: models.contains { $0.runtime == "cloud" }
    )
    try run.writeJSON(input, filename: "input.json")

    let report = await DiagnosticsRunner.run(
      audioURL: audio,
      scope: scope,
      models: models,
      keywordTerms: terms,
      deepgramApiKey: deepgramApiKey
    )
    try run.writeJSON(report, filename: "result.json")
    try run.writeJSON(report, filename: "diagnostics.json")
    try run.writeJSON(
      RunSummary(command: "diagnostics", modelID: scope, status: "ok", resultPath: run.url.path),
      filename: "summary.json"
    )
    print(run.url.path)
  }

  private func writeFailure(_ error: Error, command: String, modelID: String, run: RunDirectory) throws {
    let message: String
    if let cliError = error as? CLIError {
      message = cliError.message
    } else {
      message = error.localizedDescription
    }
    try run.writeJSON(
      ProbeFailure(
        status: "failed",
        command: command,
        modelID: modelID,
        message: message,
        errorType: String(describing: type(of: error))
      ),
      filename: "result.json"
    )
    try run.writeJSON(
      RunSummary(command: command, modelID: modelID, status: "failed", resultPath: run.url.path),
      filename: "summary.json"
    )
  }

  static let helpText = """
  TimberVoxBackendPrototype

  Commands:
    inventory
    runs
    coverage
    artifacts
    asr --model <id> --audio <path>
    vad --audio <path>
    diarize --model <id> --audio <path>
    keyword --terms "FluidAudio,Parakeet" --audio <path> [--model ctc110m|ctc06b]
    deepgram --model nova-3 --audio <path> [--diarize true]
    diagnostics --audio <path>
      [--scope quick|supported-local|asr|support|cloud]
      [--models id,id] [--terms "TimberVox,FluidAudio"]
    suite --audio <path> [--include-heavy true]

  Common options:
    --out <dir>       Run output root. Default: TimberVoxBackendPrototype/Runs
  """
}

struct Options {
  let dictionary: [String: String]

  init(_ args: [String]) throws {
    var values: [String: String] = [:]
    var index = 0
    while index < args.count {
      let item = args[index]
      guard item.hasPrefix("--") else {
        throw CLIError("unexpected argument: \(item)")
      }
      let key = String(item.dropFirst(2))
      if index + 1 < args.count, !args[index + 1].hasPrefix("--") {
        values[key] = args[index + 1]
        index += 2
      } else {
        values[key] = "true"
        index += 1
      }
    }
    self.dictionary = values
  }

  func value(_ key: String) -> String? {
    dictionary[key]
  }

  func required(_ key: String) throws -> String {
    guard let value = dictionary[key], !value.isEmpty else {
      throw CLIError("missing required option --\(key)")
    }
    return value
  }

  func bool(_ key: String) -> Bool? {
    guard let value = dictionary[key] else { return nil }
    switch value.lowercased() {
    case "true", "1", "yes", "y": return true
    case "false", "0", "no", "n": return false
    default: return nil
    }
  }

  func csv(_ key: String) -> [String] {
    guard let value = dictionary[key], !value.isEmpty else {
      return []
    }

    return value.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  func audioURL() throws -> URL {
    let path = try required("audio")
    return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
  }

  func outputRoot() throws -> URL {
    if let out = dictionary["out"] {
      return URL(fileURLWithPath: out, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
    }
    let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return packageRoot.appendingPathComponent("Runs", isDirectory: true)
  }

  func redacted(_ keys: Set<String>) -> [String: String] {
    dictionary.mapValues { $0 }.merging(Dictionary(uniqueKeysWithValues: keys.map { ($0, "[redacted]") })) { _, new in new }
  }
}

struct CLIError: Error {
  let message: String
  let exitCode: Int

  init(_ message: String, exitCode: Int = 1) {
    self.message = message
    self.exitCode = exitCode
  }
}
