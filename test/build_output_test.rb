# frozen_string_literal: true

require "test_helper"
require_relative "../lib/pingback/schedule"

# Only the website goes in the build: tooling, tests and docs stay private.
class BuildOutputTest < SiteTest
  PRIVATE = %w[bin lib test docs _plugins .githooks .claude CLAUDE.md Gemfile].freeze

  def test_tooling_is_not_published
    PRIVATE.each do |name|
      refute File.exist?(File.join(SiteBuild.dir, name)), "#{name} must not be in the built site"
    end
  end

  # Scheduled episodes stay off the site (page, lists, sitemap, feed) until
  # their release time; the hourly deploy publishes them.
  def test_future_dated_episodes_are_not_published_yet
    upcoming = Pingback::Schedule.new(root: File.expand_path("..", __dir__)).upcoming
    skip "no scheduled episodes right now" if upcoming.empty?

    upcoming.each do |post|
      url = "/episodes/episode-#{post.episode}/"
      refute File.exist?(File.join(SiteBuild.dir, url, "index.html")), "#{url} is built before its release"
      %w[index.html episodes/index.html sitemap.xml].each do |file|
        refute_includes File.read(File.join(SiteBuild.dir, file)), url, "#{file} links #{url} before its release"
      end
    end
  end
end
