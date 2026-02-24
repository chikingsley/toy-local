cask "toy-local" do
  version "0.2.11"
  sha256 :no_check  # Will be filled after first release

  url "https://github.com/chikingsley/toy-local/releases/download/v#{version}/ToyLocal-v#{version}.zip"
  name "ToyLocal"
  desc "On-device voice-to-text for macOS"
  homepage "https://github.com/chikingsley/toy-local"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "ToyLocal.app"

  zap trash: [
    "~/Library/Application Support/com.chiejimofor.toylocal",
    "~/Library/Caches/com.chiejimofor.toylocal",
    "~/Library/Containers/com.chiejimofor.toylocal",
    "~/Library/Preferences/com.chiejimofor.toylocal.plist",
  ]
end
