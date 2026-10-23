# frozen_string_literal: true

require "yaml"
require "date"

module Pingback
  # An episode post in _posts/, found by episode number.
  class EpisodeFile
    attr_reader :path, :front_matter, :body

    def self.find(root, number)
      Dir[File.join(root, "_posts", "*.md")].sort.each do |path|
        file = new(path)
        return file if file.front_matter["episode"].to_i == number.to_i
      end
      nil
    end

    def initialize(path)
      @path = path
      raw = File.read(path)
      @raw_front = raw[/\A---\n(.*?)\n---/m, 1].to_s
      @front_matter = YAML.safe_load(@raw_front, permitted_classes: [Date, Time]) || {}
      @body = raw.sub(/\A---\n.*?\n---\n?/m, "")
    end

    def [](key) = front_matter[key]

    # Set one top-level front matter key, in place: replaces its line if it's
    # there, otherwise adds it right after `episode:`. Values are written as
    # plain YAML scalars (strings quoted).
    def set!(key, value)
      raw = File.read(path)
      front = raw[/\A---\n(.*?\n)---/m, 1]
      line = "#{key}: #{value.is_a?(String) ? value.inspect : value}\n"
      updated = if front.match?(/^#{Regexp.escape(key)}:.*\n/)
                  front.sub(/^#{Regexp.escape(key)}:.*\n/, line)
                else
                  front.sub(/^(episode:.*\n)/) { "#{Regexp.last_match(1)}#{line}" }
                end
      File.write(path, raw.sub(front, updated))
      initialize(path)
    end

    # The post's date exactly as written (keeps its UTC offset), e.g.
    # "2026-10-16 23:00:00 -0700"; falls back to the filename's date.
    def date_string
      @raw_front[/^date:\s*"?([^"#\n]+?)"?\s*(?:#.*)?$/, 1] || File.basename(path)[0, 10]
    end
  end
end
