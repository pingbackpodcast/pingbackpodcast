# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "time"
require "yaml"
require_relative "../lib/pingback/schedule"

# Future-dated posts are scheduled: Jekyll leaves them out of the build, and an
# hourly workflow run rebuilds the site once one comes due.
class ScheduleTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "_posts"))
    post(3, "2026-10-16", "2026-10-16 23:00:00 -0700")
    post(4, "2026-10-26", "2026-10-26 02:00:00 -0700")
  end

  def teardown = FileUtils.remove_entry(@root)

  def post(n, day, date)
    File.write(File.join(@root, "_posts/#{day}-episode-#{n}.md"), "---\ntitle: Ep #{n}\nepisode: #{n}\ndate: #{date}\n---\n")
  end

  def schedule = Pingback::Schedule.new(root: @root)

  def test_lists_posts_still_to_be_released
    upcoming = schedule.upcoming(now: Time.parse("2026-10-25 12:00:00 -0700"))
    assert_equal [[4, Time.parse("2026-10-26 09:00:00 UTC")]], upcoming.map { |p| [p.episode, p.at] }
  end

  def test_nothing_due_before_the_release_time
    refute schedule.due?(now: Time.parse("2026-10-26 01:59:00 -0700"))
  end

  def test_due_just_after_release_even_if_the_hourly_run_is_late
    assert schedule.due?(now: Time.parse("2026-10-26 02:07:00 -0700"))
    assert schedule.due?(now: Time.parse("2026-10-26 03:50:00 -0700"))
  end

  def test_not_due_again_once_the_window_has_passed
    refute schedule.due?(now: Time.parse("2026-10-26 04:30:00 -0700"))
  end

  def test_release_due_runs_on_plain_ruby_without_a_utf8_locale
    out = IO.popen({ "PATH" => ENV["PATH"], "LANG" => "C", "LC_ALL" => "C" }, ["ruby", File.join(ROOT, "bin/release-due")],
                   unsetenv_others: true, err: %i[child out], &:read)
    assert_match(/\Adue=(true|false)\n\z/, out)
  end

  def test_workflow_rebuilds_hourly_only_when_a_post_is_due
    wf = YAML.safe_load_file(File.join(ROOT, ".github/workflows/jekyll.yml"))
    on = wf["on"] || wf[true] # YAML 1.1 reads a bare `on:` key as true
    assert_match(/\A\d+ \* \* \* \*\z/, on["schedule"].first["cron"], "hourly")
    gate = wf["jobs"]["due"]
    assert gate["steps"].any? { |s| s["run"].to_s.include?("bin/release-due") }
    assert_match(/github\.event_name != 'schedule'.*needs\.due\.outputs\.due == 'true'/m, wf["jobs"]["build"]["if"])
  end
end
