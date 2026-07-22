import { setAudioModeAsync } from "expo-audio";

async function configureRecordingAudioSession() {
  await setAudioModeAsync({
    allowsBackgroundRecording: true,
    allowsRecording: true,
    playsInSilentMode: true,
    shouldRouteThroughEarpiece: false,
  });
}

async function configurePlaybackAudioSession() {
  await setAudioModeAsync({
    allowsBackgroundRecording: false,
    allowsRecording: false,
    playsInSilentMode: true,
    shouldPlayInBackground: false,
    shouldRouteThroughEarpiece: false,
  });
}

export { configurePlaybackAudioSession, configureRecordingAudioSession };
