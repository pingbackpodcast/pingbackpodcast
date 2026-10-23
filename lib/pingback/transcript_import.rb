# frozen_string_literal: true

require "json"
require "net/http"
require "fileutils"
require "yaml"
require_relative "transcript"
require_relative "episode_file"

module Pingback
  # Saves an episode's Buzzsprout transcript as _data/transcripts/episode-N.json
  # (speaker turns, full names) for the episode page.
  class TranscriptImport
    class Error < StandardError; end

    def self.http_json(url)
      res = Net::HTTP.get_response(URI(url))
      raise Error, "GET #{url} returned #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def initialize(root:, fetch: ->(url) { TranscriptImport.http_json(url) })
      @root = root
      @fetch = fetch
      @config = YAML.safe_load_file(File.join(root, "_config.yml")) || {}
    end

    def run(number)
      episode = EpisodeFile.find(@root, number) or raise Error, "no post for episode #{number} in _posts/"
      id = episode["buzzsprout_id"] or raise Error, "episode #{number} has no buzzsprout_id"
      show = @config["buzzsprout_podcast_id"] or raise Error, "_config.yml has no buzzsprout_podcast_id"

      json = @fetch.call("https://www.buzzsprout.com/#{show}/#{id}/transcript.json")
      names = (@config["speakers"] || {}).merge(episode["speaker_names"] || {})
      turns = Transcript.turns(Array(json["segments"]), names: names)
      raise Error, "Buzzsprout returned no transcript for episode #{number}" if turns.empty?

      write(number, "source" => "buzzsprout", "turns" => turns.map { |t| t.transform_keys(&:to_s) })
    end

    private

    def write(number, data)
      dir = File.join(@root, "_data", "transcripts")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "episode-#{number}.json")
      File.write(path, JSON.pretty_generate(data) + "\n")
      path
    end
  end
end
