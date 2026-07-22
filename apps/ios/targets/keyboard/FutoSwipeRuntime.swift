import CoreGraphics
import Foundation
import OSLog

enum FutoSwipeRuntimeError: Error {
  case contextModelUnavailable
  case invalidEncoderOutput
  case invalidRefinerOutput
  case missingModel(String)
}

final class FutoSwipeRuntime {
  private static let logger = Logger(
    subsystem: "studio.peacockery.timbervox.keyboard",
    category: "FutoSwipeRuntime"
  )
  private static let encoderClassCount = 65
  private static let outputTimeStepCount = 32
  private static let refinerInputWidth = 92
  private static let maximumKeyCount = 64

  private let bridge: TimberVoxExecuTorchBridge
  private let contextLock = NSLock()
  private var contextLoadStarted = false
  private var contextModel: FutoContextLanguageModel?

  init(bundle: Bundle = .main) throws {
    let encoderPath = try Self.modelPath(
      named: "futo_swipe_encoder",
      bundle: bundle
    )
    let refinerPath = try Self.modelPath(
      named: "futo_swipe_refiner",
      bundle: bundle
    )
    bridge = try TimberVoxExecuTorchBridge(
      encoderPath: encoderPath,
      refinerPath: refinerPath
    )
  }

  var supportsContext: Bool {
    contextLock.lock()
    defer { contextLock.unlock() }
    return contextModel != nil
  }

  func beginLoadingContext(
    bundle: Bundle,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    contextLock.lock()
    guard !contextLoadStarted else {
      contextLock.unlock()
      return
    }
    contextLoadStarted = true
    contextLock.unlock()

    guard
      let contextPath = bundle.path(
        forResource: "futo_swipe_context_lm",
        ofType: "pte"
      )
    else { return }

    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self else { return }
      do {
        let contextBridge = TimberVoxExecuTorchBridge()
        try contextBridge.loadContextModel(atPath: contextPath)
        let loadedModel = try FutoContextLanguageModel(
          bridge: contextBridge,
          bundle: bundle
        )
        self.contextLock.lock()
        self.contextModel = loadedModel
        self.contextLock.unlock()
        completion(.success(()))
      } catch {
        Self.logger.error(
          "FUTO context model failed to load: \(error.localizedDescription, privacy: .public)"
        )
        completion(.failure(error))
      }
    }
  }

  func contextScores(
    contextWords: [String],
    candidates: [String]
  ) throws -> [Float] {
    contextLock.lock()
    let contextModel = contextModel
    contextLock.unlock()
    guard let contextModel else {
      throw FutoSwipeRuntimeError.contextModelUnavailable
    }
    return try contextModel.scores(
      contextWords: contextWords,
      candidates: candidates
    )
  }

  func emissions(
    for samples: [SwipePoint],
    layout: KeyLayout
  ) throws -> CTCEmissionSequence {
    let trace = try SwipeInputPreprocessor.normalizedTrace(
      samples: samples,
      layoutSize: layout.size
    )
    let layoutInputs = Self.makeLayoutInputs(layout: layout)
    let encoderOutputs = try bridge.encoderOutputs(
      withFeatures: Self.data(from: trace.x + trace.y),
      keyCenters: Self.data(from: layoutInputs.centers),
      keyMask: Data(layoutInputs.mask)
    )
    guard encoderOutputs.count >= 3,
      let fullEmissionValues = Self.floats(from: encoderOutputs[0]),
      let coefficientValues = Self.floats(from: encoderOutputs[1]),
      let intentionValues = Self.floats(from: encoderOutputs[2])
    else { throw FutoSwipeRuntimeError.invalidEncoderOutput }
    guard
      fullEmissionValues.count
        == Self.outputTimeStepCount * Self.encoderClassCount,
      coefficientValues.count == Self.outputTimeStepCount * 64,
      intentionValues.count == Self.outputTimeStepCount
    else { throw FutoSwipeRuntimeError.invalidEncoderOutput }

    var refinerInput: [Float] = []
    refinerInput.reserveCapacity(Self.outputTimeStepCount * Self.refinerInputWidth)
    for timeStep in 0..<Self.outputTimeStepCount {
      let emissionOffset = timeStep * Self.encoderClassCount
      refinerInput.append(
        contentsOf: fullEmissionValues[
          emissionOffset..<(emissionOffset + CharacterOrder.count)
        ]
      )
      refinerInput.append(fullEmissionValues[emissionOffset + Self.encoderClassCount - 1])
      let coefficientOffset = timeStep * 64
      refinerInput.append(
        contentsOf: coefficientValues[
          coefficientOffset..<(coefficientOffset + 64)
        ]
      )
      refinerInput.append(intentionValues[timeStep])
    }

    let refined = try bridge.refinedEmissions(
      withInput: Self.data(from: refinerInput)
    )
    guard let probabilities = Self.floats(from: refined) else {
      throw FutoSwipeRuntimeError.invalidRefinerOutput
    }
    let classCount = CharacterOrder.count + 1
    guard probabilities.count == Self.outputTimeStepCount * classCount else {
      throw FutoSwipeRuntimeError.invalidRefinerOutput
    }
    return CTCEmissionSequence(
      classCount: classCount,
      logProbabilities: probabilities,
      timeStepCount: Self.outputTimeStepCount
    )
  }

  private static func modelPath(named name: String, bundle: Bundle) throws -> String {
    guard let path = bundle.path(forResource: name, ofType: "pte") else {
      throw FutoSwipeRuntimeError.missingModel(name)
    }
    return path
  }

  private static func makeLayoutInputs(
    layout: KeyLayout
  ) -> (centers: [Float], mask: [UInt8]) {
    var centers = [Float](repeating: 0, count: maximumKeyCount * 2)
    var mask = [UInt8](repeating: 0, count: maximumKeyCount)
    let width = max(layout.size.width, 1)
    let height = max(layout.size.height, 1)
    for (index, character) in CharacterOrder.characters.enumerated() {
      guard let frame = layout.frames[character] else { continue }
      centers[index * 2] = Float(frame.midX / width)
      centers[index * 2 + 1] = Float(frame.midY / height)
      mask[index] = 1
    }
    return (centers, mask)
  }

  private static func data(from values: [Float]) -> Data {
    values.withUnsafeBytes { Data($0) }
  }

  private static func floats(from data: Data) -> [Float]? {
    guard data.count.isMultiple(of: MemoryLayout<Float>.size) else { return nil }
    return data.withUnsafeBytes { bytes in
      Array(bytes.bindMemory(to: Float.self))
    }
  }
}
