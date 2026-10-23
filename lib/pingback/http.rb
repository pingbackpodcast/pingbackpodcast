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
  end
end
