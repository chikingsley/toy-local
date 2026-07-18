import * as Clipboard from "expo-clipboard";

import type { DictationOutcome } from "@/features/dictation/dictation-types";
import {
  readBridgeNumber,
  writeBridgeNumber,
  writeBridgeString,
} from "@/features/keyboard/app-group-bridge";

async function deliverDictationResult(outcome: DictationOutcome, text: string) {
  const deliveredText = text.trim();
  if (!deliveredText) return;
  if (outcome.entryPoint === "keyboard") {
    writeBridgeString("finalResultId", outcome.resultId);
    writeBridgeString("finalRequestId", outcome.requestId);
    writeBridgeString("finalTranscript", deliveredText);
    writeBridgeNumber(
      "transcriptRevision",
      readBridgeNumber("transcriptRevision") + 1,
    );
    return;
  }
  await Clipboard.setStringAsync(deliveredText);
}

export { deliverDictationResult };
