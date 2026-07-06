cask "timbervox" do
  version "0.2.11"
  sha256 :no_check  # Will be filled after first release

  url "https://github.com/chikingsley/timbervox/releases/download/v#{version}/TimberVox-v#{version}.zip"
  name "TimberVox"
  desc "On-device voice-to-text for macOS"
  homepage "https://github.com/chikingsley/timbervox"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "TimberVox.app"

  zap trash: [
    "~/Library/Application Support/com.chiejimofor.timbervox",
    "~/Library/Caches/com.chiejimofor.timbervox",
    "~/Library/Containers/com.chiejimofor.timbervox",
    "~/Library/Preferences/com.chiejimofor.timbervox.plist",
  ]
end
