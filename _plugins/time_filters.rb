# frozen_string_literal: true

require_relative "../lib/pingback/transcript"

# Liquid filters for episode times:
#   {{ "1:59" | seconds }}  -> 119      (chapter/moment "m:ss" or "h:mm:ss")
#   {{ 119.8 | clock }}     -> "1:59"   (seconds -> display time)
module Pingback
  module TimeFilters
    def seconds(value)
      return value.to_i if value.is_a?(Numeric)

      value.to_s.split(":").map(&:to_i).reduce(0) { |total, part| total * 60 + part }
    end

    def clock(value)
      Pingback::Transcript.clock(value.is_a?(Numeric) ? value : seconds(value))
    end
  end
end

Liquid::Template.register_filter(Pingback::TimeFilters)
