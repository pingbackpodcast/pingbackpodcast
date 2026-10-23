# frozen_string_literal: true

require "open3"

module Pingback
  # API tokens come from 1Password at run time (never stored on disk):
  # vault "Pingback Podcast", items "Buzzsprout API" / "Descript API", field
  # "credential". PINGBACK_BUZZSPROUT_TOKEN / PINGBACK_DESCRIPT_TOKEN override.
  class Secrets
    class Error < StandardError; end

    VAULT = "Pingback Podcast"
    ITEMS = { buzzsprout: "Buzzsprout API", descript: "Descript API" }.freeze

    def initialize(runner: ->(*cmd) { out, status = Open3.capture2(*cmd); [out, status.success?] }, env: ENV)
      @runner, @env = runner, env
    end

    def fetch(name)
      item = ITEMS.fetch(name)
      from_env = @env["PINGBACK_#{name.to_s.upcase}_TOKEN"]
      return from_env unless from_env.to_s.empty?

      out, ok = @runner.call("op", "read", "op://#{VAULT}/#{item}/credential")
      token = out.to_s.strip
      return token if ok && !token.empty?

      raise Error, "Couldn't read the #{item} token from 1Password (vault \"#{VAULT}\", item \"#{item}\", " \
                   "field \"credential\"). Run `op signin` and check the item exists."
    end
  end
end
