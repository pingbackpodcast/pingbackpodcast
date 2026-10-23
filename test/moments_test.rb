# frozen_string_literal: true

require "test_helper"
require "yaml"
require "date"

# Phase 3: best-moment cards on the episode page.
class MomentsTest < SiteTest
  def moments(n)
    path = Dir[File.join(SiteBuild::ROOT, "_posts/*-episode-#{n}.md")].first
    fm = YAML.safe_load(File.read(path)[/\A---\n(.*?)\n---/m, 1], permitted_classes: [Date, Time])
    fm.fetch("moments")
  end

  def test_every_episode_has_six_to_ten_moments
    (1..3).each { |n| assert_includes 6..10, moments(n).size, "episode #{n}" }
  end

  def test_moment_cards_render_with_art_title_quote_and_seek
    doc = page("/episodes/episode-3/")
    cards = doc.css("section.moments article.card.moment-card")
    expected = moments(3)
    assert_equal expected.size, cards.size
    first, data = cards.first, expected.first
    assert_equal "/assets/images/moments/episode-3-1.jpg", first.at_css("img.moment-card__art")&.[]("src")
    assert_equal data["title"], first.at_css(".card__title").text.strip
    assert_equal data["quote"], first.at_css("blockquote.moment-card__quote").text.strip
    play = first.at_css("a.moment-card__play[data-seek]")
    assert_equal data["t"].split(":").map(&:to_i).reduce(0) { |a, b| a * 60 + b }.to_s, play["data-seek"]
    assert_equal "Play from #{data['t']}", play.text.strip
  end

  def test_moments_come_before_the_show_notes
    html = page("/episodes/episode-3/").to_html
    assert_operator html.index('class="moments"'), :<, html.index('class="episode-body')
  end

  def test_moment_art_exists_for_every_moment
    (1..3).each do |n|
      moments(n).each_index do |i|
        assert File.file?(File.join(SiteBuild::ROOT, "assets/images/moments/episode-#{n}-#{i + 1}.jpg")), "art #{n}-#{i + 1}"
      end
    end
  end
end
