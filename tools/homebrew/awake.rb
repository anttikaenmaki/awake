# Written by the awake repository's Homebrew tap workflow
# (.github/workflows/homebrew-tap.yml) from tools/homebrew/awake.rb in
# https://github.com/anttikaenmaki/awake. Change it there: this file is
# replaced at each release.
cask "awake" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/anttikaenmaki/awake/releases/download/v#{version}/awake-#{version}.tar.gz"
  name "Awake"
  desc "Keep a Mac awake, also with the lid closed, from the menu bar or Terminal"
  homepage "https://github.com/anttikaenmaki/awake"

  depends_on macos: ">= :monterey"

  # The installer builds Awake on this Mac from these sources, as it does
  # from a git clone, which carries no quarantine attribute. Built from
  # quarantined sources, the app would carry it in its copied files.
  preflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", staged_path.to_s]
  end

  # The same installer as `bash install-awake.sh`: it stops a running
  # session, builds and installs Awake.app and the awake command, and keeps
  # the settings of an earlier install.
  installer script: {
    executable: "awake-#{version}/install-awake.sh",
  }

  # Homebrew runs this also before an upgrade or reinstall; the script then
  # leaves Awake in place, and runs the uninstaller only for brew uninstall.
  uninstall script: {
    executable: "awake-#{version}/scripts/homebrew-uninstall.sh",
  }

  zap trash: [
    "~/Library/Application Support/Awake",
    "~/Library/Preferences/net.kaenmaki.awake.statusbar.plist",
  ]

  caveats <<~EOS
    Awake is installed as ~/Applications/Awake.app, with the awake command in
    ~/bin or ~/.local/bin. brew upgrade updates it in place and keeps its
    settings; brew uninstall awake removes it, with its settings and helper.

    The installer asks for your administrator password, in a macOS dialog,
    when it installs or updates the helper that lid-closed mode needs.
  EOS
end
