# frozen_string_literal: true

# One page per topic in _data/topics.yml, at /topics/<slug>/ (layout: topic).
module Pingback
  class TopicPages < Jekyll::Generator
    safe true

    def generate(site)
      Array(site.data["topics"]).each do |topic|
        page = Jekyll::PageWithoutAFile.new(site, site.source, File.join("topics", topic["slug"]), "index.html")
        page.data.merge!(
          "layout" => "topic",
          "title" => topic["name"],
          "topic" => topic["slug"],
          "description" => topic["blurb"]
        )
        site.pages << page
      end
    end
  end
end
