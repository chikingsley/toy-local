import XCTest

@testable import TimberVoxCore

final class TranscriptionPipelineTests: XCTestCase {
  func testPipelineCanRunASROnly() async throws {
    let pipeline = TranscriptionPipeline { _, request in
      TranscriptionDraft(text: "raw transcript", providerID: .fluidAudio, modelID: request.modelID)
    }

    let result = try await pipeline.run(
      source: AudioSource(url: URL(fileURLWithPath: "/tmp/sample.wav")),
      transcriptionRequest: TranscriptionRequest(modelID: FluidAudioModels.parakeetTdtV3.id)
    )

    XCTAssertEqual(result.text, "raw transcript")
    XCTAssertNil(result.transform)
  }

  func testPipelineCanRunASRThenTextTransform() async throws {
    let pipeline = TranscriptionPipeline(
      transcribe: { _, request in
        TranscriptionDraft(text: "raw transcript", providerID: .fluidAudio, modelID: request.modelID)
      },
      complete: { request in
        XCTAssertEqual(request.messages.map(\.role), [.system, .user])
        XCTAssertTrue(request.messages.last?.content.contains("INSTRUCTIONS:") == true)
        XCTAssertTrue(request.messages.last?.content.contains("USER MESSAGE:\nraw transcript") == true)
        return TextCompletion(text: "clean transcript", providerID: .openAI, modelID: request.modelID)
      }
    )

    let result = try await pipeline.run(
      source: AudioSource(url: URL(fileURLWithPath: "/tmp/sample.wav")),
      transcriptionRequest: TranscriptionRequest(modelID: FluidAudioModels.parakeetTdtV3.id),
      transformRequest: TranscriptTransformRequest(
        modelID: "gpt-example",
        preset: .custom("Clean this up.")
      )
    )

    XCTAssertEqual(result.text, "clean transcript")
    XCTAssertEqual(result.draft.text, "raw transcript")
    XCTAssertEqual(result.transform?.modelID, "gpt-example")
  }

  func testCustomTransformCanOptIntoApplicationAndClipboardContext() async throws {
    let context = DictationContext(
      application: ApplicationContext(
        name: "Mail",
        category: "Email",
        description: "Email client",
        textInputFormat: "email"
      ),
      focusedElement: FocusedElementContext(role: "Input field", title: "Body", description: "Message body"),
      selectedText: "selected sentence",
      clipboardText: "copied paragraph",
      vocabulary: ["TimberVox"],
      system: SystemContext(language: "English", currentTime: "July 1, 2026 at 9:00 AM"),
      user: UserContext(fullName: "Test User")
    )

    let pipeline = TranscriptionPipeline(
      transcribe: { _, request in
        TranscriptionDraft(text: "raw transcript", providerID: .fluidAudio, modelID: request.modelID)
      },
      complete: { request in
        let body = try XCTUnwrap(request.messages.last?.content)
        XCTAssertTrue(body.contains("APPLICATION CONTEXT:"))
        XCTAssertTrue(body.contains("User is currently using Mail"))
        XCTAssertTrue(body.contains("Selected Text Context: selected sentence"))
        XCTAssertTrue(body.contains("Use the copied text as context"))
        XCTAssertTrue(body.contains("copied paragraph"))
        XCTAssertTrue(body.contains("Names and Usernames: TimberVox"))
        return TextCompletion(text: "clean transcript", providerID: .openAI, modelID: request.modelID)
      }
    )

    _ = try await pipeline.run(
      source: AudioSource(url: URL(fileURLWithPath: "/tmp/sample.wav")),
      transcriptionRequest: TranscriptionRequest(modelID: FluidAudioModels.parakeetTdtV3.id),
      transformRequest: TranscriptTransformRequest(
        modelID: "gpt-example",
        preset: .custom("Rewrite this as a short email."),
        context: context,
        contextOptions: DictationContextOptions(
          includeApplicationContext: true,
          includeSelectionContext: true,
          includeClipboardContext: true
        )
      )
    )
  }

  func testContextOptionsControlWhichContextIsIncluded() {
    let context = DictationContext(
      application: ApplicationContext(name: "Mail"),
      selectedText: "selected sentence",
      clipboardText: "copied paragraph"
    )

    let body = TextTransformPromptBuilder.userMessage(
      preset: .custom("Rewrite this."),
      transcript: "raw transcript",
      context: context,
      contextOptions: DictationContextOptions(includeClipboardContext: true)
    )

    XCTAssertFalse(body.contains("APPLICATION CONTEXT:"))
    XCTAssertFalse(body.contains("Selected Text Context"))
    XCTAssertTrue(body.contains("copied paragraph"))
  }

