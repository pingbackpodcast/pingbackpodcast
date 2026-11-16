# frozen_string_literal: true

require "time"
require_relative "episode_file"

module Pingback
  # Posts dated in the future are scheduled releases: Jekyll leaves them out
  # of the build. The release timer workflow deploys at each release time;
  # the hourly run is the backstop: it deploys whenever a recently released
  # post's page isn't live yet, however late GitHub runs it.
  class Schedule
    LOOKBACK = 14 * 24 * 60 * 60
    Post = Struct.new(:episode, :at, :path) do
      def url_path = "/episodes/#{File.basename(path, '.md').sub(/\A\d{4}-\d{2}-\d{2}-/, '')}/"
    end

    def initialize(root:)
      @root = root
    end

    def posts
      Dir.glob(File.join(@root, "_posts", "*.md")).sort.map do |path|
        ep = EpisodeFile.new(path)
        Post.new(ep["episode"], Time.parse(ep.date_string).utc, path)
      end
    end

    def upcoming(now: Time.now) = posts.select { |p| p.at > now }

    def next_release(now: Time.now) = upcoming(now: now).map(&:at).min

    # live: ->(url_path) { true if the page is on the live site }
    def due?(live:, now: Time.now)
      posts.any? { |p| p.at <= now && p.at > now - LOOKBACK && !live.call(p.url_path) }
    end
  end
end
