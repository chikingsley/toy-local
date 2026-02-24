# Future Ideas & Tasks

## Priority: Settings & UX Overhaul

### Word Remappings UX (High Priority)

- Remappings are the most-used feature — shouldn't be buried in a second tab
- **Add button at the top**, not bottom (currently must scroll past hundreds of entries)
- **Enter / click-away to confirm** — currently stuck in edit mode with no way to dismiss
- Better edit pattern: clickable rows with a sidebar/panel that opens for editing (match + replacement fields), dismiss to save
- Consider making remappings the default/first tab, or promoting to a top-level settings section

### Hotkeys & Modes Redesign (High Priority)

- Current hotkey UI takes up the whole screen for one key — wasteful
- **Reorganize into two sections**:
  - **Push to Talk** — single hotkey (hold to record, release to paste)
  - **Hot Mic (Always-On)** — paste hotkey + dump hotkey
- **Dump hotkey not settable** currently — needs UI
- **Three recording modes** (toggle in settings):
  1. Click-to-start / click-to-paste (tap toggle)
  2. Hold-to-record / release-to-paste (push-to-talk)
  3. Always-on (hot mic)
- All keyboard shortcuts on **one screen** — paste last transcript hotkey should be here too, not scattered
- Reference: SuperWhisper and Wispr Flow for UI patterns

### Dump Action Visual Feedback (High Priority)

- When dump hotkey is pressed, need clear visual confirmation that the buffer was cleared
- Ideas: pill flashes red briefly, shows "Dumped" text, shake animation, or a brief strikethrough on the text before it disappears
- Currently no feedback at all — user has no idea if the dump registered

### Model Picker Improvements

- Streaming model (Parakeet) not labeled in the model list
- "Accuracy" vs "Speed" bars are all maxed out — not informative
- Better labels: "Best for English", "Best for multilingual", "Real-time streaming"
- Show actual differentiators: latency, language support, model size, streaming vs batch

## Priority: LLM Output Parsing

### Send Transcript to LLM (High Priority)

- SuperWhisper pattern: configurable output modes per use case
- User sets an API key (OpenRouter, Claude, OpenAI, local endpoint)
- Transcript goes through LLM before pasting — can reformat, clean up, summarize
- Two fields: system prompt + API config
- Modes: "Raw transcript", "Clean prose", "Meeting notes", "Code dictation", custom
- Could be a per-hotkey setting (different hotkeys → different output modes)

## Feature Ideas

### Always-On Voice Commands / Trigger Words

- Extend always-on mode with configurable trigger words/phrases
- Detection is simple: after transcription, lowercase text and match against a phrase list
- Default phrases: "go ahead" / "submit" → flush buffer, "stop" / "cancel" → dump buffer, "paste" → paste immediately
- System commands: "open [app]", "quit [app]", "play pause", "volume up/down", "lock", "sleep"
- AppleScript-based execution — we already have the plumbing for this
- User-configurable phrase → action mappings in settings
- Key vs word trigger — same mechanism, both just trigger an action on match

### Send-to-Server Mode

- Say a trigger word (e.g. "hey server") and everything after goes to a configurable endpoint instead of pasting locally
- Use case: "hey server, find the new email that just came in" → POST to gmk-server or n8n webhook
- Configurable endpoints (URL, auth headers)
- Could route to different servers based on different trigger words
- Visual indicator (different color?) when in "server mode" vs normal paste mode

### Quick LLM Q&A (Voice → Model → TTS)

- Transcribe voice → send to an LLM (OpenRouter, local model, Claude API) → get response back as TTS
- For quick questions where you don't need a full IDE/terminal workflow
- Hook up OpenRouter or local ollama/vllm endpoint
- Response delivered via macOS TTS (`say` command) or a small overlay window
- Could also just paste the response as text if preferred

### Alternative ASR Models (Qwen)

- Add Qwen3-ASR-0.6B-8bit as an optional transcription backend via MLX
- Field Theory runs it as a persistent Python server (stdin/stdout JSON protocol)
- Model: `mlx-community/Qwen3-ASR-0.6B-8bit`, framework: `mlx-audio`
- Could integrate similarly — bundle a Python script, spawn a server process, keep model loaded
- Worth testing accuracy vs Parakeet/WhisperKit
- Requires Python 3.10+ and Apple Silicon

### Editable Transcripts / Smart Remappings

- MacWhisper-style transcript editing — click into a transcript in history, edit it
- Edits that change specific words could auto-suggest new word remappings
- Example: you consistently change "cuz" → "because" in transcripts → suggest adding it as a remapping
- Could also learn from corrections over time (frequency-based suggestions)
- UI for quickly adding words to remapping/removal lists from the transcript view

### Richer History

- Categorize entries by source type: voice transcription, clipboard paste, screenshot, link
- Visual icons/badges for each type (like Field Theory's four-corner icons)
- Full-text search across history (SQLite FTS or in-memory)
- Click-to-copy with visual feedback (cursor dot or brief highlight)

### Cursor Status Indicator

- Small colored dot near cursor during transcription states
- Green = done, blue = recording, red = error
- Shows briefly (~800ms) then fades
- Less intrusive than the current floating indicator for quick interactions

---

## Research Notes

### Field Theory Architecture Reference

- **Qwen ASR**: `mlx-community/Qwen3-ASR-0.6B-8bit` via `mlx-audio` Python package
- **No streaming inference** — batch mode with VAD-segmented audio chunks
- **Trigger detection**: Pure string matching post-transcription, not model-level
- **VLM (separate)**: `mlx-community/nanoLLaVA` for screenshot captioning, unrelated to ASR
- **Whisper fallback**: Bundled `whisper-cli` (whisper.cpp compiled binary) as backup engine
- **Native helper**: Swift binary handles mic access, VAD, WAV recording
- **Claude Code integration**: Writes hooks to `~/.claude/settings.json` for auto-approved file reads

### UI References to Study

- **SuperWhisper**: Output modes (raw, clean, custom LLM), API key config, per-mode settings
- **Wispr Flow**: Hotkey setup, mode switching UI
- **MacWhisper**: Transcript editing, history management
