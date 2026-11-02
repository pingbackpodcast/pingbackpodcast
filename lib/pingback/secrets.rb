# frozen_string_literal: true

require "open3"

module Pingback
  # API tokens come from 1Password at run time (never stored on disk): vault
  # "Pingback Podcast", item "Descript", fields "Buzzsprout API token" and
  # "Descript website deploy API token".
  # PINGBACK_BUZZSPROUT_TOKEN / PINGBACK_DESCRIPT_TOKEN override.
  #
  # Over SSH (or anywhere the desktop app is locked): a token saved in
  # TOKEN_DIR/<name>-token (mode 600) is used before op, and op reads with a
  # read-only service account key from KEY_FILE (mode 600) when that exists.
  class Secrets
    class Error < StandardError; end

    VAULT = "Pingback Podcast"
    ITEMS = {
      buzzsprout: ["Descript", "Buzzsprout API token"],
      descript: ["Descript", "Descript website deploy API token"]
    }.freeze
    TOKEN_DIR = File.expand_path("~/.config/pingback")
    KEY_FILE = File.join(TOKEN_DIR, "op-service-account-token")

    def initialize(runner: ->(*cmd) { out, status = Open3.capture2(*cmd); [out, status.success?] }, env: ENV,
                   key_file: KEY_FILE, token_dir: TOKEN_DIR)
      @runner, @env, @key_file, @token_dir = runner, env, key_file, token_dir
    end

    def fetch(name)
      item, field = ITEMS.fetch(name)
      from_env = @env["PINGBACK_#{name.to_s.upcase}_TOKEN"]
      return from_env unless from_env.to_s.empty?

      from_file = private_file(File.join(@token_dir, "#{name}-token"))
      return from_file unless from_file.to_s.empty?

      out, ok = @runner.call(*service_account, "op", "read", "op://#{VAULT}/#{item}/#{field}")
      token = out.to_s.strip
      return token if ok && !token.empty?

      raise Error, "Couldn't read the #{field} from 1Password (vault \"#{VAULT}\", item \"#{item}\", " \
                   "field \"#{field}\"). Run `op signin` and check the item exists " \
                   "(over SSH, save the token in #{TOKEN_DIR}/#{name}-token, mode 600)."
    end

    private

    # [{ "OP_SERVICE_ACCOUNT_TOKEN" => key }] when the key file is there.
    def service_account
      key = private_file(@key_file)
      key.to_s.empty? ? [] : [{ "OP_SERVICE_ACCOUNT_TOKEN" => key }]
    end

    # A secret's contents, or nil when the file isn't there.
    def private_file(path)
      return unless path && File.file?(path)
      raise Error, "#{path} can be read by other users; run `chmod 600 #{path}`" if File.stat(path).mode.anybits?(0o077)

      File.read(path).strip
    end
  end
end
