# frozen_string_literal: true

require "json"
require "openssl"

module HotwireNativeShell
  module Push
    class Apns
      def initialize(credentials: Credentials.new, http: Http)
        @credentials = credentials
        @http = http
      end

      def deliver(token:, title:, body:, data: {}, device_token: nil)
        settings = @credentials.require_apns!
        jwt = self.class.token_for(settings)
        payload = { "aps" => { "alert" => { "title" => title.to_s, "body" => body.to_s }, "sound" => "default" } }
        data.each { |key, value| payload[key.to_s] = value }
        host = settings[:sandbox] ? "api.sandbox.push.apple.com" : "api.push.apple.com"
        response = @http.apns(
          host: host,
          path: "/3/device/#{token}",
          headers: {
            "authorization" => "bearer #{jwt}",
            "apns-topic" => settings[:bundle_id],
            "apns-push-type" => "alert",
            "apns-priority" => "10"
          },
          body: JSON.generate(payload)
        )
        forget(device_token) if [ 404, 410 ].include?(response.status)
        return response if response.status == 200 || [ 404, 410 ].include?(response.status)

        raise DeliveryError, "APNs responded #{response.status}"
      end

      def self.token_for(settings, now: Time.now.to_i)
        key = OpenSSL::PKey::EC.new(settings[:private_key])
        Jwt.encode({ "iss" => settings[:team_id], "iat" => now }, key, alg: "ES256", kid: settings[:key_id])
      end

      private

      def forget(device_token)
        device_token.destroy if device_token.respond_to?(:destroy) && device_token.respond_to?(:destroyed?) && !device_token.destroyed?
      end
    end
  end
end
