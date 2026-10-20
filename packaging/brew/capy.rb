class Capy < Formula
  # Tap: rey-language/homebrew-tap
  desc "The capy command line interface for the Rey language"
  homepage "https://github.com/rey-language/capybara"
  version "0.1.0"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  # scripts/package.sh fills these SHA-256 placeholders from the release archives.
  on_macos do
    on_arm do
      url "https://github.com/rey-language/capybara/releases/download/v0.1.0/capy-v0.1.0-darwin-arm64.tar.gz"
      sha256 "__SHA_DARWIN_ARM64__"
    end
    on_intel do
      url "https://github.com/rey-language/capybara/releases/download/v0.1.0/capy-v0.1.0-darwin-x86_64.tar.gz"
      sha256 "__SHA_DARWIN_X86_64__"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/rey-language/capybara/releases/download/v0.1.0/capy-v0.1.0-linux-aarch64.tar.gz"
      sha256 "__SHA_LINUX_AARCH64__"
    end
    on_intel do
      url "https://github.com/rey-language/capybara/releases/download/v0.1.0/capy-v0.1.0-linux-x86_64.tar.gz"
      sha256 "__SHA_LINUX_X86_64__"
    end
  end

  def install
    bin.install "bin/capy"
    libexec.install "libexec/toolchain"
    bin.install_symlink libexec/"toolchain/bin/rey"
  end

  test do
    system "#{bin}/capy", "--version"
  end
end
