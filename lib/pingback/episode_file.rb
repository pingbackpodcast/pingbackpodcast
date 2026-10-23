# frozen_string_literal: true

require "yaml"
require "date"

module Pingback
  # An episode post in _posts/, found by episode number.
  class EpisodeFile
    attr_reader :path, :front_matter

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
      @front_matter = YAML.safe_load(raw[/\A---\n(.*?)\n---/m, 1].to_s, permitted_classes: [Date, Time]) || {}
    end

    def [](key) = front_matter[key]
  end
end
