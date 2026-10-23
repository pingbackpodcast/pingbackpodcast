# frozen_string_literal: true

module Pingback
  # Turns word-level transcript segments (Buzzsprout's transcript.json) into
  # speaker turns for the episode page, and Buzzsprout chapters into the
  # front matter format ({ "t" => "m:ss", "title" => ... }).
  module Transcript
    SENTENCE_END = /[.?!]["')\]]*\z/

    module_function

    # segments: [{ "speaker", "startTime", "body" }, ...] in time order.
    # A new turn starts when the speaker changes, or when the current turn has
    # run longer than paragraph_seconds and the last word ended a sentence.
    def turns(segments, names: {}, paragraph_seconds: 45)
      segments.each_with_object([]) do |seg, out|
        body = seg["body"].to_s.strip
        next if body.empty?

        speaker = names.fetch(seg["speaker"], seg["speaker"])
        start = seg["startTime"].to_f
        current = out.last

        if current.nil? || current[:speaker] != speaker || paragraph_break?(current, start, paragraph_seconds)
          out << { speaker: speaker, t: start.round(1), text: body.dup }
        else
          current[:text] << " " << body
        end
      end
    end

    def paragraph_break?(turn, start, limit)
      start - turn[:t] > limit && turn[:text].match?(SENTENCE_END)
    end

    def chapters(json)
      Array(json["chapters"]).map do |c|
        { "t" => clock(c["startTime"]), "title" => c["title"].to_s.strip }
      end
    end

    def clock(seconds)
      s = seconds.to_i
      h, rem = s.divmod(3600)
      m, sec = rem.divmod(60)
      h.positive? ? format("%d:%02d:%02d", h, m, sec) : format("%d:%02d", m, sec)
    end
  end
end
