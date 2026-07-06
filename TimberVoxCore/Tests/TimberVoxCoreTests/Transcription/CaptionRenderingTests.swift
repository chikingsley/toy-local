import XCTest

@testable import TimberVoxCore

final class CaptionRenderingTests: XCTestCase {
  func testDecodesCloudJobResultIntoCaptionDocument() throws {
    let document = try fixtureDocument("speaker_job_result")

    XCTAssertEqual(document.transcript, "Hello world. Good morning.")
    XCTAssertEqual(document.provider, "deepgram")
    XCTAssertEqual(document.model, "deepgram-nova-3")
    XCTAssertEqual(document.turns.count, 2)
    XCTAssertEqual(document.turns[0].speakerID, "speaker_0")
    XCTAssertEqual(document.turns[0].words[0].confidence, 0.98)
  }

  func testRendersTextWithTimestampsAndSpeakers() throws {
    let document = try fixtureDocument("speaker_job_result")

    let text = CaptionRenderer.renderText(document, includeTimestamps: true, includeSpeakers: true)

    XCTAssertEqual(
      text,
      """
      00:00:00,000 --> 00:00:01,200 [Speaker 0]
      Hello world.

      00:00:01,400 --> 00:00:02,400 [Speaker 1]
      Good morning.

      """
    )
  }

  func testRendersSRTAndWebVTTCaptions() throws {
    let document = try fixtureDocument("speaker_job_result")
    let options = CaptionRenderOptions(includeSpeakers: true)

    let srt = try CaptionRenderer.render(document, format: .srt, options: options)
    let vtt = try CaptionRenderer.render(document, format: .vtt(includeCueIDs: true), options: options)

    XCTAssertTrue(srt.hasPrefix("1\n00:00:00,000 --> 00:00:01,200\nSpeaker 0: Hello world."))
    XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\ncue-1\n00:00:00.000 --> 00:00:01.200\n<v Speaker 0>Hello world."))
  }

  func testBuildsFullCaptionArtifactContract() throws {
    let document = try fixtureDocument("speaker_job_result")

    let artifacts = try CaptionRenderer.buildArtifacts(document)

    let textVariants = ["plain", "speakers", "timestamps", "timestamps-speakers"]
    let textFormats = ["docx", "html", "json", "md", "pdf", "txt"]
    let expectedNames = Set(
      textFormats.flatMap { format in
        textVariants.map { variant in "transcript.\(variant).\(format)" }
      }
        + ["srt", "vtt"].flatMap { format in
          ["plain", "speakers"].map { variant in "transcript.\(variant).\(format)" }
        }
    )

    XCTAssertEqual(artifacts.count, 28)
    XCTAssertEqual(Set(artifacts.map(\.name)), expectedNames)
    XCTAssertEqual(try artifact(artifacts, "transcript.plain.txt").encoding, .utf8)
    XCTAssertTrue(try XCTUnwrap(artifact(artifacts, "transcript.plain.md").text).hasPrefix("# Transcript"))
    XCTAssertTrue(try XCTUnwrap(artifact(artifacts, "transcript.plain.html").text).contains("<!DOCTYPE html>"))
    XCTAssertEqual(
      String(data: try artifact(artifacts, "transcript.plain.pdf").data.prefixData(4), encoding: .utf8),
      "%PDF"
    )
    XCTAssertEqual(
      String(data: try artifact(artifacts, "transcript.plain.docx").data.prefixData(2), encoding: .utf8),
      "PK"
    )
    XCTAssertTrue(try XCTUnwrap(artifact(artifacts, "transcript.plain.srt").text).hasPrefix("1\n"))
    XCTAssertTrue(try XCTUnwrap(artifact(artifacts, "transcript.plain.vtt").text).hasPrefix("WEBVTT"))

    let jsonData = try XCTUnwrap(artifact(artifacts, "transcript.timestamps-speakers.json").text?.data(using: .utf8))
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
    let words = try XCTUnwrap(json["words"] as? [[String: Any]])
    let segments = try XCTUnwrap(json["segments"] as? [[String: Any]])
    XCTAssertEqual(words.first?["speaker"] as? String, "speaker_0")
    XCTAssertEqual(segments.first?["speaker"] as? String, "speaker_0")
    XCTAssertNotNil(words.first?["start"])
    XCTAssertNotNil(words.first?["end"])
  }

  func testDefaultCaptionCueOptionsMatchReferenceContract() {
    let options = CaptionRenderOptions()

    XCTAssertEqual(options.maxCharsPerLine, 42)
    XCTAssertEqual(options.maxLinesPerCue, 2)
    XCTAssertEqual(options.maxSecondsPerCue, 7)
    XCTAssertEqual(options.strategy, .speakerSegments)
  }

  func testTextOnlyTranscriptCanRenderTXTButTimedCaptionsThrow() throws {
    let document = try fixtureDocument("text_only_job_result")

    XCTAssertEqual(
      CaptionRenderer.renderText(document),
      "A transcript without timestamps.\n"
    )
    XCTAssertThrowsError(try CaptionRenderer.render(document, format: .srt)) { error in
      XCTAssertEqual(error as? CaptionRenderingError, .missingTimedTranscript)
    }
    XCTAssertThrowsError(try CaptionRenderer.buildArtifacts(document, formats: [.srt])) { error in
      XCTAssertEqual(error as? CaptionRenderingError, .missingTimedTranscript)
    }
  }

  private func fixtureDocument(_ key: String) throws -> CaptionDocument {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "CaptionRenderingFixtures", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let value = try XCTUnwrap(root?[key])
    let fixtureData = try JSONSerialization.data(withJSONObject: value)
    return try CaptionDocument(jobResultData: fixtureData)
  }

  private func artifact(_ artifacts: [CaptionArtifact], _ name: String) throws -> CaptionArtifact {
    try XCTUnwrap(artifacts.first { $0.name == name }, "Missing \(name)")
  }
}

private extension Data {
  func prefixData(_ count: Int) -> Data {
    Data(prefix(count))
  }
}
