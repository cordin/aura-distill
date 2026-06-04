class AuraDistill < Formula
  desc "Retrospective knowledge distillation for Claude Code and Codex"
  homepage "https://github.com/tomacco/aura-distill"
  url "https://github.com/tomacco/aura-distill/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "f8436dec1f2c1a5cfbfe5ee26ea6396e3b6f1cdee82dff02fa1c21d405e68e5d"
  license "MIT"

  head "https://github.com/tomacco/aura-distill.git", branch: "main"

  def install
    # Only install files needed by the installer — skip docs, tests, server, etc.
    libexec.install "install.sh", "VERSION", "LICENSE",
                    "distill.md", "distill-process.md", "distill-monitor.md",
                    "banner.txt"
    (libexec/"rules").install "rules/distill.md"
    (libexec/"codex").install "codex/distill-adapter.md"
    (libexec/"codex/skills/distill").install "codex/skills/distill/SKILL.md"

    # Create the `aura-distill` wrapper that runs the installer
    wrapper = buildpath/"homebrew/aura-distill-wrapper.sh"
    inreplace wrapper, "__AURA_DISTILL_LIBEXEC__", libexec.to_s
    bin.install wrapper => "aura-distill"
  end

  def caveats
    <<~EOS
      To complete setup, run:
        aura-distill install

      This copies the distill files to your Claude Code profile (~/.claude/).

      For a specific profile:
        aura-distill install --profile personal

      For Codex:
        aura-distill install --target codex

      To upgrade after `brew upgrade`:
        aura-distill install
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aura-distill version").strip
  end
end
