# frozen_string_literal: true

require "test_helper"

# Phase 1: Pingback's dark-first design system (tokens + components + motion).
class DesignSystemTest < SiteTest
  TOKENS = {
    "--bg" => "#14161f", "--surface" => "#1c1f2c", "--line" => "#2b2f44",
    "--ink" => "#e8ebf5", "--muted" => "#9aa3bd", "--ruby" => "#e8436b",
    "--sky" => "#7cc8ff", "--gold" => "#e0b060"
  }.freeze

  def test_brand_tokens_are_defined_on_root
    root = rules_for(":root")
    TOKENS.each do |name, value|
      assert_match(/#{Regexp.escape(name)}:\s*#{value}/i, root, "#{name} should be #{value}")
    end
  end

  def test_site_is_dark_only
    refute css.include?("prefers-color-scheme"), "no light/dark switching: the site is dark only"
    assert_equal "dark", page("/").at_css('meta[name="color-scheme"]')&.[]("content")
  end

  def test_card_component
    card = rules_for(".card")
    assert_match(/background:\s*var\(--surface\)/, card)
    assert_match(/border:\s*1px solid var\(--line\)/, card)
    assert_match(/border-radius:/, card)
    assert_match(/transition:/, card)
  end

  def test_card_hover_and_focus_turn_the_border_and_title_ruby
    %w[.card:hover .card:focus-within].each do |state|
      assert_match(/border-color:\s*var\(--ruby\)/, rules_for(state), "#{state} border")
      assert_match(/color:/, rules_for("#{state} .card__title"), "#{state} title colour")
    end
  end

  def test_chips_and_buttons_lift_on_hover
    assert_match(/border-radius:\s*999px/, rules_for(".chip"))
    assert_match(/translateY\(-1px\)/, rules_for("a.chip:hover"))
    assert_match(/box-shadow:/, rules_for("a.chip:hover"))
    assert_match(/translateY\(-1px\)/, rules_for(".btn:hover"))
    assert_match(/background:\s*var\(--ruby\)/, rules_for(".btn--primary"))
  end

  def test_keyboard_focus_is_visible
    assert_match(/outline:.*var\(--ruby\)/, rules_for(":focus-visible"))
  end

  def test_reduced_motion_turns_movement_off
    block = css[/@media \(prefers-reduced-motion: ?reduce\)\s*\{(.*?\}\s*)\}/m, 1].to_s
    assert_match(/transition:\s*none/, block)
    assert_match(/transform:\s*none/, block)
    assert_match(/animation:\s*none/, block)
  end

  def test_timestamps_use_the_mono_face
    assert_match(/font-family:\s*var\(--mono\)/, rules_for(".timestamp"))
    assert_match(/--mono:\s*"JetBrains Mono"/, rules_for(":root"))
    assert page("/").at_css('link[href*="JetBrains+Mono"]'), "JetBrains Mono is loaded"
  end
end
