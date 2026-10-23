# frozen_string_literal: true

require "net/http"
require "fileutils"
require "tmpdir"
require_relative "episode_file"

module Pingback
  # Saves an episode's YouTube thumbnail as assets/images/episodes/episode-N.jpg
  # (1280px wide), so the site never hotlinks YouTube images.
  class Thumbnail
    class Error < StandardError; end

    SIZES = %w[maxresdefault hqdefault].freeze

    def self.http_bytes(url)
      res = Net::HTTP.get_response(URI(url))
      res.is_a?(Net::HTTPSuccess) ? res.body : nil
    end

    def self.magick_resize(src, dst)
      system("magick", src, "-resize", "1280x>", "-strip", "-quality", "82", dst, exception: true)
    end

    def initialize(root:, fetch: ->(url) { Thumbnail.http_bytes(url) },
                   resize: ->(src, dst) { Thumbnail.magick_resize(src, dst) })
      @root, @fetch, @resize = root, fetch, resize
    end

    def run(number)
      episode = EpisodeFile.find(@root, number) or raise Error, "no post for episode #{number} in _posts/"
      id = episode["youtube_id"] or raise Error, "episode #{number} has no youtube_id"

      bytes = SIZES.lazy.map { |size| @fetch.call("https://i.ytimg.com/vi/#{id}/#{size}.jpg") }.find(&:itself)
      raise Error, "YouTube has no thumbnail for #{id}" unless bytes

      dir = File.join(@root, "assets/images/episodes")
      FileUtils.mkdir_p(dir)
      dst = File.join(dir, "episode-#{number}.jpg")
      Dir.mktmpdir do |tmp|
        src = File.join(tmp, "thumb.jpg")
        File.binwrite(src, bytes)
        @resize.call(src, dst)
      end
      dst
    end
  end
end
