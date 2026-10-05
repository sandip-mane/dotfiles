cask "cleanshot" do
  version "4.8.11"
  sha256 "298afb3d085ee6343dae954ba2a7429bd613e6ad9e942c8f79008688ceb11a81"

  url "https://updates.getcleanshot.com/v3/CleanShot-X-#{version}.dmg"
  name "CleanShot"
  desc "Screen capturing tool"
  homepage "https://cleanshot.com/"

  depends_on macos: :ventura

  app "CleanShot X.app"

  uninstall quit: "pl.maketheweb.cleanshotx"
end
