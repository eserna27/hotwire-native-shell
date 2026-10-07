# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module HotwireNativeShell
  module Push
    class Http
      Response = Struct.new(:status, :body, keyword_init: true)

      def self.apns(host:, path:, headers:, body:)
        require "net-http2"
        client = NetHttp2::Client.new("https://#{host}")
        response = client.call(:post, path, body: body, headers: headers)
        Response.new(status: Integer(response.status), body: response.body.to_s)
      ensure
        client&.close
      end

      def self.post_form(url, form, headers: {})
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key] = value }
        request.set_form_data(form)
        perform(uri, request)
      end

      def self.post_json(url, json, headers: {})
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key] = value }
        request["content-type"] = "application/json"
        request.body = JSON.generate(json)
        perform(uri, request)
      end

      def self.perform(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          response = http.request(request)
          Response.new(status: response.code.to_i, body: response.body.to_s)
        end
      end
    end
  end
end
