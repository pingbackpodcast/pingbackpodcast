# frozen_string_literal: true

module Pingback
  # Builds the YouTube description for an episode: show notes as plain text,
  # a chapter list YouTube turns into chapters, and links back to the site.
  # YouTube's chapter rules: first at 0:00, at least 3, each >= 10 seconds.
  module YoutubeText
    class Error < StandardError; end

    module_function

    def build(body:, chapters:, url:, platforms: [])
      check_chapters!(chapters)
      parts = [plain(body)]
      parts << (["Chapters"] + chapters.map { |c| "#{c['t']} #{c['title']}" }).join("\n") if chapters.any?
      parts << "Show notes, best moments and the full transcript: #{url}"
      live = platforms.reject { |p| p["url"].to_s.empty? }
      parts << live.map { |p| "#{p['name']}: #{p['url']}" }.join("\n") if live.any?
      parts.join("\n\n") + "\n"
    end

    # Markdown show notes -> plain text: headings sit directly above their
    # block, list items keep "- " with links as "text: url", inline links
    # become "text (url)", emphasis marks are dropped.
    def plain(markdown)
      out = []
      heading = nil
      markdown.strip.split(/\n{2,}/).each do |block|
        if (h = block[/\A#+\s*(.+)\z/, 1])
          heading = h.strip
          next
        end
        text = block.lines.map { |l| line(l.chomp) }.join("\n")
        out << (heading ? "#{heading}\n#{text}" : text)
        heading = nil
      end
      out << heading if heading
      out.join("\n\n")
    end

    def line(text)
      if (m = text.match(/\A\s*[-*]\s+\[([^\]]+)\]\(([^)]+)\)(.*)\z/))
        return "- #{inline(m[1])}#{inline(m[3])}: #{m[2]}"
      end

      text = text.sub(/\A\s*[-*]\s+/, "- ")
      inline(text)
    end

    def inline(text)
      text.gsub(/\[([^\]]+)\]\(([^)]+)\)/) { "#{Regexp.last_match(1)} (#{Regexp.last_match(2)})" }
          .gsub(/(\*\*|__|\*|_)(\S(?:.*?\S)?)\1/, '\2')
    end

    def check_chapters!(chapters)
      return if chapters.empty?

      secs = chapters.map { |c| c["t"].to_s.split(":").map(&:to_i).reduce(0) { |a, b| a * 60 + b } }
      raise Error, "YouTube chapters must start at 0:00 (first is #{chapters.first['t']})" unless secs.first.zero?
      raise Error, "YouTube needs at least 3 chapters (got #{chapters.size})" if chapters.size < 3

      secs.each_cons(2).with_index do |(a, b), i|
        raise Error, "YouTube chapters must be at least 10 seconds apart (#{chapters[i]['t']} -> #{chapters[i + 1]['t']})" if b - a < 10
      end
    end
  end
end
