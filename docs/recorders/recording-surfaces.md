# Recording Surfaces — Spec

Status: states/colors and mini-pill behavior AGREED (Chi, 2026-07-04).
Open questions at the bottom. Prototype work happens only against this file;
anything not covered here gets asked first, not inferred.

## The state model (settled)

One color answers one question: "what is the system doing right now?"
Captioning is NOT a state — it's a separate, optional surface (below).

| State | Color | Meaning |
|---|---|---|
| Off / idle | — (near-invisible) | Mic off. Minimal resting UI only (see mini pill); most surfaces show nothing at all. |
| Recording | **Red** | Mic hot: push-to-talk, toggle, or realtime. Streaming/realtime is STILL RED — the mic is what matters. Level-reactive pulse (Chi's existing capsule pulse — keep, it's good). |
| Processing | **Blue** | LLM pass rewriting the transcript. Slightly BIGGER than idle. Also shown when hot-mic Paste triggers its processing. |
| Hot mic (always-on) | **Green** | A different way of being on — ambient listening while speech accumulates. |
| Dump / flash actions | **Orange/yellow flash** | Momentary, not a standing state: hot-mic dump, and similar one-shot confirms. (Matches the original capsule's alwaysOnDumped orange.) |

Flow example: idle → (start) red → (finish talking) blue → back to idle.
Hot mic: green standing; Paste → blue processing moment; Dump → orange flash.

## The mini pill (the primary recorder — Chi's capsule, evolved)

Reference screenshots in this folder (superwhisper's mini window — the
model to beat, "very similar to my pill but different"):

- `superwhisper-mini-01-idle.png` — idle = a tiny dark oval/line. That's the
  whole resting UI. Chi: "I like this, keep it."
- `superwhisper-mini-02..04` — on HOVER the oval expands into a 3-button bar;
  each button has its own hover state showing a labeled tooltip beneath with
  its shortcut: ✦ = Change mode (⌥⇧K there), △ = Start recording (⌥Space),
  ⤢ = Expand window.

Agreed behavior for ours:
- Idle: tiny oval, centered at its dock. Near-invisible, no waveform, nothing.
- Hover: expands to the button bar (contents TBD — likely change-mode /
  record / open-window, hover tooltips with real shortcuts).
- Recording: transforms red, level-reactive pulse (existing
  TranscriptionIndicatorView pulse language).
- Processing: blue, slightly larger than idle.
- Hot mic: green standing state. Paste → blue moment. Dump → orange flash.
- Then back to the idle oval.

## Captioning (separate layer, not a state)

- Live captions render at the TOP of the screen, probably draggable.
- Available during recording (realtime) and hot mic.
- Keep it simple for v1: one caption surface, top-center.

## Variants

Keep ALL current stage variants as options for now (notch, caret, window
surface, snap, cursor tag, original/mini). The mini pill above is the
default/primary. Some variants may be expanded later; none deleted yet.

## Open questions (ask Chi, do not infer)

1. Mini-pill hover bar: exact three buttons + their shortcuts/tooltips.
2. Notch wing contents: probably NO buttons (color+waveform say everything),
   but Chi wants to see examples before deciding.
3. Per-variant state renderings: needs a worked table once the mini pill
   lands; Chi will judge from examples rather than specify in the abstract.
4. Caption surface details: draggable? font size? fade behavior?
5. Whether snap/cursor variants earn their keep once the mini pill has
   hover-expand.
