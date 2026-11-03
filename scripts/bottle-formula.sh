#!/usr/bin/env bash
# Prints the Homebrew formula that .github/workflows/bottle.yml installs with
# `brew install --build-bottle`. It mirrors Formula/outskirts.rb of the
# tiny-earth-moon/homebrew-tap tap: keep their install, caveats and test blocks
# identical. Only the source differs (the job builds the checked-out tree), and
# the tap formula also carries homepage, head, conflicts_with and the bottle block.
#
# Usage: scripts/bottle-formula.sh <version> <source-url> <sha256>
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <version> <source-url> <sha256>" >&2
  exit 64
fi

version=$1
url=$2
sha256=$3

if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version '$version' is not X.Y.Z" >&2
  exit 65
fi
if [[ ! $sha256 =~ ^[0-9a-f]{64}$ ]]; then
  echo "error: '$sha256' is not a SHA-256 digest" >&2
  exit 65
fi
if [[ $url == *'"'* || $url == *'#'* ]]; then
  echo "error: source url must not contain '\"' or '#'" >&2
  exit 65
fi

cat <<EOF
class Outskirts < Formula
  desc "Finds unused code in Swift projects (community-maintained fork of Periphery)"
  homepage "https://github.com/tiny-earth-moon/outskirts"
  url "${url}"
  version "${version}"
  sha256 "${sha256}"
  license "MIT"

  depends_on :macos
  depends_on xcode: "26.0"

  def install
    args = %w[--disable-sandbox -c release --product outskirts]
    # outskirts links @rpath/libIndexStore.dylib and swift-index-store only adds the building
    # Xcode to the rpath, e.g. /Applications/Xcode_27.2.app on a CI runner. A bottle must find
    # the library on the user's machine: the default Xcode location first, then the Command Line
    # Tools, which homebrew-core's periphery formula also relies on.
    if build.bottle?
      args += %w[-Xlinker -rpath -Xlinker
                 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib
                 -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/usr/lib]
    end
    system "swift", "build", *args
    bin.install ".build/release/outskirts"
    bin.install_symlink "outskirts" => "periphery"
  end

  def caveats
    <<~EOS
      The bottle loads libIndexStore.dylib from /Applications/Xcode.app, or else from the
      Command Line Tools. If neither is installed there, build from source instead:
        brew reinstall --build-from-source outskirts
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/outskirts version")
    assert_match version.to_s, shell_output("#{bin}/periphery version")
  end
end
EOF
