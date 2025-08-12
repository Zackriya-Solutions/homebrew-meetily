cask "meetily" do
  version "0.0.5"
  sha256 "2bac406c82c7a4545c12e1650daef585983704873c0483e932ec56f907dcb08f"
  url "https://github.com/Zackriya-Solutions/meeting-minutes/releases/download/v0.0.5/dmg_darwin_arch64_0.0.5.zip"
  name "Meetily"
  desc "Meeting transcription and analysis application"
  homepage "https://github.com/Zackriya-Solutions/meeting-minutes"

  depends_on formula: "meetily-backend"
  depends_on macos: ">= :monterey"
  depends_on arch: :arm64

  container nested: "dmg/meetily-frontend_0.0.5_aarch64.dmg"
  
  app "meetily-frontend.app"
  
  postflight do
    # Clear extended attributes to avoid security/quarantine issues
    system_command "/usr/bin/xattr",
                   args: ["-c", "/Applications/meetily-frontend.app"],
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
      Meetily requires the backend server to be running.
      
      To start the backend server:
        meetily-server
      
      The frontend will automatically connect to the backend at:
        http://localhost:5167
    EOS
  end
end
