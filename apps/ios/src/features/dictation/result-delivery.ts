import * as Clipboard from "expo-clipboard";

import type { DictationOutcome } from "@/features/dictation/dictation-types";
import {
  readBridgeNumber,
  writeBridgeNumber,
  writeBridgeString,
} from "@/features/keyboard/app-group-bridge";

async function deliverDictationResult(outcome: DictationOutcome, text: string) {
  const deliveredText = text.trim();
  if (outcome.entryPoint === "keyboard" || outcome.entryPoint === "shortcut") {
    writeBridgeString("finalResultId", outcome.resultId);
    writeBridgeString("finalRequestId", outcome.requestId);
    writeBridgeString("finalTranscript", deliveredText);
    writeBridgeString("finalResultStatus", outcome.status);
    writeBridgeNumber(
      "transcriptRevision",
      readBridgeNumber("transcriptRevision") + 1,
    );
    if (outcome.entryPoint === "keyboard") return;
  }
  if (!deliveredText) return;
  await Clipboard.setStringAsync(deliveredText);
}

export { deliverDictationResult };
