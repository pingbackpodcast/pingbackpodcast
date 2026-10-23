# frozen_string_literal: true

require "test_helper"
require "yaml"

# Phase 5: topics (index, one page per topic, filters) and the start-here row.
class TopicsTest < SiteTest
  TOPICS = { "rails" => [3, 2, 1], "ai" => [3, 2, 1], "indie" => [2], "tools" => [2, 1], "other-tech" => [1] }.freeze

  def topic_names
    YAML.safe_load_file(File.join(SiteBuild::ROOT, "_data/topics.yml")).to_h { |t| [t["slug"], t["name"]] }
  end

  def test_each_topic_has_a_page_listing_its_episodes
    TOPICS.each do |slug, episodes|
      doc = page("/topics/#{slug}/")
      assert_equal topic_names[slug], doc.at_css("h1").text.strip
      assert doc.at_css(".topic-blurb"), "#{slug} blurb"
      hrefs = doc.css("article.episode-card a.card__link").map { |a| a["href"] }
      assert_equal episodes.map { |n| "/episodes/episode-#{n}/" }, hrefs, slug
      assert doc.at_css(".topic-empty"), "#{slug} explains it's empty" if episodes.empty?
    end
  end

  def test_topics_index_shows_every_topic_with_a_count
    cards = page("/topics/").css("article.card.topic-card")
    assert_equal TOPICS.keys.size, cards.size
    rails = cards.find { |c| c.at_css("a.card__link")["href"] == "/topics/rails/" }
    assert_equal "3 episodes", rails.at_css(".topic-card__count").text.strip
    other = cards.find { |c| c.at_css("a.card__link")["href"] == "/topics/other-tech/" }
    assert_equal "1 episode", other.at_css(".topic-card__count").text.strip
  end

  def test_episode_header_topic_chips_link_to_topic_pages
    chips = page("/episodes/episode-2/").css(".episode-header a.chip[href^='/topics/']")
    assert_equal ["/topics/indie/", "/topics/ai/", "/topics/rails/", "/topics/tools/"], chips.map { |a| a["href"] }
  end

  def test_episodes_page_has_topic_filters_and_tagged_cards
    doc = page("/episodes/")
    filters = doc.css(".topic-filter a.chip[data-topic]")
    assert_equal ["all", *TOPICS.keys], filters.map { |a| a["data-topic"] }
    assert_equal "/topics/rails/", filters.find { |a| a["data-topic"] == "rails" }["href"]
    card = doc.css("article.episode-card").find { |c| c.at_css("a.card__link")["href"] == "/episodes/episode-2/" }
    assert_equal "indie ai rails tools", card["data-topics"]
    assert doc.at_css("script[src='/assets/js/topics.js'][defer]")
  end

  def test_homepage_has_topic_cards_and_nav_and_footer_link_topics
    home = page("/")
    assert_equal TOPICS.keys.size, home.css("section.topics article.topic-card").size
    assert home.at_css(".site-nav a[href='/topics/']"), "nav"
    assert home.at_css("footer nav[aria-label='Explore'] a[href='/topics/']"), "footer"
  end

  def test_start_here_stays_hidden_until_it_has_picks
    picks = YAML.safe_load_file(File.join(SiteBuild::ROOT, "_data/start_here.yml")) || []
    assert_empty picks, "hidden until about six episodes exist"
    refute page("/").at_css(".start-here")
  end
end
