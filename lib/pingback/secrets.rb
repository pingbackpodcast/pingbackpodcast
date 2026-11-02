# frozen_string_literal: true

require "open3"

module Pingback
  # API tokens come from 1Password at run time (never stored on disk): vault
  # "Pingback Podcast", item "Descript", fields "Buzzsprout API token" and
  # "Descript website deploy API token".
  # PINGBACK_BUZZSPROUT_TOKEN / PINGBACK_DESCRIPT_TOKEN override.
  #
  # Over SSH (or anywhere the desktop app is locked), op reads with a
  # read-only service account key for that vault, kept in KEY_FILE (mode 600).
  class Secrets
    class Error < StandardError; end

    VAULT = "Pingback Podcast"
    ITEMS = {
      buzzsprout: ["Descript", "Buzzsprout API token"],
      descript: ["Descript", "Descript website deploy API token"]
    }.freeze
    KEY_FILE = File.expand_path("~/.config/pingback/op-service-account-token")

    def initialize(runner: ->(*cmd) { out, status = Open3.capture2(*cmd); [out, status.success?] }, env: ENV,
                   key_file: KEY_FILE)
      @runner, @env, @key_file = runner, env, key_file
    end

    def fetch(name)
      item, field = ITEMS.fetch(name)
      from_env = @env["PINGBACK_#{name.to_s.upcase}_TOKEN"]
      return from_env unless from_env.to_s.empty?

      out, ok = @runner.call(*service_account, "op", "read", "op://#{VAULT}/#{item}/#{field}")
      token = out.to_s.strip
      return token if ok && !token.empty?

      raise Error, "Couldn't read the #{field} from 1Password (vault \"#{VAULT}\", item \"#{item}\", " \
                   "field \"#{field}\"). Run `op signin` and check the item exists " \
                   "(over SSH, put a service account key in #{KEY_FILE})."
    end

    private

    # [{ "OP_SERVICE_ACCOUNT_TOKEN" => key }] when the key file is there.
    def service_account
      return [] unless @key_file && File.file?(@key_file)
      raise Error, "#{@key_file} can be read by other users; run `chmod 600 #{@key_file}`" if File.stat(@key_file).mode.anybits?(0o077)

      key = File.read(@key_file).strip
      key.empty? ? [] : [{ "OP_SERVICE_ACCOUNT_TOKEN" => key }]
    end
  end
end
