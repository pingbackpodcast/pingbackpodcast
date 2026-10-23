# frozen_string_literal: true

require "net/http"
require "uri"

module Pingback
  # Minimal HTTP for the API clients; tests swap in a fake with the same #call.
  module Http
    Response = Struct.new(:status, :body, :headers)

    module_function

    def call(method, url, headers: {}, body: nil)
      uri = URI(url)
      klass = Net::HTTP.const_get(method.to_s.capitalize)
      request = klass.new(uri)
      headers.each { |k, v| request[k] = v }
      request.body = body if body
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 300) { |h| h.request(request) }
      Response.new(res.code.to_i, res.body.to_s, res.to_hash)
    end

    # Streams a (possibly redirected) GET to a file.
    def download(url, path, redirects: 5)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 600) do |h|
        h.request(Net::HTTP::Get.new(uri)) do |res|
          case res
          when Net::HTTPRedirection
            raise "too many redirects downloading #{url}" if redirects.zero?

            return download(URI.join(url, res["location"]).to_s, path, redirects: redirects - 1)
          when Net::HTTPSuccess
            File.open(path, "wb") { |f| res.read_body { |chunk| f.write(chunk) } }
          else
            raise "download failed: HTTP #{res.code} for #{uri.host}"
          end
        end
      end
      path
    end
  end
end
