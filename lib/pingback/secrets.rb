# frozen_string_literal: true

require "open3"

module Pingback
  # API tokens come from 1Password at run time (never stored on disk): vault
  # "Pingback Podcast", item "Descript", fields "Buzzsprout API token" and
  # "Descript website deploy API token".
  # PINGBACK_BUZZSPROUT_TOKEN / PINGBACK_DESCRIPT_TOKEN override.
  class Secrets
    class Error < StandardError; end

    VAULT = "Pingback Podcast"
    ITEMS = {
      buzzsprout: ["Descript", "Buzzsprout API token"],
      descript: ["Descript", "Descript website deploy API token"]
    }.freeze

    def initialize(runner: ->(*cmd) { out, status = Open3.capture2(*cmd); [out, status.success?] }, env: ENV)
      @runner, @env = runner, env
    end

    def fetch(name)
      item, field = ITEMS.fetch(name)
      from_env = @env["PINGBACK_#{name.to_s.upcase}_TOKEN"]
      return from_env unless from_env.to_s.empty?

      out, ok = @runner.call("op", "read", "op://#{VAULT}/#{item}/#{field}")
      token = out.to_s.strip
      return token if ok && !token.empty?

      raise Error, "Couldn't read the #{field} from 1Password (vault \"#{VAULT}\", item \"#{item}\", " \
                   "field \"#{field}\"). Run `op signin` and check the item exists."
    end
  end
end