  func testPromptBuilderExpandsContextAndTranscript() {
    let context = DictationContext(application: ApplicationContext(name: "Notes"))

    let messages = TextTransformPromptBuilder.messages(
      preset: .custom("Clean it."),
      transcript: "raw transcript",
      context: context,
      contextOptions: DictationContextOptions(includeApplicationContext: true)
    )

    XCTAssertTrue(messages.first?.content.contains("follow these and do what they say") == true)
    XCTAssertTrue(messages.last?.content.contains("INSTRUCTIONS:\nClean it.") == true)
    XCTAssertTrue(messages.last?.content.contains("User is currently using Notes") == true)
    XCTAssertTrue(messages.last?.content.contains("USER MESSAGE:\nraw transcript") == true)
    XCTAssertFalse(messages.last?.content.contains("{{user_message}}") == true)
  }

  func testPromptBuilderIncludesScreenTextWhenApplicationContextIsEnabled() {
    let context = DictationContext(
      application: ApplicationContext(
        name: "Mail",
        screenText: "Invoice total due Friday"
      )
    )

    let body = TextTransformPromptBuilder.userMessage(
      preset: .custom("Use the visible screen context."),
      transcript: "reply to this",
      context: context,
      contextOptions: DictationContextOptions(includeApplicationContext: true)
    )

    XCTAssertTrue(body.contains("Screen text: Invoice total due Friday"))
  }

  func testTextTransformOutputNormalizerRemovesSuperWhisperResponseTags() {
    XCTAssertEqual(
      TextTransformOutputNormalizer.normalize(" <sw_response_content>Clean transcript.</sw_response_content> "),
      "Clean transcript."
    )
  }

  func testUnknownTemplateMacrosAreLeftForDebugVisibility() {
    let rendered = TextTransformPromptBuilder.render("Known {{user_message}} unknown {{missing}}", values: ["user_message": "hello"])

    XCTAssertEqual(rendered, "Known hello unknown {{missing}}")
  }

  func testPipelineRequiresTextProviderWhenTransformIsRequested() async throws {
    let pipeline = TranscriptionPipeline { _, request in
      TranscriptionDraft(text: "raw transcript", providerID: .fluidAudio, modelID: request.modelID)
    }

    do {
      _ = try await pipeline.run(
        source: AudioSource(url: URL(fileURLWithPath: "/tmp/sample.wav")),
        transcriptionRequest: TranscriptionRequest(modelID: FluidAudioModels.parakeetTdtV3.id),
        transformRequest: TranscriptTransformRequest(
          modelID: "gpt-example",
          preset: .custom("Clean this up.")
        )
      )
      XCTFail("Expected missing text provider to throw")
    } catch let error as TranscriptionPipelineError {
      XCTAssertEqual(error, .textProviderRequired)
    }
  }

  func testKnownTranscriptionModelSpecsIncludeLocalAndCloudModels() {
    XCTAssertTrue(FluidAudioModels.transcriptionModels.contains { $0.id == FluidAudioModels.parakeetTdtV3.id })
    XCTAssertTrue(FluidAudioModels.transcriptionModels.contains { $0.id == FluidAudioModels.parakeetEou160.id })
    XCTAssertTrue(FluidAudioModels.transcriptionModels.contains { $0.id == FluidAudioModels.sileroVad.id })
    XCTAssertTrue(TranscriptionModelCatalog.all.contains { $0.id == FluidAudioModels.parakeetTdtV3.id })
    XCTAssertTrue(TranscriptionModelCatalog.all.contains { $0.id == CloudTranscriptionModels.deepgramNova3.id })
  }

  func testBuiltInTextTransformPresetsMatchExpectedInventory() {
    XCTAssertEqual(
      TextTransformPreset.builtIns.map(\.id),
      [.superPrompt, .messagePrompt, .notePrompt, .emailPrompt, .meetingPrompt]
    )
    XCTAssertTrue(TextTransformPreset.builtIns.allSatisfy { !$0.instructions.isEmpty })
  }
}
