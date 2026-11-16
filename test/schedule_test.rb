# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "time"
require "yaml"
require_relative "../lib/pingback/schedule"

# Future-dated posts are scheduled: Jekyll leaves them out of the build. The
# release timer deploys at the release time; the hourly run is the backstop.
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

  # A released post is due (needs a deploy) until its page is live, however
  # late the run is: GitHub's cron skips hours at a time.
  def live(*paths) = ->(path) { paths.include?(path) }

  def test_nothing_due_before_the_release_time
    refute schedule.due?(now: Time.parse("2026-10-26 01:59:00 -0700"), live: live("/episodes/episode-3/"))
  end

  def test_due_once_released_until_its_page_is_live
    assert schedule.due?(now: Time.parse("2026-10-26 02:07:00 -0700"), live: live("/episodes/episode-3/"))
    assert schedule.due?(now: Time.parse("2026-10-26 09:30:00 -0700"), live: live("/episodes/episode-3/")), "hours late"
    refute schedule.due?(now: Time.parse("2026-10-26 09:30:00 -0700"),
                         live: live("/episodes/episode-3/", "/episodes/episode-4/"))
  end

  def test_old_posts_are_not_checked
    checked = []
    schedule.due?(now: Time.parse("2026-11-20 12:00:00 -0700"), live: ->(path) { checked << path; true })
    assert_empty checked
  end

  def test_next_release_is_the_earliest_upcoming_post
    post(5, "2026-11-02", "2026-11-02 02:00:00 -0800")
    assert_equal Time.parse("2026-10-26 09:00:00 UTC"), schedule.next_release(now: Time.parse("2026-10-20 12:00:00 -0700"))
    assert_nil schedule.next_release(now: Time.parse("2026-11-03 12:00:00 -0800"))
  end

  def test_release_wait_prints_seconds_until_the_next_release
    out = IO.popen({ "PATH" => ENV["PATH"], "LANG" => "C", "LC_ALL" => "C", "RELEASE_NOW" => "2026-10-26T08:00:00Z" },
                   ["ruby", File.join(ROOT, "bin/release-wait"), @root], unsetenv_others: true, err: %i[child out], &:read)
    assert_equal "seconds=3600\n", out
  end

  def test_release_due_runs_on_plain_ruby_without_a_utf8_locale
    # RELEASE_DUE_ASSUME_LIVE keeps the test off the network.
    out = IO.popen({ "PATH" => ENV["PATH"], "LANG" => "C", "LC_ALL" => "C", "RELEASE_DUE_ASSUME_LIVE" => "1" },
                   ["ruby", File.join(ROOT, "bin/release-due")],
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
    # On a push the "due" job is skipped, and GitHub skips every job after a
    # skipped one unless it says otherwise: deploy must check build itself.
    assert_match(/!cancelled\(\).*needs\.build\.result == 'success'/, wf["jobs"]["deploy"]["if"].to_s)
  end

  # The real trigger: a run started by every push sleeps until the next
  # release, then dispatches the deploy. Jobs stop at 6 hours, so a longer
  # wait re-dispatches itself. GITHUB_TOKEN may dispatch workflows.
  def test_release_timer_sleeps_until_the_release_then_deploys
    wf = YAML.safe_load_file(File.join(ROOT, ".github/workflows/release-timer.yml"))
    on = wf["on"] || wf[true]
    assert_equal ["main"], on["push"]["branches"]
    assert on.key?("workflow_dispatch")
    assert_equal "write", wf["permissions"]["actions"]
    assert_equal true, wf["concurrency"]["cancel-in-progress"], "one timer at a time; a new push restarts it"
    job = wf["jobs"].values.first
    assert_operator job["timeout-minutes"], :<, 360
    script = job["steps"].map { |s| s["run"].to_s }.join("\n")
    assert_includes script, "bin/release-wait"
    assert_includes script, "gh workflow run jekyll.yml"
    assert_includes script, "gh workflow run release-timer.yml"
    refute_includes job["runs-on"], "latest", "pin the image: ubuntu-latest moving broke a release"
  end

  def test_workflow_pins_the_runner_image
    wf = YAML.safe_load_file(File.join(ROOT, ".github/workflows/jekyll.yml"))
    wf["jobs"].each_value { |j| refute_includes j["runs-on"], "latest" }
  end
end
