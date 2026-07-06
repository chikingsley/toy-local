import TimberVoxCore
import Foundation
import Yams

struct SuiteDefinition: Decodable {
  let name: String
  let target: Target?
  let steps: [SuiteStep]
}

enum SuiteStep: Decodable {
  case quit
  case resetTCC
  case launch
  case checkPermissions
  case showOnboarding
  case pressButton(String)
  case pressButtonText(String)
  case assertElement(String)
  case assertButtonText(String)
  case assertText(String)
  case assertState(StateExpectation)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      switch string {
      case "quit":
        self = .quit
      case "resetTCC":
        self = .resetTCC
      case "launch":
        self = .launch
      case "checkPermissions":
        self = .checkPermissions
      case "showOnboarding":
        self = .showOnboarding
      default:
        throw DriverError("Unknown suite step: \(string)")
      }
      return
    }

    let keyed = try decoder.container(keyedBy: CodingKeys.self)
    if keyed.contains(.pressButton) {
      self = .pressButton(try keyed.decode(String.self, forKey: .pressButton))
      return
    }
    if keyed.contains(.pressButtonText) {
      self = .pressButtonText(try keyed.decode(String.self, forKey: .pressButtonText))
      return
    }
    if keyed.contains(.assertElement) {
      self = .assertElement(try keyed.decode(String.self, forKey: .assertElement))
      return
    }
    if keyed.contains(.assertButtonText) {
      self = .assertButtonText(try keyed.decode(String.self, forKey: .assertButtonText))
      return
    }
    if keyed.contains(.assertText) {
      self = .assertText(try keyed.decode(String.self, forKey: .assertText))
      return
    }
    if keyed.contains(.assertState) {
      self = .assertState(try keyed.decode(StateExpectation.self, forKey: .assertState))
      return
    }
    throw DriverError("Unknown suite step mapping")
  }

  private enum CodingKeys: String, CodingKey {
    case pressButton
    case pressButtonText
    case assertElement
    case assertButtonText
    case assertText
    case assertState
  }
}

struct SuiteRunner {
  func run(suite: String, targetOverride: Target?) throws {
    let definition = try loadSuite(namedOrPath: suite)
    let target = targetOverride ?? definition.target ?? .debug
    let app = AppControl(target: target)

    print("Running suite \(definition.name) against \(target.rawValue)")
    for (index, step) in definition.steps.enumerated() {
      print("[\(index + 1)/\(definition.steps.count)] \(step.label)")
      try run(step: step, app: app)
    }
    print("Suite \(definition.name) passed")
  }

  private func run(step: SuiteStep, app: AppControl) throws {
    let ax = AXDriver(app: app)
    switch step {
    case .quit:
      app.quit()
      Thread.sleep(forTimeInterval: 1)
    case .resetTCC:
      app.resetTCC(services: TCCService.allCases)
    case .launch:
      try app.launch()
      Thread.sleep(forTimeInterval: 2)
    case .checkPermissions:
      try app.openURL("timbervox-debug://check-permissions")
      Thread.sleep(forTimeInterval: 1)
    case .showOnboarding:
      try app.openURL("timbervox-debug://show-onboarding")
      Thread.sleep(forTimeInterval: 1)
    case .pressButton(let identifier):
      try ax.pressButton(identifier: identifier)
      Thread.sleep(forTimeInterval: 0.5)
    case .pressButtonText(let text):
      try ax.pressButton(text: text)
      Thread.sleep(forTimeInterval: 0.5)
    case .assertElement(let identifier):
      try ax.assertElement(identifier: identifier)
    case .assertButtonText(let text):
      try ax.assertButton(text: text)
    case .assertText(let text):
      try ax.assertText(text)
    case .assertState(let expectation):
      let snapshot = try app.requestState()
      try assertState(snapshot, matches: expectation)
    }
  }

  private func loadSuite(namedOrPath suite: String) throws -> SuiteDefinition {
    let explicitURL = URL(fileURLWithPath: suite)
    let suiteURL: URL
    if FileManager.default.fileExists(atPath: explicitURL.path) {
      suiteURL = explicitURL
    } else {
      suiteURL = URL.repoRoot
        .appendingPathComponent("Suites", isDirectory: true)
        .appendingPathComponent("\(suite).yaml")
    }

    guard FileManager.default.fileExists(atPath: suiteURL.path) else {
      throw DriverError("Suite not found: \(suiteURL.path)")
    }

    let yaml = try String(contentsOf: suiteURL, encoding: .utf8)
    return try YAMLDecoder().decode(SuiteDefinition.self, from: yaml)
  }
}

private extension SuiteStep {
  var label: String {
    switch self {
    case .quit:
      "quit"
    case .resetTCC:
      "resetTCC"
    case .launch:
      "launch"
    case .checkPermissions:
      "checkPermissions"
    case .showOnboarding:
      "showOnboarding"
    case .pressButton(let identifier):
      "pressButton \(identifier)"
    case .pressButtonText(let text):
      "pressButtonText \(text)"
    case .assertElement(let identifier):
      "assertElement \(identifier)"
    case .assertButtonText(let text):
      "assertButtonText \(text)"
    case .assertText(let text):
      "assertText \(text)"
    case .assertState:
      "assertState"
    }
  }
}
