// EAS build workers clone git dependencies anonymously, but
// @chikingsley/peacockery-voice-client lives in the private
// peacockery-voice repository. When a GITHUB_TOKEN environment variable is
// present (set it as an EAS secret for every remote build environment),
// rewrite GitHub fetches to authenticate with it. Local builds and
// `eas build --local` use the machine's own git credentials, so the
// missing-token case stays a no-op.
const { execSync } = require("node:child_process");

const token = process.env.GITHUB_TOKEN;
if (!token) {
  console.warn(
    "eas-build-pre-install: GITHUB_TOKEN is not set; installing the private " +
      "peacockery-voice-client will fail on a remote EAS worker.",
  );
  process.exit(0);
}

execSync(
  `git config --global url."https://x-access-token:${token}@github.com/".insteadOf "https://github.com/"`,
  { stdio: "ignore" },
);
console.log("eas-build-pre-install: authenticated GitHub fetches configured.");
