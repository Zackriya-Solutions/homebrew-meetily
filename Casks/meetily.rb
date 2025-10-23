cask "meetily" do
  version "0.1.1"
  sha256 "a9fc0d51f5c47226a7c3720510674ba85bff0204122c27175023c0671873c8f4"
  url "https://github.com/Zackriya-Solutions/meeting-minutes/releases/download/0.1.1/dmg_darwin_arch64_0.1.1.zip"
  name "Meetily"
  desc "Meeting transcription and analysis application"
  homepage "https://github.com/Zackriya-Solutions/meeting-minutes"

  depends_on macos: ">= :monterey"
  depends_on arch: :arm64

  container nested: "dmg/meetily_0.1.1_aarch64.dmg"
  
  app "meetily.app"
  
  postflight do
    # Clear extended attributes to avoid security/quarantine issues
    system_command "/usr/bin/xattr",
                   args: ["-c", "/Applications/meetily.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Meetily",
    "~/Library/Preferences/com.zackriya.meetily.plist",
    "~/Library/Saved Application State/com.zackriya.meetily.savedState",
    "~/Library/Logs/Meetily"
  ]

  caveats do
    <<~EOS
      Meetily now includes an integrated backend server!
      
      Simply launch the application - no separate backend setup required.
      The integrated backend will start automatically with the frontend.
    EOS
  end
end
