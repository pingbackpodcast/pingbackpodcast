# frozen_string_literal: true

require "time"
require_relative "episode_file"

module Pingback
  # Posts dated in the future are scheduled releases: Jekyll leaves them out
  # of the build, and the hourly workflow run rebuilds the site once one is
  # due. WINDOW covers GitHub running scheduled jobs late (a second deploy of
  # the same post is harmless).
  class Schedule
    WINDOW = 2 * 60 * 60
    Post = Struct.new(:episode, :at, :path)

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

    def due?(now: Time.now) = posts.any? { |p| p.at <= now && p.at > now - WINDOW }
  end
end
