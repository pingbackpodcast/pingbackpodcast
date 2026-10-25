# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "fileutils"

# `pingback-deploy` (bin/pingback-deploy, symlinked onto PATH) opens Claude
# Code in this repo running the /pingback-deploy skill, from any directory.
class PingbackDeployTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "bin/pingback-deploy")

  def run_with_fake_claude(*args, from: Dir.tmpdir)
    Dir.mktmpdir do |bin|
      log = File.join(bin, "log")
      File.write(File.join(bin, "claude"), "#!/bin/sh\npwd > #{log}\nfor a in \"$@\"; do echo \"$a\" >> #{log}; done\n")
      File.chmod(0o755, File.join(bin, "claude"))
      link = File.join(bin, "pingback-deploy")
      File.symlink(SCRIPT, link) # runs through a symlink, like ~/.local/bin
      _, err, status = Open3.capture3({ "PATH" => "#{bin}:#{ENV['PATH']}" }, link, *args, chdir: from)
      assert status.success?, err
      File.read(log).lines(chomp: true)
    end
  end

  def test_opens_claude_in_the_repo_with_the_skill
    cwd, prompt = run_with_fake_claude
    assert_equal File.realpath(ROOT), File.realpath(cwd)
    assert_equal "/pingback-deploy", prompt
  end

  def test_passes_an_episode_number_through
    _, prompt = run_with_fake_claude("4")
    assert_equal "/pingback-deploy 4", prompt
  end

  def test_skill_exists_and_old_episode_skill_is_gone
    skill = File.read(File.join(ROOT, ".claude/skills/pingback-deploy/SKILL.md"))
    assert_match(/^name: pingback-deploy$/, skill)
    assert_match(/thumbnail-style\.md/, skill, "skill reads the saved thumbnail preferences")
    refute File.exist?(File.join(ROOT, ".claude/skills/episode/SKILL.md"))
  end
end
